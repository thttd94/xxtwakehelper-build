#!/usr/bin/env python3
"""Simple self-hosted HTTP/SOCKS proxy checker server.

Run:
  pip install fastapi uvicorn httpx[socks]
  python proxy_checker_server.py --host 0.0.0.0 --port 8899

API:
  POST /check       {"proxy":"host:port:user:pass", "type":"socks5"}
  POST /check-batch {"items":[{"proxy":"...", "type":"http"}], "max_workers":50}
"""
from __future__ import annotations

import argparse
import asyncio
import socket
import time
from typing import Any, Dict, List, Optional, Tuple
from urllib.parse import quote

try:
    import httpx
    from fastapi import FastAPI
    from pydantic import BaseModel, Field
except Exception as e:  # pragma: no cover
    raise SystemExit(
        "Missing dependency. Install with: pip install fastapi uvicorn httpx[socks]\n"
        f"Import error: {e}"
    )

APP_NAME = "Self Proxy Checker"
VERSION = "1.0.0"
TEST_URLS = [
    "https://api.ipify.org?format=json",
    "https://httpbin.org/ip",
    "https://ifconfig.me/ip",
]

app = FastAPI(title=APP_NAME, version=VERSION)


class CheckRequest(BaseModel):
    proxy: str = Field(..., description="Proxy string: ip:port, ip:port:user:pass, user:pass@ip:port, or scheme://user:pass@ip:port")
    type: str = Field("socks5", description="http, https, socks5, socks5h")
    connect_timeout: float = 5
    read_timeout: float = 12
    retries: int = 2


class BatchRequest(BaseModel):
    items: List[CheckRequest]
    max_workers: int = 50


def parse_proxy(raw: str, proxy_type: str) -> Tuple[str, str, int, Optional[str], Optional[str]]:
    raw = str(raw or "").strip()
    if not raw:
        raise ValueError("empty proxy")
    ptype = str(proxy_type or "socks5").lower().strip()
    if ptype == "https":
        # Most HTTPS proxy providers still use HTTP CONNECT proxy URLs.
        scheme = "http"
    elif ptype in ("http", "socks5", "socks5h"):
        scheme = ptype
    else:
        raise ValueError(f"unsupported proxy type: {proxy_type}")

    if "://" in raw:
        # Let httpx/python-socks parse it. Still extract host/port for TCP precheck best-effort.
        after = raw.split("://", 1)[1]
        auth_host = after.rsplit("@", 1)[-1]
        host_port = auth_host.split("/", 1)[0]
        host, port_s = host_port.rsplit(":", 1)
        return raw, host.strip("[]"), int(port_s), None, None

    user = password = None
    host = port_s = None
    if "@" in raw:
        auth, host_port = raw.rsplit("@", 1)
        if ":" in auth:
            user, password = auth.split(":", 1)
        else:
            user = auth
            password = ""
        host, port_s = host_port.rsplit(":", 1)
    else:
        parts = raw.split(":")
        if len(parts) == 2:
            host, port_s = parts
        elif len(parts) >= 4:
            host, port_s = parts[0], parts[1]
            user = parts[2]
            password = ":".join(parts[3:])
        else:
            raise ValueError("bad proxy format")

    port = int(port_s)
    if user is not None:
        proxy_url = f"{scheme}://{quote(user, safe='')}:{quote(password or '', safe='')}@{host}:{port}"
    else:
        proxy_url = f"{scheme}://{host}:{port}"
    return proxy_url, str(host).strip("[]"), port, user, password


def tcp_connect(host: str, port: int, timeout: float) -> Tuple[bool, str, int]:
    start = time.perf_counter()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True, "", int((time.perf_counter() - start) * 1000)
    except Exception as e:
        return False, str(e), int((time.perf_counter() - start) * 1000)


def extract_out_ip(data: Any, text: str) -> str:
    if isinstance(data, dict):
        for key in ("ip", "origin", "query"):
            val = data.get(key)
            if val:
                return str(val).split(",")[0].strip()
    return str(text or "").strip().splitlines()[0][:120]


async def check_one(req: CheckRequest) -> Dict[str, Any]:
    started = time.perf_counter()
    result: Dict[str, Any] = {
        "status": "UNKNOWN",
        "type": req.type,
        "proxy": req.proxy,
        "out_ip": "",
        "latency_ms": None,
        "tcp_ms": None,
        "error": "",
        "detail": "",
        "checker": APP_NAME,
        "version": VERSION,
    }
    try:
        proxy_url, host, port, _user, _password = parse_proxy(req.proxy, req.type)
    except Exception as e:
        result.update(status="DIE", error="BAD_FORMAT", detail=str(e), latency_ms=int((time.perf_counter() - started) * 1000))
        return result

    ok, err, tcp_ms = await asyncio.to_thread(tcp_connect, host, port, req.connect_timeout)
    result["tcp_ms"] = tcp_ms
    if not ok:
        result.update(status="DIE", error="CONNECT_FAIL", detail=err, latency_ms=int((time.perf_counter() - started) * 1000))
        return result

    timeout = httpx.Timeout(connect=req.connect_timeout, read=req.read_timeout, write=req.connect_timeout, pool=req.connect_timeout)
    errors: List[str] = []
    attempts = max(1, min(5, int(req.retries or 1)))
    for attempt in range(attempts):
        for url in TEST_URLS:
            try:
                async with httpx.AsyncClient(proxy=proxy_url, timeout=timeout, verify=False, follow_redirects=True) as client:
                    r = await client.get(url, headers={"User-Agent": "proxy-checker/1.0"})
                    text = r.text or ""
                    if 200 <= r.status_code < 300 and text.strip():
                        data: Any = None
                        try:
                            data = r.json()
                        except Exception:
                            data = None
                        result.update(
                            status="LIVE",
                            out_ip=extract_out_ip(data, text),
                            latency_ms=int((time.perf_counter() - started) * 1000),
                            error="",
                            detail=f"ok via {url}",
                        )
                        return result
                    errors.append(f"{url}: HTTP {r.status_code}")
            except httpx.ProxyError as e:
                result.update(status="DIE", error="PROXY_HANDSHAKE_FAIL", detail=str(e), latency_ms=int((time.perf_counter() - started) * 1000))
                return result
            except httpx.ConnectError as e:
                errors.append(f"{url}: CONNECT_ERROR {e}")
            except httpx.ReadTimeout as e:
                errors.append(f"{url}: READ_TIMEOUT {e}")
            except httpx.ConnectTimeout as e:
                errors.append(f"{url}: CONNECT_TIMEOUT {e}")
            except Exception as e:
                errors.append(f"{url}: {type(e).__name__} {e}")

    # TCP worked, but outbound did not. Avoid false DIE when test endpoints/proxy path is slow.
    joined = " | ".join(errors[-8:])
    result.update(status="UNKNOWN", error="OUTBOUND_TEST_FAIL", detail=joined, latency_ms=int((time.perf_counter() - started) * 1000))
    return result


@app.get("/health")
async def health() -> Dict[str, Any]:
    return {"ok": True, "name": APP_NAME, "version": VERSION}


@app.post("/check")
async def check(req: CheckRequest) -> Dict[str, Any]:
    return await check_one(req)


@app.post("/check-batch")
async def check_batch(req: BatchRequest) -> Dict[str, Any]:
    sem = asyncio.Semaphore(max(1, min(300, int(req.max_workers or 50))))

    async def guarded(item: CheckRequest) -> Dict[str, Any]:
        async with sem:
            return await check_one(item)

    started = time.perf_counter()
    results = await asyncio.gather(*(guarded(item) for item in req.items))
    return {"count": len(results), "latency_ms": int((time.perf_counter() - started) * 1000), "results": results}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=8899)
    args = parser.parse_args()
    import uvicorn
    uvicorn.run(app, host=args.host, port=args.port, log_level="info")


if __name__ == "__main__":
    main()

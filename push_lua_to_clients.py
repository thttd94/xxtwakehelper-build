import argparse
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parent
DEMO = ROOT / 'demo'
LUA_DIR = DEMO / 'lua'
CONFIG = DEMO / 'xxtouch_router_config.json'
sys.path.insert(0, str(DEMO))
from xxtouch_openapi_client import XXTouchOpenAPIClient

REMOTE_DIR = '/var/mobile/Media/1ferver/lua/examples'
FILES = sorted(LUA_DIR.glob('*.lua'))

def load_rows(machines):
    data = json.loads(CONFIG.read_text(encoding='utf-8'))
    want = {str(x).strip() for x in machines} if machines else None
    out = []
    seen = set()
    for router in data:
        for row in router.get('rows', []) or []:
            m = str(row.get('machine') or '').strip()
            ip = str(row.get('ip') or '').strip()
            if not m or not ip:
                continue
            if want and m not in want:
                continue
            if m in seen:
                continue
            seen.add(m)
            out.append((m, ip))
    return out

def push_one(machine, ip):
    client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=0.8, read_timeout=8)
    pushed = 0
    for p in FILES:
        remote = f'{REMOTE_DIR}/{p.name}'
        data = p.read_bytes()
        client.write_file(remote, data)
        pushed += 1
    return machine, ip, pushed, 'OK'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--machines', default='', help='VD: 1,2,753 ; bỏ trống = all')
    ap.add_argument('--workers', type=int, default=20)
    args = ap.parse_args()
    machines = [x.strip() for x in args.machines.split(',') if x.strip()]
    rows = load_rows(machines)
    print(f'PUSH {len(FILES)} lua files -> {len(rows)} clients')
    ok = fail = 0
    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as ex:
        futs = [ex.submit(push_one, m, ip) for m, ip in rows]
        for fut in as_completed(futs):
            try:
                m, ip, n, status = fut.result()
                ok += 1
                print(f'[{m}] {ip} OK {n} files')
            except Exception as e:
                fail += 1
                print(f'FAIL {e}')
    print(f'DONE ok={ok} fail={fail}')

if __name__ == '__main__':
    main()

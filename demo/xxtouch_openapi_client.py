import base64
import json
import time
import urllib.request
import urllib.error


class XXTouchOpenAPIError(Exception):
    pass


class XXTouchOpenAPIClient:
    def __init__(self, base_url: str, timeout: int = 15, connect_timeout: float | None = None, read_timeout: float | None = None):
        self.base_url = str(base_url or '').rstrip('/')
        self.timeout = int(timeout)
        self.connect_timeout = float(connect_timeout if connect_timeout is not None else min(self.timeout, 2.0))
        self.read_timeout = float(read_timeout if read_timeout is not None else self.timeout)

    def _open_request(self, req):
        import socket
        old_timeout = socket.getdefaulttimeout()
        socket.setdefaulttimeout(self.connect_timeout)
        try:
            return urllib.request.urlopen(req, timeout=self.read_timeout)
        finally:
            socket.setdefaulttimeout(old_timeout)

    def _post_json(self, path: str, payload=None):
        if not self.base_url:
            raise XXTouchOpenAPIError('Missing base_url')
        data = json.dumps(payload or {}, ensure_ascii=False).encode('utf-8')
        req = urllib.request.Request(
            self.base_url + path,
            data=data,
            headers={'Content-Type': 'application/json; charset=utf-8'},
            method='POST',
        )
        try:
            with self._open_request(req) as resp:
                raw = resp.read().decode('utf-8', 'replace')
        except urllib.error.HTTPError as e:
            detail = e.read().decode('utf-8', 'replace')
            raise XXTouchOpenAPIError(f'HTTP {e.code}: {detail}')
        except Exception as e:
            raise XXTouchOpenAPIError(str(e))
        try:
            return json.loads(raw)
        except Exception:
            return {'raw': raw}

    def _post_raw(self, path: str, data=b'', content_type: str = 'application/x-www-form-urlencoded; charset=utf-8'):
        if not self.base_url:
            raise XXTouchOpenAPIError('Missing base_url')
        if isinstance(data, str):
            data = data.encode('utf-8')
        req = urllib.request.Request(
            self.base_url + path,
            data=data,
            headers={'Content-Type': content_type},
            method='POST',
        )
        try:
            with self._open_request(req) as resp:
                raw = resp.read().decode('utf-8', 'replace')
        except urllib.error.HTTPError as e:
            detail = e.read().decode('utf-8', 'replace')
            raise XXTouchOpenAPIError(f'HTTP {e.code}: {detail}')
        except Exception as e:
            raise XXTouchOpenAPIError(str(e))
        try:
            return json.loads(raw)
        except Exception:
            return {'raw': raw}

    def _post_lua(self, path: str, script: str, spawn_args=None):
        if not self.base_url:
            raise XXTouchOpenAPIError('Missing base_url')
        req = urllib.request.Request(
            self.base_url + path,
            data=str(script or '').encode('utf-8'),
            headers={
                'Content-Type': 'text/lua; charset=utf-8',
                'spawn_args': json.dumps(spawn_args or {}, ensure_ascii=False),
            },
            method='POST',
        )
        try:
            with self._open_request(req) as resp:
                raw = resp.read().decode('utf-8', 'replace')
        except urllib.error.HTTPError as e:
            detail = e.read().decode('utf-8', 'replace')
            raise XXTouchOpenAPIError(f'HTTP {e.code}: {detail}')
        except Exception as e:
            raise XXTouchOpenAPIError(str(e))
        try:
            return json.loads(raw)
        except Exception:
            return {'raw': raw}

    def spawn(self, script: str, spawn_args=None):
        return self._post_lua('/spawn', script, spawn_args=spawn_args)

    def command_spawn(self, command: str):
        return self._post_json('/command_spawn', {'command': command})

    def recycle(self):
        return self._post_json('/recycle', {})

    def deviceinfo(self):
        return self._post_json('/deviceinfo', {})

    def applist(self):
        return self._post_json('/applist', {})

    def lock_screen(self):
        return self._post_json('/lock_screen', {})

    def unlock_screen(self):
        return self._post_json('/unlock_screen', {})

    def reboot2(self):
        return self._post_json('/reboot2', {})

    def snapshot(self):
        if not self.base_url:
            raise XXTouchOpenAPIError('Missing base_url')
        last_error = None
        for path in ['/snapshot', '/screenshot']:
            req = urllib.request.Request(self.base_url + path, method='POST')
            try:
                with self._open_request(req) as resp:
                    return resp.read()
            except urllib.error.HTTPError as e:
                last_error = f'HTTP {e.code}: {e.read().decode("utf-8", "replace")}'
            except Exception as e:
                last_error = str(e)
        raise XXTouchOpenAPIError(last_error or 'Snapshot failed')

    def write_file(self, filename: str, content_bytes: bytes):
        payload = {
            'path': filename,
            'filename': filename,
            'content': base64.b64encode(content_bytes).decode('ascii'),
            'data': base64.b64encode(content_bytes).decode('ascii'),
        }
        return self._post_json('/write_file', payload)

    def spawn_and_wait(self, script: str, spawn_args=None, wait_seconds: float = 2.0):
        self.spawn(script, spawn_args=spawn_args)
        import time
        time.sleep(wait_seconds)

    def get_storage_info(self):
        probe_name = f"storage_probe_{int(time.time() * 1000)}.txt"
        probe_path = f"/var/mobile/Media/1ferver/log/{probe_name}"
        script = f'''
local f = io.popen('df -k /private/var 2>/dev/null')
local out = ''
if f then
  out = f:read('*a') or ''
  f:close()
end
local ff = io.open('{probe_path}', 'w')
if ff then
  ff:write(out)
  ff:close()
end
return true
'''
        try:
            self.recycle()
            time.sleep(0.8)
        except Exception:
            pass
        self.spawn(script)
        time.sleep(1.0)
        raw = self.download_text_file(probe_path)
        storage = {{'raw': raw, 'ok': False, 'total_kb': None, 'used_kb': None, 'free_kb': None}}
        for line in str(raw or '').splitlines():
            parts = line.split()
            if len(parts) >= 6 and parts[0].startswith('/dev/'):
                try:
                    storage['ok'] = True
                    storage['total_kb'] = int(parts[1])
                    storage['used_kb'] = int(parts[2])
                    storage['free_kb'] = int(parts[3])
                    break
                except Exception:
                    continue
        return storage

    def download_text_file(self, filename: str):
        if not self.base_url:
            raise XXTouchOpenAPIError('Missing base_url')
        quoted = urllib.parse.quote(filename, safe='')
        req = urllib.request.Request(self.base_url + '/download_file?filename=' + quoted, method='GET')
        try:
            with self._open_request(req) as resp:
                return resp.read().decode('utf-8', 'replace')
        except urllib.error.HTTPError as e:
            detail = e.read().decode('utf-8', 'replace')
            raise XXTouchOpenAPIError(f'HTTP {e.code}: {detail}')
        except Exception as e:
            raise XXTouchOpenAPIError(str(e))

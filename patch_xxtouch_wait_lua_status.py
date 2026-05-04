from pathlib import Path
p=Path(r'C:\Users\Administrator\.openclaw\workspace\demo\xxtouch_only_gui_demo.pyw')
s=p.read_text(encoding='utf-8')
backup=p.with_suffix(p.suffix + '.bak_20260505_status_wait')
backup.write_text(s, encoding='utf-8')

s=s.replace("""    def _run_group3_action(self, router, action_key):
        script_path = self._group3_script_path(router, action_key)
        if not script_path.exists():
            self._append_router_log(router, f'Không thấy file lua: {script_path.name}')
            return
        command = script_path.read_text(encoding='utf-8')
        if action_key == 'event_dd_20p':
            self._run_spawn_batched_for_router(router, command, script_path.name, batch_size=10, batch_delay=10, stop_first=True, read_timeout=12)
            return
        if action_key == 'ui':
            self._run_floating_ui_for_router(router, script_path)
            return
        self._run_spawn_command_for_router(router, command, script_path.name, stop_first=True, read_timeout=12)
""", """    def _run_group3_action(self, router, action_key):
        script_path = self._group3_script_path(router, action_key)
        if not script_path.exists():
            self._append_router_log(router, f'Không thấy file lua: {script_path.name}')
            return
        command = script_path.read_text(encoding='utf-8')
        if action_key == 'ui':
            self._run_floating_ui_for_router(router, script_path)
            return
        # Với các script Group3/NuoiPhoi: spawn thành công chưa gọi là OK.
        # Phải đọc status Lua và chỉ OK khi script chạy xong thật.
        self._run_spawn_command_for_router(router, command, script_path.name, stop_first=True, read_timeout=12, wait_lua_done=True)
""")

s=s.replace("""            max_workers = min(32, max(1, len(rows)))
""", """            max_workers = min(1000, max(1, len(rows)))
""", 1)

old="""    def _spawn_task_for_row(self, router, row, command, action_name, stop_first=True, read_timeout=6):
        ip = str(row.get('ip') or '').strip()
        if not ip:
            raise XXTouchOpenAPIError('Thiếu IP')
        client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=read_timeout)
        if stop_first:
            self._append_router_log(router, f'[{row.get("machine", "?")}] {action_name}: STOP SCRIPT trước khi chạy')
            client.recycle()
            time.sleep(0.8)
        client.spawn(command)
        row['network'] = 'Online'
        row['xxtouch'] = 'Connected'
        row['updated'] = now_text()
        return row

"""
new=r"""    def _lua_status_wrapper(self, command, status_path):
        safe_path = str(status_path).replace('\\', '/').replace('"', '\\"')
        return f'''
local __oc_status_path = "{safe_path}"
local __oc_old_toast = nil
local function __oc_write_status(msg)
    msg = tostring(msg or "")
    local line = tostring(os.time()) .. "|" .. msg
    local ok_file, file = pcall(require, "file")
    if ok_file and file and file.writes then
        pcall(file.writes, __oc_status_path, line)
    else
        local f = io.open(__oc_status_path, "w")
        if f then f:write(line) f:close() end
    end
    print("OC_STATUS:" .. msg)
end
local ok_sys, sys_mod = pcall(require, "sys")
if ok_sys and sys_mod then
    __oc_old_toast = sys_mod.toast
    sys_mod.toast = function(msg, ...)
        __oc_write_status(msg)
        if __oc_old_toast then return __oc_old_toast(msg, ...) end
    end
    package.loaded["sys"] = sys_mod
end
__oc_write_status("STARTED")
local __oc_ok, __oc_err = xpcall(function()
{command}
end, debug.traceback)
if __oc_ok then
    __oc_write_status("FINISHED_OK")
else
    __oc_write_status("ERROR: " .. tostring(__oc_err))
    error(__oc_err)
end
'''.lstrip()

    def _client_is_running(self, client):
        try:
            resp = client._post_json('/is_running', {})
            if isinstance(resp, dict):
                code = resp.get('code')
                msg = str(resp.get('message') or '')
                data = resp.get('data')
                if code == 3 or 'running another script' in msg.lower():
                    return True
                if isinstance(data, bool):
                    return data
                if isinstance(data, dict) and 'running' in data:
                    return bool(data.get('running'))
            return False
        except Exception:
            return False

    def _read_lua_status_text(self, client, status_path):
        try:
            raw = client.download_text_file(status_path)
        except Exception:
            return ''
        raw = str(raw or '').strip()
        if '|' in raw:
            return raw.split('|', 1)[1].strip()
        return raw

    def _spawn_task_for_row(self, router, row, command, action_name, stop_first=True, read_timeout=6, wait_lua_done=False):
        ip = str(row.get('ip') or '').strip()
        if not ip:
            raise XXTouchOpenAPIError('Thiếu IP')
        machine = str(row.get('machine', '?'))
        client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=read_timeout)
        if stop_first:
            self._append_router_log(router, f'[{machine}] {action_name}: STOP SCRIPT trước khi chạy')
            client.recycle()
            time.sleep(0.8)
        status_path = f'/var/mobile/Media/1ferver/lua/examples/oc_status_{machine}.txt'
        run_command = self._lua_status_wrapper(command, status_path) if wait_lua_done else command
        client.spawn(run_command)
        row['network'] = 'Online'
        row['xxtouch'] = 'Connected'
        row['updated'] = now_text()
        if not wait_lua_done:
            return row

        self._set_machine_status(router, row, action_name, 'Đã start Lua, đang chờ status...', mode='running', started_at=time.time())
        last_status = ''
        last_log_at = 0.0
        quiet_after_spawn = time.time() + 1.5
        deadline = time.time() + 4 * 60 * 60
        while time.time() < deadline:
            status_text = self._read_lua_status_text(client, status_path)
            if status_text and status_text != last_status:
                last_status = status_text
                row['note'] = status_text
                row['updated'] = now_text()
                mode = 'error' if status_text.startswith('ERROR:') else 'running'
                self._set_machine_status(router, row, action_name, status_text, mode=mode)
                now = time.time()
                if now - last_log_at >= 1.0:
                    last_log_at = now
                    self.after(0, lambda m=machine, st=status_text: self._append_router_log(router, f'[{m}] {st}'))
            if status_text == 'FINISHED_OK':
                row['note'] = f'{action_name}: chạy xong'
                row['updated'] = now_text()
                return row
            if status_text.startswith('ERROR:'):
                raise XXTouchOpenAPIError(status_text)
            if time.time() > quiet_after_spawn and not self._client_is_running(client):
                final_status = self._read_lua_status_text(client, status_path) or last_status
                if final_status == 'FINISHED_OK':
                    row['note'] = f'{action_name}: chạy xong'
                    row['updated'] = now_text()
                    return row
                if final_status.startswith('ERROR:'):
                    raise XXTouchOpenAPIError(final_status)
                raise XXTouchOpenAPIError(f'Lua đã dừng nhưng chưa báo FINISHED_OK, status cuối: {final_status or "<trống>"}')
            time.sleep(2.5)
        raise XXTouchOpenAPIError('Quá thời gian chờ Lua chạy xong')

"""
if old not in s:
    raise SystemExit('old spawn block not found')
s=s.replace(old,new)

s=s.replace("""    def _run_spawn_command_for_router(self, router, command, action_name, stop_first=True, read_timeout=6):
        rows = self._selected_rows(router)

        def task(row):
            return self._spawn_task_for_row(router, row, command, action_name, stop_first=stop_first, read_timeout=read_timeout)

        self._run_parallel_rows(router, rows, task, action_name, per_success=lambda row: f'[{row.get("machine", "?")}] {action_name} OK')
""", """    def _run_spawn_command_for_router(self, router, command, action_name, stop_first=True, read_timeout=6, wait_lua_done=False):
        rows = self._selected_rows(router)

        def task(row):
            return self._spawn_task_for_row(router, row, command, action_name, stop_first=stop_first, read_timeout=read_timeout, wait_lua_done=wait_lua_done)

        ok_label = 'CHẠY XONG OK' if wait_lua_done else 'START OK'
        self._run_parallel_rows(router, rows, task, action_name, per_success=lambda row: f'[{row.get("machine", "?")}] {action_name} {ok_label}')
""")

p.write_text(s, encoding='utf-8')
print('patched', p)
print('backup', backup)

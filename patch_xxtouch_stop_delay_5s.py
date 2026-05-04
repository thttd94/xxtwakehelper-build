from pathlib import Path
p=Path(r'C:\Users\Administrator\.openclaw\workspace\demo\xxtouch_only_gui_demo.pyw')
s=p.read_text(encoding='utf-8')
backup=p.with_suffix(p.suffix + '.bak_20260505_stop_delay_5s')
backup.write_text(s,encoding='utf-8')
s=s.replace('''    def _try_recycle_before_spawn(self, client):
        try:
            client.recycle()
            time.sleep(0.35)
            return
''','''    def _try_recycle_before_spawn(self, client):
        try:
            client.recycle()
            time.sleep(5.0)
            return
''')
s=s.replace('''        if stop_first:
            self._append_router_log(router, f'[{machine}] {action_name}: STOP SCRIPT trước khi chạy')
            client.recycle()
            time.sleep(0.8)
''','''        if stop_first:
            self._append_router_log(router, f'[{machine}] {action_name}: STOP SCRIPT trước khi chạy, chờ 5s')
            client.recycle()
            time.sleep(5.0)
''')
s=s.replace('''            self._append_router_log(router, f'[{row.get("machine", "?")}] UI: STOP SCRIPT trước khi chạy')
            client.recycle()
            time.sleep(0.8)
''','''            self._append_router_log(router, f'[{row.get("machine", "?")}] UI: STOP SCRIPT trước khi chạy, chờ 5s')
            client.recycle()
            time.sleep(5.0)
''')
p.write_text(s,encoding='utf-8')
print('patched stop delay 5s')
print('backup', backup)

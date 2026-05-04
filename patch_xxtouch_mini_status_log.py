from pathlib import Path
p=Path(r'C:\Users\Administrator\.openclaw\workspace\demo\xxtouch_only_gui_demo.pyw')
s=p.read_text(encoding='utf-8')

s=s.replace("        self.router_logs_widgets = {}\n        self.router_file_widgets = {}", "        self.router_logs_widgets = {}\n        self.router_mini_log_widgets = {}\n        self.router_file_widgets = {}")

old="""        primary_row = ttk.Frame(box, style='Card.TFrame')
        primary_row.pack(fill='x', pady=(0, 8))
        primary_specs = [
"""
new="""        primary_row = ttk.Frame(box, style='Card.TFrame')
        primary_row.pack(fill='x', pady=(0, 8))
        mini_log = tk.Text(primary_row, height=5, width=46, bg='#020617', fg='#e2e8f0', insertbackground='#e2e8f0', relief='solid', borderwidth=1, wrap='none', font=('Consolas', 8))
        mini_log.pack(side='right', padx=(8, 0), fill='x')
        for tag, color in [
            ('mini0', '#22c55e'),
            ('mini1', '#60a5fa'),
            ('mini2', '#facc15'),
            ('mini3', '#fb7185'),
            ('mini4', '#c084fc'),
        ]:
            mini_log.tag_configure(tag, foreground=color)
        mini_log.config(state='disabled')
        self.router_mini_log_widgets[id(router)] = mini_log
        self._refresh_router_mini_log(router)
        primary_specs = [
"""
if old not in s:
    raise SystemExit('primary row block not found')
s=s.replace(old,new)

marker="""    def _open_log_file(self):
"""
helper=r'''    def _refresh_router_mini_log(self, router):
        widget = self.router_mini_log_widgets.get(id(router))
        if widget is None:
            return
        try:
            widget.config(state='normal')
            widget.delete('1.0', 'end')
            lines = list(router.get('logs', []))[-5:]
            colors = ['mini0', 'mini1', 'mini2', 'mini3', 'mini4']
            for idx, line in enumerate(lines):
                widget.insert('end', line + '\n', colors[idx % len(colors)])
            widget.see('end')
            widget.config(state='disabled')
        except Exception:
            pass

'''
if marker not in s:
    raise SystemExit('open log marker not found')
s=s.replace(marker, helper+marker)

s=s.replace("        self._refresh_router_logs(router)\n\n    def _run_background", "        self._refresh_router_logs(router)\n        self._refresh_router_mini_log(router)\n\n    def _run_background")

p.write_text(s,encoding='utf-8')
print('patched mini status log')

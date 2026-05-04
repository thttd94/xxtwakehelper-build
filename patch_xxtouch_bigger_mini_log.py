from pathlib import Path
p=Path(r'C:\Users\Administrator\.openclaw\workspace\demo\xxtouch_only_gui_demo.pyw')
s=p.read_text(encoding='utf-8')
old="""        primary_row = ttk.Frame(box, style='Card.TFrame')
        primary_row.pack(fill='x', pady=(0, 8))
        mini_log = tk.Text(primary_row, height=5, width=46, bg='#020617', fg='#e2e8f0', insertbackground='#e2e8f0', relief='solid', borderwidth=1, wrap='none', font=('Consolas', 8))
        mini_log.pack(side='right', padx=(8, 0), fill='x')
"""
new="""        primary_row = ttk.Frame(box, style='Card.TFrame')
        primary_row.pack(fill='x', pady=(0, 8))
        mini_log_wrap = tk.Frame(primary_row, bg='#94a3b8', highlightbackground='#94a3b8', highlightthickness=1)
        mini_log_wrap.pack(side='right', padx=(12, 0), fill='both', expand=True)
        mini_log = tk.Text(mini_log_wrap, height=6, width=86, bg='#020617', fg='#e2e8f0', insertbackground='#e2e8f0', relief='flat', borderwidth=0, wrap='none', font=('Consolas', 10, 'bold'), padx=8, pady=5)
        mini_log.pack(fill='both', expand=True)
"""
if old not in s:
    raise SystemExit('target block not found')
s=s.replace(old,new)
p.write_text(s,encoding='utf-8')
print('patched bigger mini log')

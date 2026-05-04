from pathlib import Path
p=Path(r'C:\Users\Administrator\.openclaw\workspace\demo\xxtouch_only_gui_demo.pyw')
s=p.read_text(encoding='utf-8')
backup=p.with_suffix(p.suffix + '.bak_20260505_remove_sync_examples')
backup.write_text(s, encoding='utf-8')
old="""            ('SYNC EXAMPLES', lambda r=router: self._sync_examples_from_repo_for_router(r)),
"""
if old not in s:
    raise SystemExit('SYNC EXAMPLES button line not found')
s=s.replace(old,'')
p.write_text(s, encoding='utf-8')
print('removed SYNC EXAMPLES button')
print('backup', backup)

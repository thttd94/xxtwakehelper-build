from pathlib import Path
p=Path('patch_xxtouch_wait_lua_status.py')
s=p.read_text(encoding='utf-8')
s=s.replace("new=r'''    def _lua_status_wrapper", 'new=r"""    def _lua_status_wrapper')
s=s.replace("\n'''\nif old not in s:", '\n"""\nif old not in s:')
p.write_text(s,encoding='utf-8')

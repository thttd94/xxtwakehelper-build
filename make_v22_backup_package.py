from pathlib import Path
import shutil
root=Path('GEN_NEW_9001')
ver='2.2'
pkg=root/'gen_backup'/'versions'/ver/'package'
if pkg.exists():
    shutil.rmtree(pkg)
pkg.mkdir(parents=True)
exclude={'.git','__pycache__','gen_backup'}
for item in root.iterdir():
    if item.name in exclude:
        continue
    dest=pkg/item.name
    if item.is_dir():
        shutil.copytree(item,dest,ignore=shutil.ignore_patterns('__pycache__','*.pyc'))
    else:
        shutil.copy2(item,dest)
(pkg/'VERSION.txt').write_text('V2.2\n',encoding='utf-8')
print('created',pkg)

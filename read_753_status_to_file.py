import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent / 'demo'))
from xxtouch_openapi_client import XXTouchOpenAPIClient
client=XXTouchOpenAPIClient('http://192.16.5.192:46952', connect_timeout=1.0, read_timeout=5)
out=[]
for path in ['/var/mobile/Media/1ferver/lua/examples/oc_status_753.txt','/var/mobile/Media/1ferver/lua/examples/oc_status.txt']:
    try:
        raw=client.download_text_file(path)
        out.append(path+' OK '+repr(raw[:1000]))
    except Exception as e:
        out.append(path+' ERR '+repr(str(e)))
Path('read_753_status_to_file.txt').write_text('\n'.join(out), encoding='utf-8', errors='replace')

from pathlib import Path
base=Path(r'C:\Users\Administrator\.openclaw\workspace\demo\lua')
for name in ['Group3_NuoiPhoi_tiktok.lua','Group3_NuoiPhoi_tiktok_lite.lua']:
    s=(base/name).read_text(encoding='utf-8',errors='replace')
    print(name)
    print(' backgroundWatchdog', s.count('function backgroundWatchdog'))
    print(' ensureActiveApp', s.count('function ensureActiveApp'))
    print(' setActiveApp appstore', s.count('setActiveApp("appstore"'))
    print(' sleep watchdog', s.count('type(backgroundWatchdog)'))

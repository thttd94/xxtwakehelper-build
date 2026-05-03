import json, tkinter as tk, urllib.request, math, os
from datetime import datetime, timezone

DB = r'C:\Users\Administrator\AppData\Roaming\9router\db.json'
API = 'http://127.0.0.1:20129/api/usage/{}'
REFRESH_MS = 60000
W = 360
ROW_H = 78
PAD = 8

root = tk.Tk()
root.title('9Router Live Quota')
root.configure(bg='black')
root.attributes('-topmost', True)
root.attributes('-alpha', 1.0)
root.overrideredirect(True)
try:
    root.wm_attributes('-transparentcolor', 'black')
except Exception:
    pass
screen_w = root.winfo_screenwidth()
root.geometry(f'{W}x420+{screen_w-W-80}+60')
cv = tk.Canvas(root, width=W, height=420, bg='black', highlightthickness=0, bd=0)
cv.pack(fill='both', expand=True)

COL = {
    'text':'#f4f7fa','muted':'#aab2bd','dim':'#757d88','card':'#20211f',
    'green':'#00d26a','yellow':'#ffe04a','red':'#ff375f','blue':'#59a6ff'
}

_tick = 0


def clickthrough():
    try:
        import ctypes
        root.lift()
        root.attributes('-topmost', True)
        root.update_idletasks()
        hwnd = root.winfo_id()
        GWL_EXSTYLE = -20
        WS_EX_LAYERED = 0x00080000
        WS_EX_TRANSPARENT = 0x00000020
        WS_EX_TOOLWINDOW = 0x00000080
        HWND_TOPMOST = -1
        SWP_NOMOVE = 0x0002
        SWP_NOSIZE = 0x0001
        SWP_NOACTIVATE = 0x0010
        SWP_SHOWWINDOW = 0x0040
        style = ctypes.windll.user32.GetWindowLongW(hwnd, GWL_EXSTYLE)
        ctypes.windll.user32.SetWindowLongW(hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED | WS_EX_TRANSPARENT | WS_EX_TOOLWINDOW)
        ctypes.windll.user32.SetWindowPos(hwnd, HWND_TOPMOST, 0,0,0,0, SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE|SWP_SHOWWINDOW)
    except Exception:
        pass


def rounded(x1,y1,x2,y2,r,fill):
    pts=[x1+r,y1,x2-r,y1,x2,y1,x2,y1+r,x2,y2-r,x2,y2,x2-r,y2,x1+r,y2,x1,y2,x1,y2-r,x1,y1+r,x1,y1]
    cv.create_polygon(pts, smooth=True, fill=fill, outline='')


def short_name(s):
    s=s or 'unknown'
    if '@' in s:
        left,right=s.split('@',1)
        return left[:18] + ('...' if len(left)>18 else '') + '@' + right.split('.')[0][:10]
    return s[:28]


def accounts():
    try:
        with open(DB, encoding='utf-8') as f:
            d=json.load(f)
    except Exception:
        return []
    return sorted(
        [a for a in d.get('providerConnections',[]) if a.get('provider')=='codex'],
        key=lambda x:(x.get('priority') or 999,x.get('name') or '')
    )[:6]


def quota(cid):
    try:
        with urllib.request.urlopen(API.format(cid),timeout=8) as r:
            return json.loads(r.read().decode('utf-8'))
    except Exception as e:
        return {'error':str(e),'quotas':{}}


def pct(q):
    total=q.get('total') or 100
    rem=q.get('remaining')
    if rem is None:
        rem=max(0,total-(q.get('used') or 0))
    return max(0,min(100,round(rem/total*100))) if total else 100


def used_text(q):
    if not q:
        return '-'
    used = q.get('used')
    total = q.get('total') or 100
    rem = q.get('remaining')
    if used is None and rem is not None:
        used = total - rem
    if used is None:
        return f"{pct(q)}% left"
    return f"{used}/{total} used"


def color(p): return COL['green'] if p>=70 else COL['yellow'] if p>=30 else COL['red']


def intime(reset):
    if not reset: return '-'
    try:
        d=datetime.fromisoformat(reset.replace('Z','+00:00'))
        mins=max(0,math.ceil((d-datetime.now(timezone.utc)).total_seconds()/60))
        if mins<60: return f'reset {mins}m'
        h,m=divmod(mins,60)
        if h<24: return f'reset {h}h{m:02d}'
        days,h=divmod(h,24)
        return f'reset {days}d{h:02d}h'
    except Exception: return '-'


def local_age(iso):
    if not iso: return '-'
    try:
        d=datetime.fromisoformat(iso.replace('Z','+00:00'))
        secs=max(0,int((datetime.now(timezone.utc)-d).total_seconds()))
        if secs < 60: return f'{secs}s ago'
        mins = secs//60
        if mins < 60: return f'{mins}m ago'
        return f'{mins//60}h ago'
    except Exception:
        return '-'


def bar(x,y,w,p,c):
    cv.create_rectangle(x,y,x+w,y+4,fill='#363a36',outline='')
    cv.create_rectangle(x,y,x+int(w*p/100),y+4,fill=c,outline='')


def line(y, label, q):
    p=pct(q)
    cv.create_text(PAD+9,y,text=label,anchor='w',fill=COL['muted'],font=('Segoe UI',7))
    cv.create_text(PAD+64,y,text=f'{p}% left',anchor='w',fill=color(p),font=('Segoe UI',7,'bold'))
    cv.create_text(PAD+126,y,text=used_text(q),anchor='w',fill=COL['text'],font=('Segoe UI',7))
    bar(PAD+214,y-2,58,p,color(p))
    cv.create_text(W-PAD-9,y,text=intime(q.get('resetAt') if q else None),anchor='e',fill=COL['muted'],font=('Segoe UI',7))


def draw():
    global _tick
    _tick += 1
    rows=[]
    for a in accounts():
        q=quota(a.get('id'))
        qs=q.get('quotas') or {}
        rows.append((a, qs.get('session',{}), qs.get('weekly',{}), q.get('error')))
    H=PAD*2+22+len(rows)*ROW_H
    root.geometry(f'{W}x{H}+{root.winfo_screenwidth()-W-80}+60')
    cv.config(width=W,height=H)
    cv.delete('all')
    cv.create_rectangle(0, 0, W, H, fill='black', outline='black')
    now = datetime.now().strftime('%H:%M:%S')
    pulse = '*' if _tick % 2 else 'o'
    cv.create_text(PAD,12,text='9Router Live Quota',anchor='w',fill=COL['text'],font=('Segoe UI',10,'bold'))
    cv.create_text(W-PAD,12,text=f'{pulse} {now}',anchor='e',fill=COL['blue'],font=('Segoe UI',8,'bold'))
    y=30
    if not rows:
        cv.create_text(W//2, y+20, text='No codex accounts found', fill=COL['red'], font=('Segoe UI',9,'bold'))
    for a,s,w,err in rows:
        rounded(PAD,y,W-PAD,y+ROW_H-7,8,COL['card'])
        cv.create_text(PAD+8,y+13,text=short_name(a.get('email') or a.get('name')),anchor='w',fill=COL['text'],font=('Segoe UI Semibold',8))
        cv.create_text(W-PAD-9,y+13,text='last ' + local_age(a.get('lastUsedAt') or a.get('updatedAt')),anchor='e',fill=COL['dim'],font=('Segoe UI',7))
        if err:
            cv.create_text(PAD+9,y+42,text='API error: '+err[:42],anchor='w',fill=COL['red'],font=('Segoe UI',7,'bold'))
        else:
            line(y+35, 'Session', s)
            line(y+56, 'Weekly', w)
        y += ROW_H
    root.after(REFRESH_MS,draw)
    root.after(200,clickthrough)


draw()
root.after(500,clickthrough)
root.mainloop()

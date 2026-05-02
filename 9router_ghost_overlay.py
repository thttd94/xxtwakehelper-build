import json, tkinter as tk, urllib.request, math
from datetime import datetime, timezone

DB = r'C:\Users\Administrator\AppData\Roaming\9router\db.json'
API = 'http://127.0.0.1:20128/api/usage/{}'
REFRESH_MS = 5000
W = 300
ROW_H = 64
PAD = 8

root = tk.Tk()
root.title('9Router Live Quota')
root.configure(bg='black')
root.attributes('-topmost', True)
# Keep window fully opaque but make the black background transparent.
# Do NOT use whole-window alpha; that creates a visible sheet over the desktop.
root.attributes('-alpha', 1.0)
root.overrideredirect(True)
try:
    root.wm_attributes('-transparentcolor', 'black')
except Exception:
    pass
screen_w = root.winfo_screenwidth()
# Keep it near top-right but not flush to the edge, easier to notice.
root.geometry(f'{W}x380+{screen_w-W-80}+60')
cv = tk.Canvas(root, width=W, height=380, bg='black', highlightthickness=0, bd=0)
cv.pack(fill='both', expand=True)

COL = {'text':'#f4f7fa','muted':'#aab2bd','dim':'#757d88','card':'#20211f','green':'#00d26a','yellow':'#ffe04a','red':'#ff375f'}

def clickthrough():
    try:
        import ctypes
        root.lift()
        root.attributes('-topmost', True)
        root.update_idletasks()
        hwnd = root.winfo_id()
        # For Tk on Windows, winfo_id is the real top-level HWND in this setup.
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
        return left[:15] + ('â€¦' if len(left)>15 else '') + '@' + right.split('.')[0][:10]
    return s[:22]

def accounts():
    try: d=json.load(open(DB,encoding='utf-8'))
    except Exception: return []
    return sorted([a for a in d.get('providerConnections',[]) if a.get('provider')=='codex'], key=lambda x:(x.get('priority') or 999,x.get('name') or ''))[:6]

def quota(cid):
    try:
        with urllib.request.urlopen(API.format(cid),timeout=8) as r: return json.loads(r.read().decode('utf-8'))
    except Exception as e: return {'error':str(e),'quotas':{}}

def pct(q):
    total=q.get('total') or 100; rem=q.get('remaining')
    if rem is None: rem=max(0,total-(q.get('used') or 0))
    return max(0,min(100,round(rem/total*100))) if total else 100

def color(p): return COL['green'] if p>=70 else COL['yellow'] if p>=30 else COL['red']

def intime(reset):
    if not reset: return '-'
    try:
        d=datetime.fromisoformat(reset.replace('Z','+00:00'))
        mins=max(0,math.ceil((d-datetime.now(timezone.utc)).total_seconds()/60))
        if mins<60: return f'in {mins}m'
        h,m=divmod(mins,60)
        if h<24: return f'in {h}h'
        days,h=divmod(h,24)
        return f'in {days}d'
    except Exception: return '-'

def bar(x,y,w,p,c):
    cv.create_rectangle(x,y,x+w,y+3,fill='#363a36',outline='')
    cv.create_rectangle(x,y,x+int(w*p/100),y+3,fill=c,outline='')

def draw():
    rows=[]
    for a in accounts():
        q=quota(a.get('id')); qs=q.get('quotas') or {}; s=qs.get('session',{}); w=qs.get('weekly',{})
        rows.append((a,pct(s),pct(w),intime(s.get('resetAt')),intime(w.get('resetAt')),q.get('error')))
    H=PAD*2+16+len(rows)*ROW_H
    root.geometry(f'{W}x{H}+{root.winfo_screenwidth()-W-80}+60')
    cv.config(width=W,height=H); cv.delete('all')
    # Keep the black canvas transparent; draw only title text and small cards so desktop is not covered.
    cv.create_rectangle(0, 0, W, H, fill='black', outline='black')
    cv.create_text(PAD,12,text='9Router Live Quota',anchor='w',fill=COL['text'],font=('Segoe UI',10,'bold'))
    cv.create_text(W-PAD,12,text=datetime.now().strftime('%H:%M:%S'),anchor='e',fill=COL['dim'],font=('Segoe UI',7))
    y=26
    for a,sp,wp,st,wt,err in rows:
        rounded(PAD,y,W-PAD,y+ROW_H-6,7,COL['card'])
        cv.create_text(PAD+8,y+13,text=short_name(a.get('email') or a.get('name')),anchor='w',fill=COL['text'],font=('Segoe UI Semibold',8))
        sy=y+32
        cv.create_text(PAD+9,sy,text='Session',anchor='w',fill=COL['muted'],font=('Segoe UI',7))
        cv.create_text(PAD+66,sy,text=f'{sp}%',anchor='w',fill=color(sp),font=('Segoe UI',7,'bold'))
        bar(PAD+104,sy-1,82,sp,color(sp))
        cv.create_text(W-PAD-9,sy,text=st,anchor='e',fill=COL['muted'],font=('Segoe UI',7))
        wy=y+50
        cv.create_text(PAD+9,wy,text='Weekly',anchor='w',fill=COL['muted'],font=('Segoe UI',7))
        cv.create_text(PAD+66,wy,text=f'{wp}%',anchor='w',fill=color(wp),font=('Segoe UI',7,'bold'))
        bar(PAD+104,wy-1,82,wp,color(wp))
        cv.create_text(W-PAD-9,wy,text=wt,anchor='e',fill=COL['muted'],font=('Segoe UI',7))
        y += ROW_H
    root.after(REFRESH_MS,draw); root.after(200,clickthrough)

draw(); root.after(500,clickthrough); root.mainloop()


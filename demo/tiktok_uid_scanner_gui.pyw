import json
import threading
import time
import tkinter as tk
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from tkinter import ttk, messagebox, filedialog

try:
    from xxtouch_openapi_client import XXTouchOpenAPIClient
except Exception:
    XXTouchOpenAPIClient = None

APP_DIR = Path(__file__).resolve().parent
CONFIG_PATH = APP_DIR / 'tiktok_uid_scanner_config.json'
RESULT_PATH = APP_DIR / 'tiktok_uid_scan_results.txt'

INLINE_LUA = r'''
file = require("file")

local OUT = "/var/mobile/Media/1ferver/tiktok_uid_folders.txt"
local bases = {
  "/private/var/mobile/Containers/Data/Application",
  "/var/mobile/Containers/Data/Application"
}

local function write(s)
  local old = ""
  if file.exists(OUT) then old = file.reads(OUT) or "" end
  file.writes(OUT, old .. tostring(s) .. "\n")
  print(s)
end

local function join(a, b)
  return tostring(a):gsub("/$", "") .. "/" .. tostring(b):gsub("^/", "")
end

local function list(path)
  local t = file.list(path)
  local arr = {}
  if type(t) == "table" then
    for _, name in pairs(t) do
      if name and name ~= "." and name ~= ".." then table.insert(arr, tostring(name)) end
    end
  end
  table.sort(arr)
  return arr
end

local function is_dir(path)
  return type(file.list(path)) == "table"
end

local function exists(path)
  return file.exists(path) or is_dir(path)
end

local function is_number_name(name)
  return string.match(tostring(name), "^[0-9]+$") ~= nil
end

local function is_tiktok_container(container)
  if exists(join(container, "Documents/Aweme.db")) then return true end
  if exists(join(container, "Documents/mmkv")) then return true end
  if exists(join(container, "Documents/AWEIMGoupMockAvatar")) then return true end
  local docs = join(container, "Documents")
  for _, name in ipairs(list(docs)) do
    if string.match(name, "^AwemeIM%-.+%.db$") then return true end
  end
  return false
end

local function find_tiktok_container()
  for _, base in ipairs(bases) do
    for _, folder in ipairs(list(base)) do
      local container = join(base, folder)
      if is_dir(container) and is_tiktok_container(container) then return container end
    end
  end
  return nil
end

file.writes(OUT, "")
local container = find_tiktok_container()
if not container then
  write("STATUS=NO_CONTAINER")
  write("DONE")
  return true
end

write("TIKTOK_CONTAINER=" .. container)

local docs_uid = ""
local avatar_uid = ""
local docs = join(container, "Documents")
local avatar = join(container, "Documents/AWEIMGoupMockAvatar")

for _, name in ipairs(list(docs)) do
  local p = join(docs, name)
  if docs_uid == "" and is_number_name(name) and is_dir(p) then
    docs_uid = name
    write("DOCUMENTS_UID_FOLDER=" .. name)
    write("DOCUMENTS_PATH=" .. p)
  end
end

for _, name in ipairs(list(avatar)) do
  local p = join(avatar, name)
  if avatar_uid == "" and is_number_name(name) and is_dir(p) then
    avatar_uid = name
    write("AVATAR_UID_FOLDER=" .. name)
    write("AVATAR_PATH=" .. p)
  end
end

write("DOCS_UID=" .. docs_uid)
write("AVATAR_UID=" .. avatar_uid)

if docs_uid ~= "" and avatar_uid ~= "" and docs_uid == avatar_uid then
  write("MATCH=YES")
  write("UID=" .. docs_uid)
elseif docs_uid == "" and avatar_uid == "" then
  write("MATCH=NO")
  write("STATUS=NO_UID_FOLDERS")
else
  write("MATCH=NO")
  write("STATUS=UID_NOT_MATCH")
end

write("DONE")
return true
'''

READ_RESULT_LUA = r'''
file = require("file")
local p = "/var/mobile/Media/1ferver/tiktok_uid_folders.txt"
print(file.reads(p) or "NO_FILE")
return true
'''


def parse_machine_lines(text):
    rows = []
    for raw in text.splitlines():
        raw = raw.strip()
        if not raw:
            continue
        if '|' in raw:
            parts = [p.strip() for p in raw.split('|') if p.strip()]
            if len(parts) >= 3:
                machine, ip = parts[0], parts[-1]
            elif len(parts) >= 2:
                machine, ip = parts[0], parts[1]
            else:
                continue
        else:
            parts = raw.split()
            if len(parts) < 2:
                continue
            machine, ip = parts[0], parts[-1]
        if machine and ip:
            rows.append({'machine': machine, 'ip': ip})
    return rows


def parse_result(text):
    data = {}
    for line in (text or '').splitlines():
        if '=' in line:
            k, v = line.split('=', 1)
            data[k.strip()] = v.strip()
    docs = data.get('DOCS_UID') or data.get('DOCUMENTS_UID_FOLDER') or ''
    avatar = data.get('AVATAR_UID') or data.get('AVATAR_UID_FOLDER') or ''
    uid = data.get('UID') or (docs if docs and docs == avatar else '')
    match = data.get('MATCH', '')
    status = data.get('STATUS', '')
    if uid and match == 'YES':
        state = 'KHỚP'
    elif status == 'NO_CONTAINER':
        state = 'KHÔNG THẤY TIKTOK CONTAINER'
    elif status == 'NO_UID_FOLDERS':
        state = 'KHÔNG THẤY 2 THƯ MỤC UID'
    elif docs or avatar:
        state = 'KHÔNG TRÙNG NHAU'
    else:
        state = status or 'KHÔNG RÕ'
    return docs, avatar, uid, state


class TikTokUIDScanner(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('TikTok UID Folder Scanner')
        self.geometry('1180x760')
        self.configure(bg='#0f172a')
        self.rows = []
        self.running = False
        self._build()
        self._load_config()

    def _build(self):
        style = ttk.Style(self)
        try:
            style.theme_use('clam')
        except Exception:
            pass
        style.configure('TFrame', background='#0f172a')
        style.configure('TLabel', background='#0f172a', foreground='#e5e7eb')
        style.configure('TButton', padding=6)
        style.configure('Treeview', rowheight=26, background='#111827', fieldbackground='#111827', foreground='#e5e7eb')
        style.configure('Treeview.Heading', background='#1f2937', foreground='#f8fafc')

        top = ttk.Frame(self, padding=10)
        top.pack(fill='x')
        ttk.Label(top, text='TikTok UID Scanner: Documents/<số> + Documents/AWEIMGoupMockAvatar/<số>', font=('Arial', 12, 'bold')).pack(side='left')
        ttk.Button(top, text='Cấu hình máy|ip', command=self.open_config).pack(side='right', padx=4)
        ttk.Button(top, text='Xuất kết quả TXT', command=self.export_results).pack(side='right', padx=4)
        ttk.Button(top, text='Quét ALL', command=self.scan_all).pack(side='right', padx=4)

        opts = ttk.Frame(self, padding=(10, 0, 10, 8))
        opts.pack(fill='x')
        ttk.Label(opts, text='Workers:').pack(side='left')
        self.workers_var = tk.StringVar(value='16')
        ttk.Entry(opts, textvariable=self.workers_var, width=5).pack(side='left', padx=(4, 16))
        self.status_var = tk.StringVar(value='Chưa quét')
        ttk.Label(opts, textvariable=self.status_var).pack(side='left')

        cols = ('machine', 'ip', 'docs_uid', 'avatar_uid', 'uid', 'status')
        self.tree = ttk.Treeview(self, columns=cols, show='headings')
        headings = {
            'machine': 'Máy', 'ip': 'IP', 'docs_uid': 'Documents UID',
            'avatar_uid': 'Avatar UID', 'uid': 'UID nếu khớp', 'status': 'Trạng thái'
        }
        widths = {'machine': 80, 'ip': 140, 'docs_uid': 190, 'avatar_uid': 190, 'uid': 190, 'status': 260}
        for c in cols:
            self.tree.heading(c, text=headings[c])
            self.tree.column(c, width=widths[c], anchor='w')
        y = ttk.Scrollbar(self, orient='vertical', command=self.tree.yview)
        x = ttk.Scrollbar(self, orient='horizontal', command=self.tree.xview)
        self.tree.configure(yscrollcommand=y.set, xscrollcommand=x.set)
        self.tree.pack(side='left', fill='both', expand=True, padx=(10, 0), pady=(0, 10))
        y.pack(side='right', fill='y', pady=(0, 10))
        x.pack(side='bottom', fill='x', padx=10)

    def _load_config(self):
        if CONFIG_PATH.exists():
            try:
                data = json.loads(CONFIG_PATH.read_text(encoding='utf-8'))
                self.rows = data.get('rows', []) if isinstance(data, dict) else []
            except Exception:
                self.rows = []
        self.refresh_table()

    def _save_config(self):
        CONFIG_PATH.write_text(json.dumps({'rows': self.rows}, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

    def refresh_table(self):
        self.tree.delete(*self.tree.get_children())
        for row in self.rows:
            self.tree.insert('', 'end', values=(row.get('machine',''), row.get('ip',''), row.get('docs_uid',''), row.get('avatar_uid',''), row.get('uid',''), row.get('status','Chưa quét')))
        self.status_var.set(f'Tổng máy: {len(self.rows)}')

    def open_config(self):
        win = tk.Toplevel(self)
        win.title('Cấu hình máy|ip')
        win.geometry('620x560')
        win.configure(bg='#0f172a')
        ttk.Label(win, text='Nhập dạng: máy|ip, máy ip, hoặc máy|Proxy_xxx|ip').pack(anchor='w', padx=10, pady=(10, 4))
        wrap = ttk.Frame(win)
        wrap.pack(fill='both', expand=True, padx=10, pady=4)
        text = tk.Text(wrap, bg='#111827', fg='#e5e7eb', insertbackground='#e5e7eb', font=('Consolas', 11), wrap='none')
        sy = ttk.Scrollbar(wrap, orient='vertical', command=text.yview)
        sx = ttk.Scrollbar(wrap, orient='horizontal', command=text.xview)
        text.configure(yscrollcommand=sy.set, xscrollcommand=sx.set)
        text.grid(row=0, column=0, sticky='nsew')
        sy.grid(row=0, column=1, sticky='ns')
        sx.grid(row=1, column=0, sticky='ew')
        wrap.rowconfigure(0, weight=1)
        wrap.columnconfigure(0, weight=1)
        text.insert('1.0', '\n'.join(f"{r.get('machine','')}|{r.get('ip','')}" for r in self.rows))

        btns = ttk.Frame(win, padding=10)
        btns.pack(fill='x')
        def save():
            parsed = parse_machine_lines(text.get('1.0', 'end'))
            old = {str(r.get('machine')): r for r in self.rows}
            new_rows = []
            for r in parsed:
                oldr = dict(old.get(str(r['machine']), {}))
                oldr.update({'machine': r['machine'], 'ip': r['ip']})
                new_rows.append(oldr)
            self.rows = new_rows
            self._save_config()
            self.refresh_table()
            win.destroy()
        ttk.Button(btns, text='Lưu', command=save).pack(side='right')

    def scan_one(self, row):
        if XXTouchOpenAPIClient is None:
            raise RuntimeError('Không import được xxtouch_openapi_client')
        ip = str(row.get('ip','')).strip()
        client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=8, timeout=12)
        try:
            client.recycle()
            time.sleep(0.2)
        except Exception:
            pass
        client.spawn(INLINE_LUA)
        time.sleep(1.2)
        client.spawn(READ_RESULT_LUA)
        # Many XXTouch spawn APIs don't return printed output, so download result file directly.
        text = ''
        try:
            text = client.download_text_file('/var/mobile/Media/1ferver/tiktok_uid_folders.txt')
        except Exception as e:
            text = f'STATUS=DOWNLOAD_FAILED\nERROR={e}'
        docs, avatar, uid, state = parse_result(text)
        return {'docs_uid': docs, 'avatar_uid': avatar, 'uid': uid, 'status': state, 'raw': text}

    def scan_all(self):
        if self.running:
            return
        if not self.rows:
            messagebox.showwarning('Thiếu máy', 'Chưa có danh sách máy|ip')
            return
        self.running = True
        self.status_var.set('Đang quét...')
        for r in self.rows:
            r.update({'docs_uid': '', 'avatar_uid': '', 'uid': '', 'status': 'Đang chờ'})
        self.refresh_table()
        threading.Thread(target=self._scan_worker, daemon=True).start()

    def _scan_worker(self):
        try:
            workers = max(1, min(64, int(self.workers_var.get() or '16')))
        except Exception:
            workers = 16
        ok = fail = 0
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futs = {pool.submit(self.scan_one, row): row for row in self.rows}
            for fut in as_completed(futs):
                row = futs[fut]
                try:
                    res = fut.result()
                    row.update(res)
                    if res.get('uid'):
                        ok += 1
                    else:
                        fail += 1
                except Exception as e:
                    row.update({'docs_uid': '', 'avatar_uid': '', 'uid': '', 'status': 'LỖI: ' + str(e)})
                    fail += 1
                self.after(0, self.refresh_table)
                self.after(0, lambda ok=ok, fail=fail: self.status_var.set(f'Đang quét... OK {ok}, lỗi/chưa khớp {fail}'))
        self._save_config()
        self.save_results_file()
        self.running = False
        self.after(0, lambda: self.status_var.set(f'Xong. OK {ok}, lỗi/chưa khớp {fail}. File: {RESULT_PATH.name}'))

    def save_results_file(self):
        lines = ['machine|ip|documents_uid|avatar_uid|uid|status']
        for r in self.rows:
            lines.append('|'.join(str(r.get(k,'')) for k in ['machine','ip','docs_uid','avatar_uid','uid','status']))
        RESULT_PATH.write_text('\n'.join(lines) + '\n', encoding='utf-8')

    def export_results(self):
        self.save_results_file()
        path = filedialog.asksaveasfilename(defaultextension='.txt', initialfile='tiktok_uid_scan_results.txt', filetypes=[('Text', '*.txt'), ('All files', '*.*')])
        if path:
            Path(path).write_text(RESULT_PATH.read_text(encoding='utf-8'), encoding='utf-8')
            messagebox.showinfo('Xuất kết quả', path)


if __name__ == '__main__':
    TikTokUIDScanner().mainloop()

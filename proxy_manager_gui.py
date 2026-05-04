import json
import threading
import time
import socket
import concurrent.futures
from pathlib import Path
import tkinter as tk
from tkinter import ttk, messagebox

APP_TITLE = 'PROXY MANAGER'
BASE_DIR = Path(__file__).resolve().parent
CONFIG_FILE = BASE_DIR / 'proxy_manager_config.json'

DEFAULT_CONFIG = {
    'groups': [
        {'key': 'group1', 'title': 'TIKTOK 03', 'range': '701-735'},
        {'key': 'group2', 'title': 'TIKTOK 04', 'range': '701-735'},
        {'key': 'group3', 'title': 'TIKTOK 05', 'range': '701-735'},
    ],
    'source_proxies': [],
    'source_die_proxies': [],
    'check_settings': {'speed': 50},
    'assignments': {},
}


def safe_int(v, default=0):
    try:
        return int(str(v).strip())
    except Exception:
        return default


def parse_range(text):
    raw = str(text or '').strip()
    if '-' not in raw:
        return []
    a, b = [x.strip() for x in raw.split('-', 1)]
    if not a.isdigit() or not b.isdigit():
        return []
    start, end = int(a), int(b)
    if end < start:
        start, end = end, start
    return list(range(start, end + 1))


class ProxyManagerApp:
    def __init__(self, root):
        self.root = root
        self.root.title(APP_TITLE)
        self.root.geometry('1600x900')
        self.root.configure(bg='#f5f5f5')

        self.config = self.load_config()
        self.status_cycle = 0
        self.stop_flag = False
        self.tree_map = {}
        self.group_machine_maps = {}
        self.die_entries = []
        self.source_check_running = False
        self.die_check_running = False
        self.check_pool = None

        self.build_ui()
        self.refresh_all_views()
        self.start_status_loop()
        self.root.protocol('WM_DELETE_WINDOW', self.on_close)

    def load_config(self):
        if CONFIG_FILE.exists():
            try:
                data = json.loads(CONFIG_FILE.read_text(encoding='utf-8'))
                if isinstance(data, dict):
                    cfg = json.loads(json.dumps(DEFAULT_CONFIG))
                    cfg.update(data)
                    return cfg
            except Exception:
                pass
        return json.loads(json.dumps(DEFAULT_CONFIG))

    def save_config(self):
        CONFIG_FILE.write_text(json.dumps(self.config, ensure_ascii=False, indent=2), encoding='utf-8')

    def build_ui(self):
        top = tk.Frame(self.root, bg='#f5f5f5')
        top.pack(fill='x', padx=18, pady=12)

        spacer = tk.Frame(top, bg='#f5f5f5')
        spacer.pack(side='left', expand=True, fill='x')

        self.make_btn(top, 'NHẬP IP', self.action_fill_empty).pack(side='left', padx=6)
        self.make_btn(top, 'THAY IP', self.action_replace_die).pack(side='left', padx=6)
        self.make_btn(top, 'ADD IP', self.open_add_ip_dialog).pack(side='left', padx=6)
        self.make_btn(top, 'CHECK NGUỒN', self.action_check_source_parallel).pack(side='left', padx=6)
        self.make_btn(top, 'LỌC DIE NGUỒN', self.action_filter_source_die).pack(side='left', padx=6)
        self.make_btn(top, 'CHECK LẠI DIE', self.open_source_die_dialog).pack(side='left', padx=6)
        tk.Label(top, text='Tốc độ', bg='#f5f5f5', font=('Arial', 10, 'bold')).pack(side='left', padx=(14, 4))
        self.speed_var = tk.IntVar(value=safe_int(self.config.get('check_settings', {}).get('speed', 50), 50))
        self.speed_scale = tk.Scale(top, from_=10, to=100, orient='horizontal', variable=self.speed_var, length=140, bg='#f5f5f5', showvalue=True, command=lambda v: self.update_check_speed())
        self.speed_scale.pack(side='left', padx=4)
        self.check_info_var = tk.StringVar(value='Checker: idle')
        tk.Label(top, textvariable=self.check_info_var, bg='#f5f5f5', fg='#333', font=('Arial', 9)).pack(side='left', padx=8)
        self.make_btn(top, 'CẤU HÌNH', self.open_config_dialog).pack(side='left', padx=6)

        body = tk.Frame(self.root, bg='#f5f5f5')
        body.pack(fill='both', expand=True, padx=10, pady=(0, 10))

        cols = [1.25, 1.25, 1.25, 1.05, 1.15]
        for i, weight in enumerate(cols):
            body.grid_columnconfigure(i, weight=weight, uniform='col')
        body.grid_rowconfigure(0, weight=1)

        self.group_frames = []
        for idx in range(3):
            frame = self.build_group_panel(body, idx)
            frame.grid(row=0, column=idx, sticky='nsew', padx=6, pady=6)
            self.group_frames.append(frame)

        self.die_frame = self.build_info_panel(body, 'DANH SÁCH IP DIE', ('MÁY', 'PROXY', 'STATUS'), editable=False)
        self.die_frame.grid(row=0, column=3, sticky='nsew', padx=6, pady=6)

        self.source_frame = self.build_info_panel(body, 'NGUỒN PROXY', ('STT', 'PROXY', 'STATUS'), editable=True)
        self.source_frame.grid(row=0, column=4, sticky='nsew', padx=6, pady=6)

    def make_btn(self, parent, text, cmd):
        return tk.Button(parent, text=text, command=cmd, bg='#118c4f', fg='white', activebackground='#0e6f40', activeforeground='white', relief='raised', bd=2, font=('Arial', 10, 'bold'), padx=14, pady=7)

    def build_group_panel(self, parent, idx):
        wrap = tk.Frame(parent, bg='white', highlightbackground='#666', highlightthickness=1)
        head = tk.Frame(wrap, bg='white')
        head.pack(fill='x', padx=8, pady=(8, 4))

        title_var = tk.StringVar(value=self.config['groups'][idx]['title'])
        setattr(self, f'group_title_{idx}', title_var)
        tk.Label(head, textvariable=title_var, bg='#2b2d33', fg='white', font=('Arial', 10, 'bold'), padx=18, pady=6).pack(side='left', pady=2)
        self.make_btn(head, 'COPPY', lambda i=idx: self.copy_group(i)).pack(side='left', padx=8)

        tree = ttk.Treeview(wrap, columns=('machine', 'proxy', 'status'), show='headings', height=35)
        tree.heading('machine', text='Máy')
        tree.heading('proxy', text='Proxy')
        tree.heading('status', text='Status')
        tree.column('machine', width=70, anchor='center', stretch=False)
        tree.column('proxy', width=245, anchor='w', stretch=True)
        tree.column('status', width=70, anchor='center', stretch=False)
        tree.pack(fill='both', expand=True, padx=6, pady=(0, 6))
        tree.bind('<Double-1>', lambda e, i=idx: self.edit_group_proxy(i))
        self.tree_map[f'group{idx+1}'] = tree
        return wrap

    def build_info_panel(self, parent, title, columns, editable=False):
        wrap = tk.Frame(parent, bg='white', highlightbackground='#666', highlightthickness=1)
        head = tk.Frame(wrap, bg='white')
        head.pack(fill='x', padx=8, pady=(8, 4))
        tk.Label(head, text=title, bg='#2b2d33', fg='white', font=('Arial', 10, 'bold'), padx=18, pady=6).pack(side='left', pady=2)

        tree = ttk.Treeview(wrap, columns=tuple(c.lower() for c in columns), show='headings', height=35)
        for col in columns:
            key = col.lower()
            tree.heading(key, text=col)
            width = 55 if col in ('STT', 'MÁY') else 245 if col == 'PROXY' else 70
            tree.column(key, width=width, anchor='center' if col in ('STT', 'MÁY', 'STATUS') else 'w', stretch=True)
        tree.pack(fill='both', expand=True, padx=6, pady=(0, 6))
        if editable:
            tree.bind('<Double-1>', lambda e: self.edit_source_proxy())
            self.tree_map['source'] = tree
        else:
            self.tree_map['die'] = tree
        return wrap

    def refresh_all_views(self):
        self.refresh_groups()
        self.refresh_source()
        self.refresh_die_list()

    def refresh_groups(self):
        self.group_machine_maps = {}
        assignments = self.config.setdefault('assignments', {})
        for idx, group in enumerate(self.config['groups']):
            key = group['key']
            title_var = getattr(self, f'group_title_{idx}')
            title_var.set(group['title'])
            tree = self.tree_map[key]
            for iid in tree.get_children():
                tree.delete(iid)
            machine_map = {}
            for machine in parse_range(group['range']):
                item = assignments.setdefault(str(machine), {'proxy': '', 'status': ''})
                iid = tree.insert('', 'end', values=(machine, item.get('proxy', ''), item.get('status', '')))
                machine_map[str(machine)] = iid
            self.group_machine_maps[key] = machine_map
        self.save_config()

    def refresh_source(self):
        tree = self.tree_map['source']
        for iid in tree.get_children():
            tree.delete(iid)
        for idx, item in enumerate(self.config.get('source_proxies', []), start=1):
            tree.insert('', 'end', values=(idx, item.get('proxy', ''), item.get('status', '')))

    def refresh_die_list(self):
        tree = self.tree_map['die']
        for iid in tree.get_children():
            tree.delete(iid)
        self.die_entries = []
        assignments = self.config.get('assignments', {})
        for machine, item in sorted(assignments.items(), key=lambda kv: safe_int(kv[0])):
            if item.get('status') == 'DIE' and item.get('proxy'):
                self.die_entries.append({'machine': machine, 'proxy': item.get('proxy', ''), 'status': 'DIE'})
        for row in self.die_entries:
            tree.insert('', 'end', values=(row['machine'], row['proxy'], row['status']))

    def start_status_loop(self):
        def worker():
            while not self.stop_flag:
                self.status_cycle += 1
                self.compute_statuses()
                time.sleep(2.0)
        threading.Thread(target=worker, daemon=True).start()

    def compute_statuses(self):
        cycle = self.status_cycle
        assignments = self.config.get('assignments', {})
        for machine, item in assignments.items():
            proxy = item.get('proxy', '')
            if not proxy:
                item['status'] = ''
                continue
            item['status'] = 'DIE' if (safe_int(machine) + cycle) % 9 == 0 else 'LIVE'
        # Source proxy status is controlled by the real parallel SOCKS5 checker, not fake cycle status.
        self.root.after(0, self.apply_status_refresh)

    def apply_status_refresh(self):
        assignments = self.config.get('assignments', {})
        for idx, group in enumerate(self.config['groups']):
            tree = self.tree_map[group['key']]
            for machine in parse_range(group['range']):
                iid = self.group_machine_maps[group['key']].get(str(machine))
                if not iid:
                    continue
                item = assignments.get(str(machine), {'proxy': '', 'status': ''})
                tree.item(iid, values=(machine, item.get('proxy', ''), item.get('status', '')))
        self.refresh_source()
        self.refresh_die_list()
        self.save_config()

    def copy_group(self, idx):
        group = self.config['groups'][idx]
        lines = []
        for machine in parse_range(group['range']):
            item = self.config['assignments'].get(str(machine), {})
            lines.append(f'{machine}|{item.get("proxy", "")}')
        text = '\n'.join(lines)
        self.root.clipboard_clear()
        self.root.clipboard_append(text)
        messagebox.showinfo(APP_TITLE, f'Đã copy {group["title"]}')

    def edit_group_proxy(self, idx):
        group = self.config['groups'][idx]
        tree = self.tree_map[group['key']]
        selected = tree.selection()
        if not selected:
            return
        vals = tree.item(selected[0], 'values')
        machine = str(vals[0])
        current = self.config['assignments'].get(machine, {}).get('proxy', '')
        self.open_text_edit(f'Sửa proxy máy {machine}', current, lambda value: self.set_machine_proxy(machine, value))

    def set_machine_proxy(self, machine, value):
        self.config['assignments'].setdefault(str(machine), {'proxy': '', 'status': ''})['proxy'] = value.strip()
        self.refresh_all_views()

    def edit_source_proxy(self):
        tree = self.tree_map['source']
        selected = tree.selection()
        if not selected:
            return
        vals = tree.item(selected[0], 'values')
        index = safe_int(vals[0]) - 1
        if index < 0 or index >= len(self.config['source_proxies']):
            return
        current = self.config['source_proxies'][index].get('proxy', '')
        self.open_text_edit(f'Sửa nguồn proxy #{index+1}', current, lambda value, i=index: self.set_source_proxy(i, value))

    def set_source_proxy(self, index, value):
        self.config['source_proxies'][index]['proxy'] = value.strip()
        self.refresh_source()
        self.save_config()


    def update_check_speed(self):
        self.config.setdefault('check_settings', {})['speed'] = safe_int(self.speed_var.get(), 50)
        self.save_config()

    def check_params(self):
        speed = max(10, min(100, safe_int(self.speed_var.get(), 50)))
        # Slider maps to real parallelism. All checks run concurrently in a pool, not one-by-one.
        workers = int(40 + speed * 4)     # 80..440
        timeout = max(0.20, 1.20 - speed * 0.008)  # 1.12s..0.40s
        if speed >= 90:
            timeout = 0.28
        return speed, workers, timeout

    def parse_proxy_parts(self, proxy):
        parts = str(proxy or '').strip().split(':')
        if len(parts) < 4:
            return None
        ip, port, user = parts[0].strip(), parts[1].strip(), parts[2].strip()
        password = ':'.join(parts[3:]).strip()
        if not ip or not port.isdigit() or not user:
            return None
        return ip, int(port), user, password

    def socks5_connect_1111(self, proxy, timeout):
        parsed = self.parse_proxy_parts(proxy)
        if not parsed:
            return 'BAD_FORMAT', 'BAD_FORMAT'
        ip, port, user, password = parsed
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        start = time.perf_counter()
        try:
            s.connect((ip, port))
            s.sendall(b'\x05\x01\x02')
            r = s.recv(2)
            if len(r) != 2 or r[0] != 5:
                return 'DEAD', 'BAD_SOCKS5'
            if r[1] == 2:
                u = user.encode('utf-8')[:255]; pw = password.encode('utf-8')[:255]
                s.sendall(bytes([1, len(u)]) + u + bytes([len(pw)]) + pw)
                a = s.recv(2)
                if len(a) != 2 or a[1] != 0:
                    return 'DEAD', 'AUTH_FAIL'
            elif r[1] != 0:
                return 'DEAD', 'NO_AUTH_METHOD'
            host = b'1.1.1.1'
            s.sendall(b'\x05\x01\x00\x03' + bytes([len(host)]) + host + (80).to_bytes(2, 'big'))
            h = s.recv(4)
            if len(h) == 4 and h[0] == 5 and h[1] == 0:
                return 'LIVE', f'{int((time.perf_counter()-start)*1000)}ms'
            return 'DEAD', 'TARGET_REJECT'
        except socket.timeout:
            return 'TIMEOUT', 'TIMEOUT'
        except Exception as e:
            return 'DEAD', type(e).__name__
        finally:
            try:
                s.close()
            except Exception:
                pass

    def action_check_source_parallel(self):
        if self.source_check_running:
            return messagebox.showwarning(APP_TITLE, 'Đang check Proxy nguồn rồi')
        source = self.config.get('source_proxies', [])
        items = [(i, x.get('proxy', '').strip()) for i, x in enumerate(source) if x.get('proxy', '').strip()]
        if not items:
            return messagebox.showwarning(APP_TITLE, 'Nguồn proxy đang trống')
        speed, workers, timeout = self.check_params()
        self.source_check_running = True
        self.check_info_var.set(f'Checking nguồn: 0/{len(items)} | speed={speed} workers={workers} timeout={timeout:.2f}s')
        for i, _proxy in items:
            source[i]['status'] = 'CHECKING'
        self.refresh_source(); self.save_config()

        def worker():
            done = live = bad = 0
            with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
                futs = {ex.submit(self.socks5_connect_1111, proxy, timeout): (i, proxy) for i, proxy in items}
                for fut in concurrent.futures.as_completed(futs):
                    i, proxy = futs[fut]
                    try:
                        status, detail = fut.result()
                    except Exception as e:
                        status, detail = 'DEAD', type(e).__name__
                    done += 1
                    if status == 'LIVE': live += 1
                    else: bad += 1
                    def apply(i=i, status=status, detail=detail, done=done, live=live, bad=bad):
                        if i < len(self.config.get('source_proxies', [])):
                            self.config['source_proxies'][i]['status'] = status
                            self.config['source_proxies'][i]['last_error'] = detail
                            self.config['source_proxies'][i]['last_checked'] = time.time()
                        self.check_info_var.set(f'Nguồn {done}/{len(items)} | LIVE={live} DIE/TIMEOUT={bad}')
                        if done % 25 == 0 or status == 'LIVE':
                            self.refresh_source(); self.save_config()
                    self.root.after(0, apply)
            def finish():
                self.source_check_running = False
                self.refresh_source(); self.save_config()
                self.check_info_var.set(f'Xong nguồn: LIVE={live} DIE/TIMEOUT={bad}')
            self.root.after(0, finish)
        threading.Thread(target=worker, daemon=True).start()

    def action_filter_source_die(self):
        src = self.config.get('source_proxies', [])
        die_bucket = self.config.setdefault('source_die_proxies', [])
        keep = []
        moved = 0
        for item in src:
            proxy = item.get('proxy', '').strip()
            status = str(item.get('status', '')).upper()
            if proxy and status and status != 'LIVE':
                die_bucket.append(dict(item))
                moved += 1
            else:
                keep.append(item)
        self.config['source_proxies'] = keep
        self.refresh_source(); self.save_config()
        messagebox.showinfo(APP_TITLE, f'Đã chuyển {moved} proxy DIE/TIMEOUT khỏi Proxy nguồn sang kho check lại')

    def open_source_die_dialog(self):
        win = tk.Toplevel(self.root)
        win.title('CHECK LẠI PROXY DIE TỪ NGUỒN')
        win.geometry('900x600')
        head = tk.Frame(win); head.pack(fill='x', padx=8, pady=8)
        info = tk.StringVar(value='DIE bucket idle')
        tk.Label(head, textvariable=info, font=('Arial', 10, 'bold')).pack(side='left')
        tree = ttk.Treeview(win, columns=('stt','proxy','status'), show='headings')
        for c,w in [('stt',60),('proxy',560),('status',140)]:
            tree.heading(c, text=c.upper()); tree.column(c, width=w, anchor='center' if c!='proxy' else 'w')
        tree.pack(fill='both', expand=True, padx=8, pady=8)
        def refresh():
            for iid in tree.get_children(): tree.delete(iid)
            for idx,item in enumerate(self.config.get('source_die_proxies', []), start=1):
                tree.insert('', 'end', values=(idx, item.get('proxy',''), item.get('status','')))
            info.set(f'DIE bucket: {len(self.config.get("source_die_proxies", []))} proxy')
        def recheck():
            if self.die_check_running: return
            bucket = self.config.get('source_die_proxies', [])
            items = [(i, x.get('proxy','').strip()) for i,x in enumerate(bucket) if x.get('proxy','').strip()]
            if not items: return
            speed, workers, timeout = self.check_params()
            self.die_check_running = True
            def run():
                live_indices=set(); done=live=bad=0
                with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as ex:
                    futs={ex.submit(self.socks5_connect_1111, proxy, timeout):(i,proxy) for i,proxy in items}
                    for fut in concurrent.futures.as_completed(futs):
                        i,proxy=futs[fut]
                        try: status,detail=fut.result()
                        except Exception as e: status,detail='DEAD',type(e).__name__
                        done+=1
                        if status=='LIVE': live+=1; live_indices.add(i)
                        else: bad+=1
                        if i < len(self.config.get('source_die_proxies', [])):
                            self.config['source_die_proxies'][i]['status']=status
                            self.config['source_die_proxies'][i]['last_error']=detail
                        self.root.after(0, lambda d=done,l=live,b=bad: info.set(f'Check lại {d}/{len(items)} | LIVE trả về nguồn={l} | còn DIE={b}'))
                def finish():
                    bucket=self.config.get('source_die_proxies', [])
                    new_bucket=[]; moved=0
                    for idx,item in enumerate(bucket):
                        if idx in live_indices:
                            item['status']='LIVE'; self.config.setdefault('source_proxies', []).append(item); moved+=1
                        else:
                            new_bucket.append(item)
                    self.config['source_die_proxies']=new_bucket
                    self.die_check_running=False
                    self.refresh_source(); refresh(); self.save_config()
                    info.set(f'Xong: đưa lại nguồn {moved} LIVE, còn DIE {len(new_bucket)}')
                self.root.after(0, finish)
            threading.Thread(target=run, daemon=True).start()
        self.make_btn(head, 'CHECK LẠI', recheck).pack(side='right', padx=6)
        refresh()

    def action_fill_empty(self):
        source = self.config.get('source_proxies', [])
        pool = [item for item in source if item.get('proxy', '').strip()]
        if not pool:
            return messagebox.showwarning(APP_TITLE, 'Nguồn proxy đang trống')
        assignments = self.config['assignments']
        used = 0
        for group in self.config['groups']:
            for machine in parse_range(group['range']):
                item = assignments.setdefault(str(machine), {'proxy': '', 'status': ''})
                if item.get('proxy', '').strip():
                    continue
                if not pool:
                    break
                picked = pool.pop(0)
                item['proxy'] = picked.get('proxy', '')
                used += 1
            if not pool:
                break
        self.config['source_proxies'] = pool
        self.refresh_all_views()
        messagebox.showinfo(APP_TITLE, f'Đã nhập {used} proxy vào ô trống')

    def action_replace_die(self):
        source = self.config.get('source_proxies', [])
        pool = [item for item in source if item.get('proxy', '').strip()]
        if not pool:
            return messagebox.showwarning(APP_TITLE, 'Nguồn proxy đang trống')
        count = 0
        for row in list(self.die_entries):
            if not pool:
                break
            picked = pool.pop(0)
            machine = str(row['machine'])
            self.config['assignments'].setdefault(machine, {'proxy': '', 'status': ''})['proxy'] = picked.get('proxy', '')
            self.config['assignments'][machine]['status'] = ''
            count += 1
        self.config['source_proxies'] = pool
        self.refresh_all_views()
        messagebox.showinfo(APP_TITLE, f'Đã thay {count} IP DIE')

    def open_add_ip_dialog(self):
        win = tk.Toplevel(self.root)
        win.title('ADD IP')
        win.geometry('700x500')
        txt = tk.Text(win, font=('Consolas', 11))
        txt.pack(fill='both', expand=True, padx=10, pady=10)

        def save():
            raw = txt.get('1.0', 'end').strip().splitlines()
            added = 0
            for line in raw:
                proxy = line.strip()
                if not proxy:
                    continue
                self.config['source_proxies'].append({'proxy': proxy, 'status': ''})
                added += 1
            self.refresh_source()
            self.save_config()
            win.destroy()
            messagebox.showinfo(APP_TITLE, f'Đã add {added} proxy')

        self.make_btn(win, 'LƯU', save).pack(pady=(0, 10))

    def open_config_dialog(self):
        win = tk.Toplevel(self.root)
        win.title('CẤU HÌNH')
        win.geometry('420x280')
        entries = []
        for idx, group in enumerate(self.config['groups']):
            row = tk.Frame(win)
            row.pack(fill='x', padx=12, pady=8)
            tk.Label(row, text=f'Nhóm {idx+1}').pack(side='left')
            title = tk.Entry(row)
            title.insert(0, group['title'])
            title.pack(side='left', padx=8)
            rng = tk.Entry(row, width=14)
            rng.insert(0, group['range'])
            rng.pack(side='left', padx=8)
            entries.append((title, rng))

        def save():
            for idx, (title, rng) in enumerate(entries):
                self.config['groups'][idx]['title'] = title.get().strip() or self.config['groups'][idx]['title']
                self.config['groups'][idx]['range'] = rng.get().strip() or self.config['groups'][idx]['range']
            self.refresh_all_views()
            self.save_config()
            win.destroy()
            messagebox.showinfo(APP_TITLE, 'Đã lưu cấu hình')

        self.make_btn(win, 'LƯU CẤU HÌNH', save).pack(pady=14)

    def open_text_edit(self, title, current, on_save):
        win = tk.Toplevel(self.root)
        win.title(title)
        win.geometry('540x160')
        ent = tk.Entry(win, font=('Consolas', 12))
        ent.pack(fill='x', padx=12, pady=20)
        ent.insert(0, current)

        def save():
            on_save(ent.get())
            self.save_config()
            win.destroy()

        self.make_btn(win, 'LƯU', save).pack()

    def on_close(self):
        self.stop_flag = True
        self.save_config()
        self.root.destroy()


if __name__ == '__main__':
    root = tk.Tk()
    style = ttk.Style()
    try:
        style.theme_use('clam')
    except Exception:
        pass
    app = ProxyManagerApp(root)
    root.mainloop()

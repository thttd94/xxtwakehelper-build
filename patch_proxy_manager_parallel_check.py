from pathlib import Path
p=Path('proxy_manager_gui.py')
s=p.read_text(encoding='utf-8')

s=s.replace("import threading\nimport time\nfrom pathlib import Path", "import threading\nimport time\nimport socket\nimport concurrent.futures\nfrom pathlib import Path")

s=s.replace("import tkinter as tk\nfrom tkinter import ttk, messagebox", "import tkinter as tk\nfrom tkinter import ttk, messagebox")

s=s.replace("    'source_proxies': [],\n    'assignments': {},", "    'source_proxies': [],\n    'source_die_proxies': [],\n    'check_settings': {'speed': 50},\n    'assignments': {},")

s=s.replace("        self.die_entries = []\n\n        self.build_ui()", "        self.die_entries = []\n        self.source_check_running = False\n        self.die_check_running = False\n        self.check_pool = None\n\n        self.build_ui()")

old="""        self.make_btn(top, 'NHẬP IP', self.action_fill_empty).pack(side='left', padx=6)
        self.make_btn(top, 'THAY IP', self.action_replace_die).pack(side='left', padx=6)
        self.make_btn(top, 'ADD IP', self.open_add_ip_dialog).pack(side='left', padx=6)
        self.make_btn(top, 'CẤU HÌNH', self.open_config_dialog).pack(side='left', padx=6)
"""
new="""        self.make_btn(top, 'NHẬP IP', self.action_fill_empty).pack(side='left', padx=6)
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
"""
s=s.replace(old,new)

s=s.replace("""        self.source_frame = self.build_info_panel(body, 'NGUỒN PROXY', ('STT', 'PROXY', 'STATUS'), editable=True)
        self.source_frame.grid(row=0, column=4, sticky='nsew', padx=6, pady=6)
""", """        self.source_frame = self.build_info_panel(body, 'NGUỒN PROXY', ('STT', 'PROXY', 'STATUS'), editable=True)
        self.source_frame.grid(row=0, column=4, sticky='nsew', padx=6, pady=6)
""")

# disable fake status loop for source proxies; keep assignments simulated as before
s=s.replace("""        for idx, item in enumerate(self.config.get('source_proxies', []), start=1):
            proxy = item.get('proxy', '')
            if not proxy:
                item['status'] = ''
                continue
            item['status'] = 'DIE' if (idx + cycle) % 11 == 0 else 'LIVE'
        self.root.after(0, self.apply_status_refresh)
""", """        # Source proxy status is controlled by the real parallel SOCKS5 checker, not fake cycle status.
        self.root.after(0, self.apply_status_refresh)
""")

insert_before="""    def action_fill_empty(self):
"""
methods=r'''
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

'''
s=s.replace(insert_before, methods+insert_before)
p.write_text(s,encoding='utf-8')
print('patched proxy_manager_gui.py')

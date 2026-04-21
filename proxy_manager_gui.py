import json
import threading
import time
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
        for idx, item in enumerate(self.config.get('source_proxies', []), start=1):
            proxy = item.get('proxy', '')
            if not proxy:
                item['status'] = ''
                continue
            item['status'] = 'DIE' if (idx + cycle) % 11 == 0 else 'LIVE'
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

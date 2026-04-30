import base64
import json
import threading
import time
import tkinter as tk
import urllib.error
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from tkinter import ttk, messagebox, filedialog

LUA_DIR = Path(__file__).with_name('lua')
FLOATING_MENU_PATH = LUA_DIR / 'floating_menu.lua'

from xxtouch_openapi_client import XXTouchOpenAPIClient, XXTouchOpenAPIError

CONFIG_PATH = Path(__file__).with_name('xxtouch_router_config.json')
TXT_POOL_PATH = Path(__file__).with_name('xxtouch_txt_pool.json')
DEFAULT_ROUTERS = [
    {
        'name': 'TIKTOK 03',
        'rows': [
            {'stt': '1', 'machine': '1', 'ip': '192.14.5.1', 'udid': '', 'network': 'Unknown', 'screen': 'Unknown', 'app': '-', 'xxtouch': 'Unknown', 'updated': '-', 'note': ''},
            {'stt': '2', 'machine': '2', 'ip': '192.14.5.2', 'udid': '', 'network': 'Unknown', 'screen': 'Unknown', 'app': '-', 'xxtouch': 'Unknown', 'updated': '-', 'note': ''},
        ],
        'logs': [],
        'selected_files': [],
        'send_dest': 'examples',
        'txt_lines': [],
    }
]


def load_router_config():
    if CONFIG_PATH.exists():
        try:
            data = json.loads(CONFIG_PATH.read_text(encoding='utf-8'))
            if isinstance(data, list) and data:
                return [ensure_router_defaults(item) for item in data]
        except Exception:
            pass
    return [ensure_router_defaults(item) for item in json.loads(json.dumps(DEFAULT_ROUTERS, ensure_ascii=False))]


def load_txt_pool():
    if TXT_POOL_PATH.exists():
        try:
            data = json.loads(TXT_POOL_PATH.read_text(encoding='utf-8'))
            if isinstance(data, list):
                return [str(line).strip() for line in data if str(line).strip()]
        except Exception:
            pass
    return []


def save_txt_pool(lines):
    safe = [str(line).strip() for line in (lines or []) if str(line).strip()]
    TXT_POOL_PATH.write_text(json.dumps(safe, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def save_router_config(routers):
    safe = []
    for router in routers:
        item = {}
        for key, value in router.items():
            if str(key).startswith('_'):
                continue
            item[key] = value
        safe.append(item)
    CONFIG_PATH.write_text(json.dumps(safe, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def ensure_router_defaults(router):
    router.setdefault('logs', [])
    router.setdefault('selected_files', [])
    router.setdefault('send_dest', 'examples')
    router.setdefault('ui_mode', 'LIST MAY')
    router.setdefault('ui_group', 'all')
    router.setdefault('ui_list', router.get('ui_group', 'all') or 'all')
    router.setdefault('remote_select', 'all')
    router.setdefault('group3_app', 'TikTok Lite')
    router.setdefault('inline_script', 'device = require("device")\nsys = require("sys")\n\nwhile (device.is_screen_locked()) do\n    device.unlock_screen()\n    sys.msleep(1000)\nend\n\nsys.toast("Screen unlocked, script starting")\n')
    router.setdefault('ui_home_expanded', '')
    router.setdefault('last_failed_action', None)
    return router


def now_text():
    from datetime import datetime
    return datetime.now().strftime('%H:%M:%S')


class XXTouchOnlyDemo(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title('XXTouch Jobs Demo')
        self.geometry('1580x940')
        self.configure(bg='#0b1220')
        self.routers = load_router_config()
        self.inline_editor = None
        self.inline_router_label = None
        self.router_tabs = None
        self.txt_pool = load_txt_pool()
        self.router_devices_trees = {}
        self.router_logs_widgets = {}
        self.router_file_widgets = {}
        self.remote_panel = None
        self.remote_header_label = None
        self.remote_status_label = None
        self.remote_preview_label = None
        self.remote_machine_list_frame = None
        self.remote_page_label = None
        self.remote_select_entry = None
        self.remote_preview_wrap = None
        self.remote_zoom_var = None
        self.remote_refresh_job = None
        self.remote_screen_info = {'width': None, 'height': None}
        self.remote_context = {'router': None, 'machines': [], 'index': 0, 'token': 0}
        self.group3_schedule_jobs = {}
        self.group3_schedule_tree = None
        self._style()
        self._build()
        self._restore_runtime_prefs()

    def _style(self):
        style = ttk.Style(self)
        try:
            style.theme_use('clam')
        except Exception:
            pass
        style.configure('App.TFrame', background='#0b1220')
        style.configure('Card.TFrame', background='#111827')
        style.configure('Title.TLabel', background='#111827', foreground='#f8fafc', font=('Arial', 12, 'bold'))
        style.configure('Sub.TLabel', background='#111827', foreground='#94a3b8', font=('Arial', 9))
        style.configure('HeadTab.TNotebook', background='#0b1220', borderwidth=0)
        style.configure('HeadTab.TNotebook.Tab', padding=(14, 8), font=('Arial', 10, 'bold'), background='#1f2937', foreground='#e5e7eb')
        style.map('HeadTab.TNotebook.Tab', background=[('selected', '#2563eb')], foreground=[('selected', '#ffffff')])
        style.configure('TButton', background='#1f2937', foreground='#f8fafc', padding=6)
        style.map('TButton', background=[('active', '#374151')])
        style.configure('TEntry', fieldbackground='#0f172a', foreground='#f8fafc')
        style.configure('TCombobox', fieldbackground='#0f172a', foreground='#f8fafc')
        style.configure('TLabelframe', background='#111827', foreground='#f8fafc')
        style.configure('TLabelframe.Label', background='#111827', foreground='#f8fafc')
        style.configure('Treeview', background='#0f172a', fieldbackground='#0f172a', foreground='#e5e7eb', rowheight=28)
        style.configure('Treeview.Heading', background='#1f2937', foreground='#f8fafc')

    def _build(self):
        root = ttk.Frame(self, style='App.TFrame', padding=12)
        root.pack(fill='both', expand=True)
        self.main_layout = ttk.Frame(root, style='App.TFrame')
        self.main_layout.pack(fill='both', expand=True)
        self.shell = ttk.Frame(self.main_layout, style='Card.TFrame', padding=14, width=1180)
        self.shell.pack(side='left', fill='both', expand=True)
        self._header(self.shell)
        self._build_router_tabs()
        self._update_header_status()

    def _header(self, parent):
        head = ttk.Frame(parent, style='Card.TFrame')
        head.pack(fill='x', pady=(0, 12))
        left = ttk.Frame(head, style='Card.TFrame')
        left.pack(side='left')
        ttk.Label(left, text='XXTOUCH PY GUI', style='Title.TLabel').pack(anchor='w')
        ttk.Label(left, text='Bản chính theo router, log và device state theo từng router', style='Sub.TLabel').pack(anchor='w')
        center = ttk.Frame(head, style='Card.TFrame')
        center.pack(side='left', expand=True)
        self.header_status_label = tk.Label(center, text='', bg='#0f172a', fg='#60a5fa', font=('Arial', 10, 'bold'), padx=12, pady=7)
        self.header_status_label.pack()
        right = ttk.Frame(head, style='Card.TFrame')
        right.pack(side='right')
        ttk.Button(right, text='Cấu hình router | Máy|IP', command=self._open_ip_config_dialog).pack(side='left', padx=(0, 8))
        self.router_count_label = ttk.Label(right, text='', style='Sub.TLabel')
        self.router_count_label.pack(side='left')
        self._refresh_router_count()

    def _refresh_router_count(self):
        self.router_count_label.config(text=f'Tổng router: {len(self.routers)}')
        self._update_header_status()

    def _build_router_tabs(self):
        if self.router_tabs is not None:
            self.router_tabs.destroy()
        self.router_devices_trees.clear()
        self.router_logs_widgets.clear()
        self.router_file_widgets.clear()
        self.router_tabs = ttk.Notebook(self.shell, style='HeadTab.TNotebook')
        self.router_tabs.pack(fill='both', expand=True)
        self.router_tabs.bind('<<NotebookTabChanged>>', self._on_router_tab_changed)
        self._refresh_router_count()
        for router in self.routers:
            router_frame = ttk.Frame(self.router_tabs, style='Card.TFrame', padding=12)
            self.router_tabs.add(router_frame, text=router['name'])
            self._router_tab(router_frame, router)
        self._update_header_status()

    def _router_tab(self, parent, router):
        router_notebook = ttk.Notebook(parent, style='HeadTab.TNotebook')
        router_notebook.pack(fill='both', expand=True)
        jobs_tab = ttk.Frame(router_notebook, style='Card.TFrame', padding=12)
        devices_tab = ttk.Frame(router_notebook, style='Card.TFrame', padding=12)
        logs_tab = ttk.Frame(router_notebook, style='Card.TFrame', padding=12)
        router_notebook.add(jobs_tab, text='XXTouch Jobs')
        router_notebook.add(devices_tab, text='Devices Info')
        router_notebook.add(logs_tab, text='Logs')
        self._jobs_tab(jobs_tab, router)
        self._devices_tab(devices_tab, router)
        self._logs_tab(logs_tab, router)

    def _jobs_tab(self, parent, router):
        self._controls(parent, router)
        self._jobs_body(parent, router)

    def _controls(self, parent, router):
        box = ttk.Frame(parent, style='Card.TFrame')
        box.pack(fill='x', pady=(0, 12))
        ttk.Label(box, text=f"Router hiện tại: {router['name']}", style='Sub.TLabel').pack(anchor='w', pady=(0, 8))

        row1 = ttk.Frame(box, style='Card.TFrame')
        row1.pack(fill='x', pady=(0, 8))
        ttk.Label(row1, text='CHỌN MÁY', style='Title.TLabel').pack(side='left', padx=(0, 8))
        ttk.Label(row1, text='List Máy', style='Sub.TLabel').pack(side='left', padx=(0, 8))
        list_entry = ttk.Entry(row1, width=26)
        saved_machine_select = str(router.get('ui_list', router.get('ui_group', ''))).strip()
        if not saved_machine_select:
            saved_machine_select = 'all'
        list_entry.insert(0, saved_machine_select)
        list_entry.pack(side='left', padx=(0, 8))
        router['_ui_list_widget'] = list_entry
        list_entry.bind('<KeyRelease>', lambda _e: self._save_router_machine_ui(router))
        router['ui_mode'] = 'LIST MAY'
        self.after(50, lambda: self._save_router_machine_ui(router))

        primary_row = ttk.Frame(box, style='Card.TFrame')
        primary_row.pack(fill='x', pady=(0, 8))
        primary_specs = [
            ('STOP SCRIPT', lambda r=router: self._run_background(r, self._stop_scripts_for_router)),
            ('HOME', lambda r=router: self._run_background(r, self._run_home_for_router)),
            ('LOCK HOME', lambda r=router: self._run_background(r, self._run_lock_home_for_router)),
            ('GỠ APP RÁC', lambda r=router: self._run_background(r, self._run_clear_app_for_router)),
            ('RE-ACTION', lambda r=router: self._run_background(r, self._rerun_last_failed_action_for_router)),
            ('CHỌN FILE', lambda r=router: self._choose_files_for_router(r)),
            ('SYNC EXAMPLES', lambda r=router: self._sync_examples_from_repo_for_router(r)),
            ('SEND FILE', lambda r=router: self._open_send_file_dest_popup(r)),
        ]
        for text, cmd in primary_specs:
            ttk.Button(primary_row, text=text, command=cmd).pack(side='left', padx=(0, 6))

        ttk.Button(primary_row, text='MORE', command=lambda r=router: self._open_more_popup(r)).pack(side='left', padx=(8, 6))

        default_remote = 'all'
        rows = router.get('rows', [])
        if rows:
            first_machine = str(rows[0].get('machine', '')).strip()
            last_machine = str(rows[-1].get('machine', '')).strip()
            if first_machine and last_machine:
                default_remote = f'{first_machine}-{last_machine}' if first_machine != last_machine else first_machine
        remote_entry = ttk.Entry(primary_row, width=16)
        remote_entry.insert(0, str(router.get('remote_select', default_remote)))
        remote_entry.pack(side='left', padx=(8, 6))
        router['_ui_remote_entry'] = remote_entry
        ttk.Button(primary_row, text='REMOTE', command=lambda r=router: self._open_remote_panel(r)).pack(side='left', padx=(0, 6))

        app_group = ttk.LabelFrame(box, text='Quản lý app', padding=10)
        app_group.pack(fill='x', pady=(0, 8))
        app_specs = [
            ('GỠ TIKTOK LITE', lambda r=router: self._run_background(r, self._run_remove_tiktok_lite_for_router)),
            ('GỠ TIKTOK', lambda r=router: self._run_background(r, self._run_remove_tiktok_for_router)),
            ('CÀI TIKTOK', lambda r=router: self._run_background(r, self._run_install_tiktok_for_router)),
            ('CÀI TIKTOK LITE', lambda r=router: self._run_background(r, self._run_install_tiktok_lite_for_router)),
            ('ĐÓNG ỨNG DỤNG', lambda r=router: self._run_background(r, self._run_quit_apps_for_router)),
        ]
        for idx, (text, cmd) in enumerate(app_specs):
            ttk.Button(app_group, text=text, command=cmd).grid(row=0, column=idx, padx=4, pady=2, sticky='w')

        file_row = ttk.Frame(box, style='Card.TFrame')
        file_row.pack(fill='x')
        router['_ui_file_row'] = file_row
        file_label = ttk.Label(file_row, text='File đã chọn', style='Sub.TLabel')
        file_label.pack(side='left', padx=(0, 8))
        router['_ui_file_label'] = file_label
        view_btn = ttk.Button(file_row, text='Xem danh sách file', command=lambda r=router: self._open_selected_files_popup(r))
        view_btn.pack(side='left', padx=(0, 8))
        router['_ui_file_view_btn'] = view_btn
        files_box = tk.Frame(file_row, bg='#ffffff')
        files_box.pack(side='left', fill='x', expand=True)
        router['_ui_files_box'] = files_box
        self.router_file_widgets[id(router)] = files_box
        self._refresh_selected_files(router)

    def _jobs_body(self, parent, router):
        body = ttk.Frame(parent, style='Card.TFrame')
        body.pack(fill='both', expand=True)
        body.columnconfigure(0, weight=3)
        body.columnconfigure(1, weight=2)
        router['_ui_body_left'] = left = ttk.Frame(body, style='Card.TFrame')
        router['_ui_body_right'] = right = ttk.Frame(body, style='Card.TFrame')
        left.grid(row=0, column=0, sticky='nsew', padx=(0, 8))
        right.grid(row=0, column=1, sticky='nsew', padx=(8, 0))
        router['_ui_body'] = body
        self._group3(left, router)
        self._schedule(left)
        self._inline_editor(right)
        return
        left = ttk.Frame(body, style='Card.TFrame')
        right = ttk.Frame(body, style='Card.TFrame')
        left = ttk.Frame(body, style='Card.TFrame')
        left.grid(row=0, column=0, sticky='nsew', padx=(0, 8))
        right = ttk.Frame(body, style='Card.TFrame')
        right.grid(row=0, column=1, sticky='nsew', padx=(8, 0))
        self._group3(left, router)
        self._schedule(left)
        self._logs(left, router)
        self._inline_editor(right)

    def _group3(self, parent, router):
        card = ttk.Frame(parent, style='Card.TFrame', padding=12)
        card.pack(fill='x', pady=(0, 10))
        top = ttk.Frame(card, style='Card.TFrame')
        top.pack(fill='x', pady=(0, 10))
        ttk.Label(top, text='Chọn app chạy nhóm 3:', style='Sub.TLabel').pack(side='left')
        app = ttk.Combobox(top, values=['TikTok Lite', 'TikTok'], width=18, state='readonly', foreground='#000000')
        saved_app = str(router.get('group3_app', 'TikTok Lite')).strip()
        if saved_app not in ['TikTok Lite', 'TikTok']:
            saved_app = 'TikTok Lite'
        router['group3_app'] = saved_app
        app.set(saved_app)
        app.pack(side='left', padx=8)
        router['_ui_group3_app'] = app
        app.bind('<<ComboboxSelected>>', lambda _e, r=router, w=app: self._save_group3_app(r, w))

        action_specs = [
            {'name': 'Nuôi Phôi', 'key': 'nurture', 'schedule': True, 'time': '00:00', 'count': '1'},
            {'name': 'Chạy Event Video 180', 'key': 'event_video_180', 'schedule': True, 'time': '00:15', 'count': '2'},
            {'name': 'Chạy Event DD 20p', 'key': 'event_dd_20p', 'schedule': True, 'time': '00:30', 'count': '1'},
            {'name': 'Safari', 'key': 'safari', 'schedule': False, 'time': '', 'count': ''},
            {'name': 'UI', 'key': 'ui', 'schedule': False, 'time': '', 'count': ''},
        ]
        router['_ui_group3_controls'] = {}
        for spec in action_specs:
            name = spec['name']
            action_key = spec['key']
            row = ttk.Frame(card, style='Card.TFrame')
            row.pack(fill='x', pady=4)
            ttk.Button(row, text=name, width=24, command=lambda a=action_key, r=router: self._run_background(r, lambda rr: self._run_group3_action(rr, a))).pack(side='left', padx=(0, 8))
            if spec['schedule']:
                time_entry = ttk.Entry(row, width=8)
                time_entry.insert(0, spec['time'])
                time_entry.pack(side='left', padx=(0, 8))
                count_entry = ttk.Entry(row, width=6)
                count_entry.insert(0, spec['count'])
                count_entry.pack(side='left', padx=(0, 8))
                schedule_btn = ttk.Button(row, text='Hẹn giờ', command=lambda a=action_key, n=name, r=router: self._toggle_group3_schedule(r, a, n))
                schedule_btn.pack(side='left', padx=(0, 8))
                cancel_btn = ttk.Button(row, text='✕', width=3, command=lambda a=action_key, r=router: self._cancel_group3_schedule(r, a))
                cancel_btn.pack(side='left')
                router['_ui_group3_controls'][action_key] = {
                    'time': time_entry,
                    'count': count_entry,
                    'schedule': schedule_btn,
                    'cancel': cancel_btn,
                    'name': name,
                }
            else:
                ttk.Label(row, text='Chạy ngay, không hẹn giờ', style='Sub.TLabel').pack(side='left', padx=(0, 8))

    def _save_group3_app(self, router, widget):
        value = widget.get().strip()
        if value not in ['TikTok Lite', 'TikTok']:
            value = 'TikTok Lite'
            try:
                widget.set(value)
            except Exception:
                pass
        router['group3_app'] = value
        save_router_config(self.routers)

    def _group3_script_path(self, router, action_key):
        app_widget = router.get('_ui_group3_app')
        app_label = app_widget.get().strip() if app_widget else router.get('group3_app', 'TikTok Lite')
        app_key = 'tiktok' if app_label == 'TikTok' else 'tiktok_lite'
        if action_key == 'safari':
            return LUA_DIR / 'Group3_safari.lua'
        if action_key == 'ui':
            return FLOATING_MENU_PATH
        mapping = {
            ('nurture', 'tiktok'): 'Group3_NuoiPhoi_tiktok.lua',
            ('event_video_180', 'tiktok'): 'Group3_EventVideo180_tiktok.lua',
            ('event_dd_20p', 'tiktok'): 'Group3_EventDD20p_tiktok.lua',
            ('nurture', 'tiktok_lite'): 'Group3_NuoiPhoi_tiktok_lite.lua',
            ('event_video_180', 'tiktok_lite'): 'Group3_EventVideo180_tiktok_lite.lua',
            ('event_dd_20p', 'tiktok_lite'): 'Group3_EventDD20p_tiktok_lite.lua',
        }
        return LUA_DIR / mapping[(action_key, app_key)]

    def _run_group3_action(self, router, action_key):
        script_path = self._group3_script_path(router, action_key)
        if not script_path.exists():
            self._append_router_log(router, f'Không thấy file lua: {script_path.name}')
            return
        command = script_path.read_text(encoding='utf-8')
        if action_key == 'event_dd_20p':
            self._run_spawn_batched_for_router(router, command, script_path.name, batch_size=10, batch_delay=10, stop_first=True, read_timeout=12)
            return
        if action_key == 'ui':
            self._run_floating_ui_for_router(router, script_path)
            return
        self._run_spawn_command_for_router(router, command, script_path.name, stop_first=True, read_timeout=12)

    def _parse_mmss(self, value):
        raw = str(value or '').strip()
        if not raw or ':' not in raw:
            return 0
        try:
            mm, ss = raw.split(':', 1)
            mm_i = int(mm)
            ss_i = int(ss)
            if mm_i < 0 or ss_i < 0 or ss_i >= 60:
                return 0
            return mm_i * 60 + ss_i
        except Exception:
            return 0

    def _toggle_group3_schedule(self, router, action_key, action_name):
        controls = (router.get('_ui_group3_controls') or {}).get(action_key)
        if not controls:
            return
        seconds = self._parse_mmss(controls['time'].get())
        try:
            runs = int(str(controls['count'].get()).strip())
        except Exception:
            runs = 0
        if seconds <= 0:
            self._append_router_log(router, f'{action_name}: nhập thời gian MM:SS hợp lệ')
            return
        if runs <= 0:
            self._append_router_log(router, f'{action_name}: nhập SL chạy hợp lệ')
            return
        app_widget = router.get('_ui_group3_app')
        app_label = app_widget.get().strip() if app_widget else router.get('group3_app', 'TikTok Lite')
        self._cancel_group3_schedule(router, action_key, quiet=True)
        state = {
            'remaining': max(0, runs - 1),
            'seconds': seconds,
            'label': action_name,
            'app': app_label,
            'interval_text': controls['time'].get().strip(),
            'next_run_at': None,
            'status': 'Đang chờ',
            'total_runs': runs,
            'countdown': '',
        }
        self.group3_schedule_jobs[(id(router), action_key)] = state
        controls['schedule'].config(text='Hẹn giờ')
        controls['time'].config(state='disabled')
        controls['count'].config(state='disabled')
        self._append_router_log(router, f'[SCHEDULE] {action_name} ({app_label}): chạy ngay 1 lần, sau đó mỗi {seconds}s, tổng {runs} lần')
        self._run_background(router, lambda rr: self._run_group3_action(rr, action_key))
        if state['remaining'] <= 0:
            self._append_router_log(router, f'[SCHEDULE] {action_name}: hoàn tất lịch chạy')
            self.group3_schedule_jobs.pop((id(router), action_key), None)
            controls['time'].config(state='normal')
            controls['count'].config(state='normal')
            self._refresh_group3_schedule_tree()
            return
        self._schedule_group3_tick(router, action_key, immediate=False)
        self._refresh_group3_schedule_tree()

    def _schedule_group3_tick(self, router, action_key, immediate=False):
        key = (id(router), action_key)
        state = self.group3_schedule_jobs.get(key)
        if not state:
            return
        if state['remaining'] <= 0:
            self._cancel_group3_schedule(router, action_key, quiet=True)
            return
        state['status'] = 'Đếm ngược'
        state['next_run_at'] = time.time() + state['seconds']
        state['countdown'] = state['interval_text']
        self._update_group3_schedule_countdown(router, action_key)

    def _update_group3_schedule_countdown(self, router, action_key):
        key = (id(router), action_key)
        state = self.group3_schedule_jobs.get(key)
        if not state:
            self._refresh_group3_schedule_tree()
            return
        remaining_secs = max(0, int(round((state.get('next_run_at') or 0) - time.time())))
        state['status'] = 'Đếm ngược'
        mm = remaining_secs // 60
        ss = remaining_secs % 60
        state['countdown'] = f'{mm:02d}:{ss:02d}'
        self._refresh_group3_schedule_tree()
        if remaining_secs <= 0:
            state['status'] = 'Đang chạy'
            state['countdown'] = '00:00'
            self._refresh_group3_schedule_tree()
            self._run_group3_action(router, action_key)
            state['remaining'] -= 1
            if state['remaining'] <= 0:
                self._append_router_log(router, f'[SCHEDULE] {state["label"]}: hoàn tất lịch chạy')
                self.group3_schedule_jobs.pop(key, None)
                controls = (router.get('_ui_group3_controls') or {}).get(action_key)
                if controls:
                    controls['time'].config(state='normal')
                    controls['count'].config(state='normal')
                self._refresh_group3_schedule_tree()
                return
            state['status'] = 'Đếm ngược'
            state['next_run_at'] = time.time() + state['seconds']
            state['countdown'] = state['interval_text']
        state['job'] = self.after(1000, lambda r=router, a=action_key: self._update_group3_schedule_countdown(r, a))

    def _cancel_group3_schedule(self, router, action_key, quiet=False):
        key = (id(router), action_key)
        state = self.group3_schedule_jobs.pop(key, None)
        if state and state.get('job'):
            try:
                self.after_cancel(state['job'])
            except Exception:
                pass
        controls = (router.get('_ui_group3_controls') or {}).get(action_key)
        if controls:
            controls['schedule'].config(text='Hẹn giờ')
            controls['time'].config(state='normal')
            controls['count'].config(state='normal')
        if state and not quiet:
            self._append_router_log(router, f'[SCHEDULE] {state["label"]}: đã hủy lịch')
        self._refresh_group3_schedule_tree()

    def _refresh_group3_schedule_tree(self):
        tree = self.group3_schedule_tree
        if tree is None:
            return
        for item in tree.get_children():
            tree.delete(item)
        for (_router_id, _action_key), state in self.group3_schedule_jobs.items():
            status = state.get('status', '')
            if state.get('countdown'):
                status = f"{status} {state.get('countdown')}".strip()
            tree.insert('', 'end', values=(state.get('label', ''), state.get('app', ''), state.get('interval_text', ''), state.get('remaining', ''), status))

    def _schedule(self, parent):
        card = ttk.Frame(parent, style='Card.TFrame', padding=12)
        card.pack(fill='both', expand=True)
        ttk.Label(card, text='LỊCH CHẠY ĐANG CÓ', style='Title.TLabel').pack(anchor='w', pady=(0, 8))
        columns = ('Tác vụ', 'App', 'Chu kỳ', 'Còn lại', 'Trạng thái')
        tree = ttk.Treeview(card, columns=columns, show='headings', height=8)
        for col in columns:
            tree.heading(col, text=col)
            tree.column(col, width=120, anchor='center')
        tree.pack(fill='both', expand=True)
        self.group3_schedule_tree = tree
        self._refresh_group3_schedule_tree()

    def _devices_tab(self, parent, router):
        top = ttk.Frame(parent, style='Card.TFrame')
        top.pack(fill='x', pady=(0, 10))
        ttk.Button(top, text='Cấu hình IP theo máy', command=self._open_ip_config_dialog).pack(side='left', padx=(0, 8))
        ttk.Button(top, text='Scan lại all máy', command=lambda r=router: self._run_background(r, self._scan_all_router)).pack(side='left', padx=(0, 8))
        ttk.Button(top, text='Full Devices Info', command=lambda r=router: self._open_full_devices_info(r)).pack(side='left', padx=(0, 8))
        ttk.Button(top, text='Refresh', command=lambda r=router: self._refresh_router_devices(r)).pack(side='left', padx=(0, 8))
        ttk.Label(top, text=f"Online: {sum(1 for row in router['rows'] if row.get('network') == 'Online')}", style='Sub.TLabel').pack(side='right', padx=(8, 0))
        ttk.Label(top, text=f"Tổng: {len(router['rows'])}", style='Sub.TLabel').pack(side='right')
        columns = ('machine', 'ip', 'network', 'screen', 'app', 'xxtouch', 'license', 'capacity', 'free', 'updated', 'note')
        headings = {'machine': 'Máy', 'ip': 'IP', 'network': 'Mạng', 'screen': 'Màn hình', 'app': 'App', 'xxtouch': 'XXTouch', 'license': 'Key XXTouch', 'capacity': 'Dung lượng', 'free': 'Dung lượng còn lại', 'updated': 'Cập nhật', 'note': 'Ghi chú'}
        table_wrap = ttk.Frame(parent, style='Card.TFrame')
        table_wrap.pack(fill='both', expand=True)
        tree = ttk.Treeview(table_wrap, columns=columns, show='headings', height=18)
        vsb = ttk.Scrollbar(table_wrap, orient='vertical', command=tree.yview)
        hsb = ttk.Scrollbar(table_wrap, orient='horizontal', command=tree.xview)
        tree.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)
        widths = {'machine': 90, 'ip': 130, 'network': 100, 'screen': 130, 'app': 140, 'xxtouch': 110, 'license': 110, 'capacity': 110, 'free': 150, 'updated': 100, 'note': 180}
        for col in columns:
            tree.heading(col, text=headings[col], command=lambda c=col, r=router: self._sort_devices_tree(r, c, False))
            tree.column(col, width=widths[col], anchor='center')
        tree.grid(row=0, column=0, sticky='nsew')
        vsb.grid(row=0, column=1, sticky='ns')
        hsb.grid(row=1, column=0, sticky='ew')
        table_wrap.rowconfigure(0, weight=1)
        table_wrap.columnconfigure(0, weight=1)
        router['_device_sort_state'] = {}
        self.router_devices_trees[id(router)] = tree
        self._refresh_router_devices(router)

    def _refresh_router_devices(self, router):
        tree = self.router_devices_trees.get(id(router))
        if tree is None:
            return
        for item in tree.get_children():
            tree.delete(item)
        for row in router['rows']:
            tree.insert('', 'end', values=(row.get('machine', ''), row.get('ip', ''), row.get('network', ''), row.get('screen', ''), row.get('app', ''), row.get('xxtouch', ''), row.get('license', ''), row.get('capacity_label', ''), row.get('free_label', ''), row.get('updated', ''), row.get('note', '')))

    def _sort_devices_tree(self, router, column, reverse):
        tree = self.router_devices_trees.get(id(router))
        if tree is None:
            return
        items = [(tree.set(k, column), k) for k in tree.get_children('')]
        items.sort(key=lambda x: str(x[0]).lower(), reverse=reverse)
        for idx, (_val, k) in enumerate(items):
            tree.move(k, '', idx)
        tree.heading(column, command=lambda c=column, r=router, rev=not reverse: self._sort_devices_tree(r, c, rev))

    def _scan_all_router(self, router):
        original_mode = router.get('ui_mode', 'ALL MAY')
        original_group = router.get('ui_group', '')
        original_list = router.get('ui_list', '')
        router['ui_mode'] = 'ALL MAY'
        router['ui_group'] = ''
        router['ui_list'] = ''
        self._scan_router(router)
        router['ui_mode'] = original_mode
        router['ui_group'] = original_group
        router['ui_list'] = original_list

    def _inline_editor(self, parent):
        card = ttk.Frame(parent, style='Card.TFrame', padding=12)
        card.pack(fill='both', expand=True)
        head = ttk.Frame(card, style='Card.TFrame')
        head.pack(fill='x', pady=(0, 8))
        ttk.Label(head, text='INLINE COMMAND EDITOR', style='Title.TLabel').pack(side='left')
        self.inline_router_label = ttk.Label(head, text='Router: ?', style='Sub.TLabel')
        self.inline_router_label.pack(side='left', padx=(12, 0))
        ttk.Button(head, text='Chạy inline', command=lambda: self._run_background(self._current_router(), self._run_inline_for_router)).pack(side='right')
        editor_wrap = tk.Frame(card, bg='#1e1e1e', bd=1, relief='solid')
        editor_wrap.pack(fill='both', expand=True)
        line_numbers = tk.Text(editor_wrap, width=5, padx=6, takefocus=0, border=0, background='#252526', foreground='#858585', state='normal', wrap='none')
        line_numbers.pack(side='left', fill='y')
        x_scroll = tk.Scrollbar(editor_wrap, orient='horizontal')
        y_scroll = tk.Scrollbar(editor_wrap, orient='vertical')
        code = tk.Text(editor_wrap, wrap='none', undo=True, bg='#1e1e1e', fg='#d4d4d4', insertbackground='#ffffff', selectbackground='#264f78', font=('Consolas', 11), xscrollcommand=x_scroll.set, yscrollcommand=y_scroll.set, relief='flat')
        y_scroll.config(command=code.yview)
        x_scroll.config(command=code.xview)
        y_scroll.pack(side='right', fill='y')
        x_scroll.pack(side='bottom', fill='x')
        code.pack(side='left', fill='both', expand=True)
        sample = self._current_router().get('inline_script', 'device = require("device")\nsys = require("sys")\n\nwhile (device.is_screen_locked()) do\n    device.unlock_screen()\n    sys.msleep(1000)\nend\n\nsys.toast("Screen unlocked, script starting")\n')
        if self.inline_router_label:
            try:
                self.inline_router_label.config(text=f'Router: {self._current_router().get("name", "?")}')
            except Exception:
                pass
        code.insert('1.0', sample)
        self.inline_editor = code
        for tag, color in {'keyword': '#c586c0', 'module': '#4ec9b0', 'string': '#ce9178', 'number': '#b5cea8'}.items():
            code.tag_configure(tag, foreground=color)

        def colorize(*_args):
            content = code.get('1.0', 'end-1c')
            for tag in ['keyword', 'module', 'string', 'number']:
                code.tag_remove(tag, '1.0', 'end')
            for word in ['while', 'do', 'end', 'require', 'for', 'in', 'local']:
                start = '1.0'
                while True:
                    idx = code.search(word, start, stopindex='end')
                    if not idx:
                        break
                    end_idx = f"{idx}+{len(word)}c"
                    code.tag_add('keyword', idx, end_idx)
                    start = end_idx
            for word in ['device', 'sys', 'app', 'key']:
                start = '1.0'
                while True:
                    idx = code.search(word, start, stopindex='end')
                    if not idx:
                        break
                    end_idx = f"{idx}+{len(word)}c"
                    code.tag_add('module', idx, end_idx)
                    start = end_idx
            start = '1.0'
            while True:
                idx = code.search('"', start, stopindex='end')
                if not idx:
                    break
                end_idx = code.search('"', f'{idx}+1c', stopindex='end')
                if not end_idx:
                    break
                code.tag_add('string', idx, f'{end_idx}+1c')
                start = f'{end_idx}+1c'
            for token in ['1000', '48', '0x0C']:
                start = '1.0'
                while True:
                    idx = code.search(token, start, stopindex='end')
                    if not idx:
                        break
                    end_idx = f"{idx}+{len(token)}c"
                    code.tag_add('number', idx, end_idx)
                    start = end_idx
            lines = content.split('\n')
            line_numbers.config(state='normal')
            line_numbers.delete('1.0', 'end')
            line_numbers.insert('1.0', '\n'.join(str(i) for i in range(1, len(lines) + 1)))
            line_numbers.config(state='disabled')

        colorize()

        def persist_and_colorize(_event=None):
            try:
                router = self._current_router()
                router['inline_script'] = code.get('1.0', 'end-1c')
                save_router_config(self.routers)
            except Exception:
                pass
            colorize()

        code.bind('<KeyRelease>', persist_and_colorize)

    def _logs_tab(self, parent, router):
        card = ttk.Frame(parent, style='Card.TFrame', padding=12)
        card.pack(fill='both', expand=True)
        ttk.Label(card, text='RUN LOG', style='Title.TLabel').pack(anchor='w', pady=(0, 8))
        wrap = ttk.Frame(card, style='Card.TFrame')
        wrap.pack(fill='both', expand=True)
        text = tk.Text(wrap, height=26, bg='#0f172a', fg='#e2e8f0', insertbackground='#e2e8f0', relief='solid', borderwidth=1, wrap='none')
        vsb = ttk.Scrollbar(wrap, orient='vertical', command=text.yview)
        hsb = ttk.Scrollbar(wrap, orient='horizontal', command=text.xview)
        text.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)
        text.grid(row=0, column=0, sticky='nsew')
        vsb.grid(row=0, column=1, sticky='ns')
        hsb.grid(row=1, column=0, sticky='ew')
        wrap.rowconfigure(0, weight=1)
        wrap.columnconfigure(0, weight=1)
        self.router_logs_widgets[id(router)] = text
        self._refresh_router_logs(router)

    def _refresh_router_logs(self, router):
        widget = self.router_logs_widgets.get(id(router))
        if widget is None:
            return
        widget.config(state='normal')
        widget.delete('1.0', 'end')
        for line in reversed(router.get('logs', [])):
            widget.insert('end', line + '\n')
        widget.see('1.0')
        widget.config(state='disabled')

    def _append_router_log(self, router, line):
        router.setdefault('logs', []).append(f'[{now_text()}] {line}')
        router['logs'] = router['logs'][-300:]
        save_router_config(self.routers)
        self._refresh_router_logs(router)

    def _run_background(self, router, fn):
        def worker():
            try:
                fn(router)
            except Exception as e:
                self.after(0, lambda: self._append_router_log(router, f'Lỗi nền: {e}'))
        threading.Thread(target=worker, daemon=True).start()

    def _on_router_tab_changed(self, _event=None):
        self._update_header_status()
        if self.inline_router_label:
            try:
                router = self._current_router()
                self.inline_router_label.config(text=f'Router: {router.get("name", "?")}')
                if self.inline_editor is not None:
                    self.inline_editor.delete('1.0', 'end')
                    self.inline_editor.insert('1.0', router.get('inline_script', ''))
            except Exception:
                self.inline_router_label.config(text='Router: ?')

    def _restore_runtime_prefs(self):
        changed = False
        for router in self.routers:
            before = json.dumps({k: v for k, v in router.items() if not str(k).startswith('_')}, ensure_ascii=False, sort_keys=True)
            ensure_router_defaults(router)
            after = json.dumps({k: v for k, v in router.items() if not str(k).startswith('_')}, ensure_ascii=False, sort_keys=True)
            if before != after:
                changed = True
        if changed:
            save_router_config(self.routers)

    def _refresh_selected_files(self, router):
        box = self.router_file_widgets.get(id(router))
        if box is None:
            return
        file_row = router.get('_ui_file_row')
        file_label = router.get('_ui_file_label')
        view_btn = router.get('_ui_file_view_btn')
        for child in box.winfo_children():
            child.destroy()
        names = [item.get('name', '') for item in router.get('selected_files', [])]
        if not names:
            if file_label is not None:
                try:
                    file_label.pack_forget()
                except Exception:
                    pass
            if view_btn is not None:
                try:
                    view_btn.pack_forget()
                except Exception:
                    pass
            try:
                box.pack_forget()
            except Exception:
                pass
            if file_row is not None:
                try:
                    file_row.pack_forget()
                except Exception:
                    pass
            return
        if file_row is not None and not file_row.winfo_ismapped():
            file_row.pack(fill='x')
        if file_label is not None and not file_label.winfo_ismapped():
            file_label.pack(side='left', padx=(0, 8))
        if view_btn is not None and not view_btn.winfo_ismapped():
            view_btn.pack(side='left', padx=(0, 8))
        if not box.winfo_ismapped():
            box.pack(side='left', fill='x', expand=True)
        preview = ', '.join(names[:3])
        if len(names) > 3:
            preview += f' ... (+{len(names)-3})'
        tk.Label(box, text=preview, bg='#ffffff', anchor='w').pack(side='left', fill='x', expand=True)

    def _remove_selected_file(self, router, path):
        router['selected_files'] = [x for x in router.get('selected_files', []) if x.get('path') != path]
        save_router_config(self.routers)
        self._refresh_selected_files(router)
        self._append_router_log(router, 'Đã hủy 1 file đã chọn')

    def _clear_selected_files(self, router):
        router['selected_files'] = []
        save_router_config(self.routers)
        self._refresh_selected_files(router)
        self._append_router_log(router, 'Đã hủy toàn bộ file đã chọn')

    def _open_selected_files_popup(self, router):
        win = tk.Toplevel(self)
        win.title('Danh sách file đã chọn')
        win.geometry('680x420')
        win.configure(bg='#eef2f7')

        wrap = ttk.Frame(win, style='Card.TFrame', padding=12)
        wrap.pack(fill='both', expand=True, padx=12, pady=12)
        ttk.Label(wrap, text='File đã chọn để SEND FILE', style='Title.TLabel').pack(anchor='w')
        ttk.Label(wrap, text='Có thể hủy từng file hoặc hủy tất cả', style='Sub.TLabel').pack(anchor='w', pady=(0, 10))

        list_wrap = tk.Frame(wrap, bg='#ffffff')
        list_wrap.pack(fill='both', expand=True)
        canvas = tk.Canvas(list_wrap, bg='#ffffff', highlightthickness=0)
        scrollbar = ttk.Scrollbar(list_wrap, orient='vertical', command=canvas.yview)
        inner = tk.Frame(canvas, bg='#ffffff')
        inner.bind('<Configure>', lambda e: canvas.configure(scrollregion=canvas.bbox('all')))
        canvas.create_window((0, 0), window=inner, anchor='nw')
        canvas.configure(yscrollcommand=scrollbar.set)
        canvas.pack(side='left', fill='both', expand=True)
        scrollbar.pack(side='right', fill='y')

        def render_items():
            for child in inner.winfo_children():
                child.destroy()
            for item in router.get('selected_files', []):
                row = tk.Frame(inner, bg='#ffffff')
                row.pack(fill='x', pady=2)
                tk.Label(row, text=item.get('name', ''), bg='#ffffff', anchor='w').pack(side='left', fill='x', expand=True)
                tk.Button(row, text='X', width=3, command=lambda p=item.get('path'): [self._remove_selected_file(router, p), render_items()]).pack(side='right')

        render_items()

        foot = ttk.Frame(wrap, style='Card.TFrame')
        foot.pack(fill='x', pady=(10, 0))
        ttk.Button(foot, text='Hủy tất cả', command=lambda: [self._clear_selected_files(router), render_items()]).pack(side='left')
        ttk.Button(foot, text='Đóng', command=win.destroy).pack(side='right')

    def _choose_files_for_router(self, router):
        paths = filedialog.askopenfilenames(title='Chọn file gửi tới XXTouch')
        if not paths:
            return
        items = router.setdefault('selected_files', [])
        existing = {x.get('path') for x in items}
        added = 0
        for path in paths:
            if path in existing:
                continue
            p = Path(path)
            items.append({'name': p.name, 'path': str(p)})
            added += 1
        save_router_config(self.routers)
        self._refresh_selected_files(router)
        self._append_router_log(router, f'Đã chọn {added} file mới')

    def _sync_examples_from_repo_for_router(self, router):
        examples_dir = Path(__file__).resolve().parent.parent / 'examples'
        if not examples_dir.exists() or not examples_dir.is_dir():
            self._append_router_log(router, f'SYNC EXAMPLES: không thấy thư mục {examples_dir}')
            return
        files = [p for p in examples_dir.iterdir() if p.is_file()]
        if not files:
            self._append_router_log(router, 'SYNC EXAMPLES: thư mục examples không có file nào')
            return
        router['selected_files'] = [{'name': p.name, 'path': str(p)} for p in files]
        router['send_dest'] = 'examples'
        save_router_config(self.routers)
        self._refresh_selected_files(router)
        self._append_router_log(router, f'SYNC EXAMPLES: đã nạp {len(files)} file từ repo/examples, chuẩn bị gửi xuống lua/examples')
        self._send_files_for_router(router, 'examples')

    def _open_send_file_dest_popup(self, router):
        files = list(router.get('selected_files', []))
        if not files:
            self._append_router_log(router, 'Chưa chọn file nào')
            return
        rows = list(self._selected_rows(router))
        if not rows:
            self._append_router_log(router, 'Không có máy đích nào được chọn')
            return

        win = tk.Toplevel(self)
        win.title('Chọn thư mục đích SEND FILE')
        win.geometry('420x210')
        win.resizable(False, False)
        win.configure(bg='#111827')
        try:
            win.transient(self)
            win.grab_set()
        except Exception:
            pass

        body = ttk.Frame(win, style='Card.TFrame', padding=16)
        body.pack(fill='both', expand=True)
        ttk.Label(body, text='Gửi file đến đâu?', style='Title.TLabel').pack(anchor='w', pady=(0, 8))
        ttk.Label(body, text='Chọn thư mục đích rồi bấm OK', style='Sub.TLabel').pack(anchor='w', pady=(0, 12))

        options = [
            ('examples', 'lua/examples'),
            ('scripts', 'lua/scripts'),
            ('lib', '/1ferver/lib'),
            ('ipa', '/1ferver/ipa'),
            ('archives', '/1ferver/archives'),
        ]
        option_map = {value: label for value, label in options}
        reverse_option_map = {label: value for value, label in options}
        current_key = str(router.get('send_dest', 'examples') or 'examples')
        current_label = option_map.get(current_key, 'lua/examples')

        pick_row = ttk.Frame(body, style='Card.TFrame')
        pick_row.pack(fill='x', pady=(0, 6))
        ttk.Label(pick_row, text='Thư mục đích', style='Sub.TLabel').pack(anchor='w', pady=(0, 6))
        dest_combo = ttk.Combobox(pick_row, values=[label for _, label in options], state='readonly', width=36)
        dest_combo.set(current_label)
        dest_combo.pack(fill='x')

        actions = ttk.Frame(body, style='Card.TFrame')
        actions.pack(fill='x', pady=(16, 0))

        def do_ok():
            selected_label = dest_combo.get().strip() or 'lua/examples'
            dest_key = reverse_option_map.get(selected_label, 'examples')
            router['send_dest'] = dest_key
            save_router_config(self.routers)
            win.destroy()
            self._send_files_for_router(router, dest_key)

        ttk.Button(actions, text='OK', command=do_ok).pack(side='right')
        ttk.Button(actions, text='Hủy', command=win.destroy).pack(side='right', padx=(0, 8))

    def _send_files_for_router(self, router, dest_key=None):
        files = list(router.get('selected_files', []))
        if not files:
            self._append_router_log(router, 'Chưa chọn file nào')
            return
        rows = list(self._selected_rows(router))
        if not rows:
            self._append_router_log(router, 'Không có máy đích nào được chọn')
            return
        dest_value = str(dest_key or router.get('send_dest', 'examples')).strip().lower()
        dest_map = {
            'examples': 'lua/examples',
            'scripts': 'lua/scripts',
            'lib': '/var/mobile/Media/1ferver/lib',
            'ipa': '/var/mobile/Media/1ferver/ipa',
            'archives': '/var/mobile/Media/1ferver/archives',
        }
        target_dir = dest_map.get(dest_value, 'lua/examples')
        file_payloads = []
        for item in files:
            p = Path(item['path'])
            file_payloads.append((p.name, p.read_bytes()))
        self._append_router_log(router, f'SEND FILE bắt đầu nền, đích {target_dir}, {len(files)} file, {len(rows)} máy')

        def task(row):
            ip = str(row.get('ip') or '').strip()
            if not ip:
                raise XXTouchOpenAPIError('Thiếu IP')
            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=8)
            for filename, data in file_payloads:
                client.write_file(f'{target_dir}/{filename}', data)
            row['network'] = 'Online'
            row['xxtouch'] = 'Connected'
            row['updated'] = now_text()
            return row

        self._run_parallel_rows(router, rows, task, 'SEND FILE', per_success=lambda row: f'[{row.get("machine", "?")}] SEND FILE OK ({len(files)} file -> {target_dir})')
        router['selected_files'] = []
        save_router_config(self.routers)
        self._refresh_selected_files(router)

    def _save_router_machine_ui(self, router):
        list_widget = router.get('_ui_list_widget')
        router['ui_mode'] = 'LIST MAY'
        value = list_widget.get().strip() if list_widget else str(router.get('ui_list', router.get('ui_group', ''))).strip()
        if not value:
            value = 'all'
        router['ui_group'] = value
        router['ui_list'] = value
        save_router_config(self.routers)

    def _selected_rows(self, router):
        rows = router.get('rows', [])
        list_widget = router.get('_ui_list_widget')
        target = list_widget.get().strip() if list_widget else str(router.get('ui_list', router.get('ui_group', ''))).strip()
        self._save_router_machine_ui(router)
        if not target or target.lower() == 'all':
            return rows
        wanted = set()
        for part in target.replace(';', ',').split(','):
            raw = part.strip()
            if not raw:
                continue
            if '-' in raw:
                a, b = raw.split('-', 1)
                try:
                    start = int(a.strip())
                    end = int(b.strip())
                    for num in range(start, end + 1):
                        wanted.add(str(num))
                except Exception:
                    continue
            else:
                wanted.add(raw)
        return [row for row in rows if str(row.get('machine', '')).strip() in wanted]

    def _scan_router(self, router):
        rows = self._selected_rows(router)
        if not rows:
            self._append_router_log(router, 'SCAN: không có máy nào được chọn')
            return

        def task(row):
            ip = str(row.get('ip') or '').strip()
            if not ip:
                row['network'] = 'Offline'
                row['screen'] = 'Unknown'
                row['app'] = row.get('app') or '-'
                row['xxtouch'] = 'Unknown'
                row['updated'] = now_text()
                raise XXTouchOpenAPIError('Thiếu IP')
            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=4)
            try:
                info_resp = client.deviceinfo()
                info = info_resp.get('data', info_resp) if isinstance(info_resp, dict) else {}
            except Exception:
                info = {}
            row['network'] = 'Online'
            row['screen'] = str(info.get('screen', info.get('display', row.get('screen', 'Unknown'))) or 'Unknown')
            row['app'] = str(info.get('frontmost_app', info.get('bundleid', row.get('app', '-'))) or '-')
            row['xxtouch'] = 'Ready'
            row['license'] = 'Không rõ'
            row['updated'] = now_text()
            row['raw_deviceinfo'] = info
            try:
                storage_data = client.get_storage_info()
                if isinstance(storage_data, dict):
                    row['raw_storageinfo'] = storage_data
            except Exception as e:
                row['raw_storageinfo_error'] = str(e)
            capacity_candidates = [
                info.get('capacity_label'),
                info.get('total_capacity'),
                info.get('disk_capacity'),
                info.get('storage_total'),
                info.get('total_disk_space'),
                info.get('disk_total'),
            ]
            free_candidates = [
                info.get('free_label'),
                info.get('free_capacity'),
                info.get('disk_free'),
                info.get('storage_free'),
                info.get('free_disk_space'),
                info.get('available_disk_space'),
            ]
            storage_data = row.get('raw_storageinfo') or {}
            if isinstance(storage_data, dict):
                total_kb = storage_data.get('total_kb')
                free_kb = storage_data.get('free_kb')
                if total_kb not in (None, ''):
                    total_gib = float(total_kb) / 1024.0 / 1024.0
                    if total_gib <= 15:
                        capacity_candidates.append('16GB')
                    elif total_gib <= 31:
                        capacity_candidates.append('32GB')
                    elif total_gib <= 63:
                        capacity_candidates.append('64GB')
                    elif total_gib <= 127:
                        capacity_candidates.append('128GB')
                    else:
                        capacity_candidates.append(f'{total_gib:.1f}GB')
                if free_kb not in (None, ''):
                    free_gib = float(free_kb) / 1024.0 / 1024.0
                    free_candidates.append(f'{free_gib:.1f}GB')
            try:
                auth_resp = client._post_json('/device_auth_info', {})
                auth_data = auth_resp.get('data', auth_resp) if isinstance(auth_resp, dict) else {}
                expire_date = auth_data.get('expireDate')
                now_date = auth_data.get('nowDate')
                if expire_date is not None and now_date is not None:
                    row['license'] = 'Đã active' if float(expire_date) > float(now_date) else 'Hết hạn'
                elif auth_data:
                    row['license'] = 'Đã active'
            except Exception:
                row['license'] = 'Không rõ'
            capacity = next((str(x) for x in capacity_candidates if x not in (None, '')), '')
            free = next((str(x) for x in free_candidates if x not in (None, '')), '')
            row['capacity_label'] = capacity
            row['free_label'] = free
            note_bits = []
            if info.get('marketing_name'):
                note_bits.append(str(info.get('marketing_name')))
            if info.get('devsn'):
                note_bits.append(f"SN:{info.get('devsn')}")
            row['note'] = ' | '.join(note_bits)
            return row

        self._run_parallel_rows(router, rows, task, 'SCAN', per_success=lambda row: f'[{row.get("machine", "?")}] SCAN OK')

    def _simple_router_action(self, router, action, log_text):
        rows = self._selected_rows(router)
        if not rows:
            self._append_router_log(router, f'{action}: không có máy nào được chọn')
            return

        def task(row):
            ip = str(row.get('ip') or '').strip()
            if not ip:
                raise XXTouchOpenAPIError('Thiếu IP')
            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=5)
            if action == 'reboot2':
                client.reboot2()
            row['updated'] = now_text()
            row['network'] = 'Online'
            row['xxtouch'] = 'Connected'
            return row

        self._run_parallel_rows(router, rows, task, action, per_success=lambda row: f'[{row.get("machine", "?")}] {log_text}')

    def _open_full_devices_info(self, router):
        win = tk.Toplevel(self)
        win.title(f'Full Devices Info - {router.get("name", "")}')
        win.geometry('980x720')
        win.configure(bg='#0f172a')

        wrap = ttk.Frame(win, style='Card.TFrame', padding=12)
        wrap.pack(fill='both', expand=True, padx=12, pady=12)
        ttk.Label(wrap, text='Full Devices Info', style='Title.TLabel').pack(anchor='w')
        ttk.Label(wrap, text='Toàn bộ dữ liệu deviceinfo() đã scan được của từng máy', style='Sub.TLabel').pack(anchor='w', pady=(0, 10))

        text_wrap = ttk.Frame(wrap, style='Card.TFrame')
        text_wrap.pack(fill='both', expand=True)
        text = tk.Text(text_wrap, bg='#0f172a', fg='#e5e7eb', insertbackground='#e5e7eb', relief='solid', borderwidth=1, wrap='none', font=('Consolas', 10))
        vsb = ttk.Scrollbar(text_wrap, orient='vertical', command=text.yview)
        hsb = ttk.Scrollbar(text_wrap, orient='horizontal', command=text.xview)
        text.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)
        text.grid(row=0, column=0, sticky='nsew')
        vsb.grid(row=0, column=1, sticky='ns')
        hsb.grid(row=1, column=0, sticky='ew')
        text_wrap.rowconfigure(0, weight=1)
        text_wrap.columnconfigure(0, weight=1)

        blocks = []
        for row in router.get('rows', []):
            info = row.get('raw_deviceinfo') or {}
            blocks.append(
                f"=== Máy {row.get('machine', '')} | IP {row.get('ip', '')} ===\n" +
                json.dumps(info, ensure_ascii=False, indent=2, sort_keys=True)
            )
        text.insert('1.0', '\n\n'.join(blocks) if blocks else 'Chưa có dữ liệu deviceinfo. Hãy Scan lại all máy trước.')
        text.config(state='disabled')

        foot = ttk.Frame(wrap, style='Card.TFrame')
        foot.pack(fill='x', pady=(10, 0))
        ttk.Button(foot, text='Đóng', command=win.destroy).pack(side='right')

    def _open_ip_config_dialog(self):
        win = tk.Toplevel(self)
        win.title('Cấu hình IP theo máy')
        win.geometry('760x520')
        win.configure(bg='#eef2f7')
        wrap = ttk.Frame(win, style='Card.TFrame', padding=12)
        wrap.pack(fill='both', expand=True, padx=12, pady=12)
        ttk.Label(wrap, text='Cấu hình router | Máy|IP', style='Title.TLabel').pack(anchor='w')
        ttk.Label(wrap, text='Thêm, xóa, đổi tên router và lưu danh sách máy|ip thật', style='Sub.TLabel').pack(anchor='w', pady=(0, 10))
        layout = ttk.Frame(wrap, style='Card.TFrame')
        layout.pack(fill='both', expand=True, pady=(0, 10))
        layout.columnconfigure(0, weight=0)
        layout.columnconfigure(1, weight=1)
        layout.rowconfigure(0, weight=1)
        router_list = tk.Listbox(layout, width=24, font=('Arial', 10))
        router_list.grid(row=0, column=0, sticky='nsw', padx=(0, 10))
        for router in self.routers:
            router_list.insert('end', router['name'])
        if self.routers:
            router_list.selection_set(0)
        right = ttk.Frame(layout, style='Card.TFrame')
        right.grid(row=0, column=1, sticky='nsew')
        ttk.Label(right, text='Danh sách Tên máy | IP', style='Sub.TLabel').pack(anchor='w', pady=(0, 6))
        mapping = tk.Text(right, height=16, relief='solid', borderwidth=1, font=('Consolas', 11))
        mapping.pack(fill='both', expand=True)

        def fill_mapping(index=0):
            mapping.delete('1.0', 'end')
            if not self.routers:
                return
            router = self.routers[index]
            lines = [f"{row.get('machine', '')}|{row.get('ip', '')}" for row in router.get('rows', [])]
            mapping.insert('1.0', '\n'.join(lines) + ('\n' if lines else ''))

        def on_select(_event=None):
            sel = router_list.curselection()
            if not sel:
                return
            idx = sel[0]
            router_name_entry.delete(0, 'end')
            router_name_entry.insert(0, self.routers[idx]['name'])
            fill_mapping(idx)

        router_list.bind('<<ListboxSelect>>', on_select)
        if self.routers:
            fill_mapping(0)

        form = ttk.Frame(wrap, style='Card.TFrame')
        form.pack(fill='x', pady=(0, 10))
        router_name_entry = ttk.Entry(form, width=26)
        router_name_entry.pack(side='left', padx=(0, 8))
        if self.routers:
            router_name_entry.insert(0, self.routers[0]['name'])

        def add_router():
            name = router_name_entry.get().strip() or f'Router {len(self.routers) + 1}'
            self.routers.append({'name': name, 'rows': [], 'logs': [], 'selected_files': []})
            router_list.insert('end', name)
            router_list.selection_clear(0, 'end')
            router_list.selection_set('end')
            fill_mapping(len(self.routers) - 1)

        def remove_router():
            sel = router_list.curselection()
            if not sel:
                return
            idx = sel[0]
            router_list.delete(idx)
            self.routers.pop(idx)
            mapping.delete('1.0', 'end')
            router_name_entry.delete(0, 'end')
            if self.routers:
                router_list.selection_set(0)
                router_name_entry.insert(0, self.routers[0]['name'])
                fill_mapping(0)

        def rename_router():
            sel = router_list.curselection()
            if not sel:
                return
            idx = sel[0]
            name = router_name_entry.get().strip()
            if not name:
                return
            self.routers[idx]['name'] = name
            router_list.delete(idx)
            router_list.insert(idx, name)
            router_list.selection_set(idx)

        def save_mapping():
            sel = router_list.curselection()
            if not sel:
                return
            idx = sel[0]
            rows = []
            for line in mapping.get('1.0', 'end').splitlines():
                raw = line.strip()
                if not raw:
                    continue
                if '|' in raw:
                    machine, ip = raw.split('|', 1)
                else:
                    parts = raw.split()
                    if len(parts) < 2:
                        continue
                    machine, ip = parts[0], parts[1]
                rows.append({'stt': str(len(rows) + 1), 'machine': machine.strip(), 'ip': ip.strip(), 'udid': '', 'network': 'Unknown', 'screen': 'Unknown', 'app': '-', 'xxtouch': 'Unknown', 'updated': '-', 'note': ''})
            self.routers[idx]['rows'] = rows
            save_router_config(self.routers)
            self._build_router_tabs()
            messagebox.showinfo('Lưu cấu hình', 'Đã lưu danh sách Máy|IP cho router')

        def save_all():
            save_router_config(self.routers)
            self._build_router_tabs()
            messagebox.showinfo('Lưu cấu hình', 'Đã lưu toàn bộ cấu hình router')
            win.destroy()

        ttk.Button(form, text='Thêm router', command=add_router).pack(side='left', padx=(0, 8))
        ttk.Button(form, text='Xóa router', command=remove_router).pack(side='left', padx=(0, 8))
        ttk.Button(form, text='Đổi tên router', command=rename_router).pack(side='left', padx=(0, 8))
        ttk.Button(form, text='Lưu danh sách Máy|IP', command=save_mapping).pack(side='left', padx=(0, 8))
        ttk.Button(form, text='Lưu', command=save_all).pack(side='right')
        ttk.Label(wrap, text='Nhập theo dạng: máy|ip hoặc máy ip', style='Sub.TLabel').pack(anchor='w')

    def _router_machine_range_text(self, router):
        rows = router.get('rows', []) or []
        machines = [str(row.get('machine', '')).strip() for row in rows if str(row.get('machine', '')).strip()]
        if not machines:
            return 'chưa có máy'
        if len(machines) == 1:
            return machines[0]
        return f'{machines[0]}-{machines[-1]}'

    def _update_header_status(self):
        if not getattr(self, 'header_status_label', None):
            return
        if not self.routers or not self.router_tabs:
            self.header_status_label.config(text='Router chưa có dữ liệu máy')
            return
        try:
            router = self._current_router()
        except Exception:
            router = self.routers[0] if self.routers else None
        if not router:
            self.header_status_label.config(text='Router chưa có dữ liệu máy')
            return
        self.header_status_label.config(text=f'Router {router.get("name", "")} - Đang có số máy từ {self._router_machine_range_text(router)}')

    def _current_router(self):
        idx = self.router_tabs.index(self.router_tabs.select())
        return self.routers[idx]

    def _open_more_popup(self, router):
        win = tk.Toplevel(self)
        win.title(f'More - {router.get("name", "")}')
        win.geometry('360x280')
        win.resizable(False, False)
        win.configure(bg='#111827')
        try:
            win.transient(self)
            win.grab_set()
        except Exception:
            pass

        body = ttk.Frame(win, style='Card.TFrame', padding=16)
        body.pack(fill='both', expand=True)
        ttk.Label(body, text='Chức năng mở rộng', style='Title.TLabel').pack(anchor='w', pady=(0, 8))
        ttk.Label(body, text='Các nút phụ được gom vào đây để giao diện chính gọn hơn', style='Sub.TLabel').pack(anchor='w', pady=(0, 14))
        ttk.Button(body, text='SCAN', command=lambda: (win.destroy(), self._run_background(router, self._scan_router))).pack(anchor='w', pady=2)
        ttk.Button(body, text='REBOOT', command=lambda: (win.destroy(), self._run_background(router, lambda rr: self._simple_router_action(rr, 'reboot2', 'Đã gửi lệnh reboot')))).pack(anchor='w', pady=2)
        ttk.Button(body, text='TXT', command=lambda: (win.destroy(), self._open_txt_lines_popup(router))).pack(anchor='w', pady=2)
        ttk.Button(body, text='Select Script', command=lambda: (win.destroy(), self._open_select_script_popup(router))).pack(anchor='w', pady=2)
        ttk.Button(body, text='Đóng', command=win.destroy).pack(side='right', pady=(18, 0))

    def _open_select_script_popup(self, router):
        rows = list(self._selected_rows(router))
        if not rows:
            self._append_router_log(router, 'SELECT SCRIPT: không có máy nào được chọn')
            return

        win = tk.Toplevel(self)
        win.title(f'Select Script - {router.get("name", "")}')
        win.geometry('620x230')
        win.resizable(False, False)
        win.configure(bg='#111827')
        try:
            win.transient(self)
            win.grab_set()
        except Exception:
            pass

        body = ttk.Frame(win, style='Card.TFrame', padding=16)
        body.pack(fill='both', expand=True)
        ttk.Label(body, text='Chọn script cho máy đã chọn', style='Title.TLabel').pack(anchor='w', pady=(0, 8))
        ttk.Label(body, text='File này sẽ được set thành selected script, rồi tự đặt click_volume_up/down = 1', style='Sub.TLabel').pack(anchor='w', pady=(0, 14))

        file_row = ttk.Frame(body, style='Card.TFrame')
        file_row.pack(fill='x', pady=(0, 12))
        ttk.Label(file_row, text='File lua', style='Sub.TLabel').pack(side='left', padx=(0, 8))
        file_var = tk.StringVar()
        ttk.Entry(file_row, textvariable=file_var, width=56).pack(side='left', fill='x', expand=True)

        def choose_file():
            path = filedialog.askopenfilename(title='Chọn file lua để select', filetypes=[('Lua files', '*.lua'), ('All files', '*.*')])
            if path:
                file_var.set(path)
                if not script_name_var.get().strip():
                    script_name_var.set(Path(path).name)

        ttk.Button(file_row, text='Chọn file', command=choose_file).pack(side='left', padx=(8, 0))

        name_row = ttk.Frame(body, style='Card.TFrame')
        name_row.pack(fill='x', pady=(0, 8))
        ttk.Label(name_row, text='Tên script trên client', style='Sub.TLabel').pack(side='left', padx=(0, 8))
        script_name_var = tk.StringVar()
        ttk.Entry(name_row, textvariable=script_name_var, width=32).pack(side='left')

        ttk.Label(body, text=f'Áp dụng theo bộ máy đang chọn: {len(rows)} máy', style='Sub.TLabel').pack(anchor='w', pady=(4, 0))

        def do_apply():
            file_path = file_var.get().strip()
            script_name = script_name_var.get().strip()
            if not file_path:
                messagebox.showwarning('Thiếu file', 'Hãy chọn file lua')
                return
            if not script_name:
                messagebox.showwarning('Thiếu tên script', 'Hãy nhập tên script trên client')
                return
            try:
                script_bytes = Path(file_path).read_bytes()
            except Exception as e:
                messagebox.showerror('Không đọc được file', str(e))
                return
            win.destroy()
            self._run_set_selected_script_for_router(router, script_name, script_bytes)

        actions = ttk.Frame(body, style='Card.TFrame')
        actions.pack(fill='x', pady=(18, 0))
        ttk.Button(actions, text='Set Select Script', command=do_apply).pack(side='right')
        ttk.Button(actions, text='Hủy', command=win.destroy).pack(side='right', padx=(0, 8))

    def _open_remote_panel(self, router):
        machines = router.get('rows', [])
        if not machines:
            self._append_router_log(router, 'REMOTE: router chưa có máy nào')
            return
        if self.remote_panel is None or not self.remote_panel.winfo_exists():
            self.remote_panel = tk.Toplevel(self)
            self.remote_panel.title('XXTouch Remote')
            self.remote_panel.geometry('980x760+920+110')
            self.remote_panel.configure(bg='#0f172a')

            wrap = tk.Frame(self.remote_panel, bg='#0f172a')
            wrap.pack(fill='both', expand=True)

            left_wrap = tk.Frame(wrap, bg='#0f172a')
            left_wrap.pack(side='left', fill='both', expand=True, padx=(18, 12), pady=18)
            right_wrap = tk.Frame(wrap, bg='#0f172a')
            right_wrap.pack(side='right', fill='y', padx=(12, 18), pady=18)

            head = tk.Frame(left_wrap, bg='#0f172a')
            head.pack(fill='x', pady=(0, 10))
            self.remote_header_label = tk.Label(head, text='MÁY ?', bg='#111827', fg='white', font=('Arial', 18, 'bold'), padx=28, pady=10)
            self.remote_header_label.pack()
            tk.Button(head, text='✕', command=self._close_remote_panel, bg='#1f2937', fg='white', relief='flat', width=3).place(relx=1.0, x=-6, y=2, anchor='ne')

            self.remote_status_label = tk.Label(left_wrap, text='Đang xem remote', bg='#0f172a', fg='#cbd5e1', font=('Arial', 10, 'bold'))
            self.remote_status_label.pack(anchor='n', pady=(0, 10))

            preview_outer = tk.Frame(left_wrap, bg='#0f172a')
            preview_outer.pack(fill='both', expand=True)
            preview_head = tk.Frame(preview_outer, bg='#0f172a')
            preview_head.pack(fill='x', pady=(0, 10))
            tk.Label(preview_head, text='REMOTE ĐANG MỞ', bg='#0f172a', fg='white', font=('Arial', 15, 'bold')).pack(side='left')
            self.remote_zoom_var = tk.DoubleVar(value=0.82)
            tk.Scale(preview_head, from_=0.45, to=1.0, resolution=0.05, orient='horizontal', variable=self.remote_zoom_var, label='Zoom', length=180, bg='#0f172a', fg='white', highlightthickness=0, troughcolor='#1f2937', command=lambda _v: self._refresh_remote_zoom()).pack(side='right')
            preview_wrap = tk.Frame(preview_outer, bg='#111827', bd=0, highlightthickness=0)
            preview_wrap.pack(fill='both', expand=True)
            self.remote_preview_wrap = preview_wrap
            self.remote_preview_label = tk.Label(preview_wrap, text='REMOTE ĐANG MỞ', bg='#000000', fg='white', font=('Arial', 18, 'bold'))
            self.remote_preview_label.place(relx=0.5, rely=0.5, anchor='center', width=300, height=600)

            chooser_shell = tk.Frame(right_wrap, bg='#111111', bd=0)
            chooser_shell.pack(fill='y', expand=False)
            tk.Label(chooser_shell, text='CHỌN MÁY', bg='#111111', fg='white', font=('Arial', 15, 'bold')).pack(anchor='center', pady=(16, 10))

            list_outer = tk.Frame(chooser_shell, bg='#111111')
            list_outer.pack(fill='both', expand=True, padx=10)
            canvas = tk.Canvas(list_outer, bg='#111111', highlightthickness=0, width=190, height=560)
            scrollbar = ttk.Scrollbar(list_outer, orient='vertical', command=canvas.yview)
            self.remote_machine_list_frame = tk.Frame(canvas, bg='#111111')
            self.remote_machine_list_frame.bind('<Configure>', lambda e: canvas.configure(scrollregion=canvas.bbox('all')))
            canvas.create_window((0, 0), window=self.remote_machine_list_frame, anchor='nw')
            canvas.configure(yscrollcommand=scrollbar.set)
            canvas.pack(side='left', fill='both', expand=True)
            scrollbar.pack(side='right', fill='y')

            nav = tk.Frame(chooser_shell, bg='#111111')
            nav.pack(fill='x', pady=(12, 14), padx=10)
            tk.Button(nav, text='←', command=lambda: self._step_remote(-1), bg='#16a34a', fg='white', relief='flat', width=5).pack(side='left')
            self.remote_page_label = tk.Label(nav, text='1/1', bg='#1f2937', fg='white', font=('Arial', 12, 'bold'), padx=20, pady=8)
            self.remote_page_label.pack(side='left', expand=True, padx=8)
            tk.Button(nav, text='→', command=lambda: self._step_remote(1), bg='#16a34a', fg='white', relief='flat', width=5).pack(side='right')
        else:
            self.remote_panel.deiconify()
            self.remote_panel.lift()

        current_router = self._current_router()
        rows_for_remote = list(current_router.get('rows', []))
        raw = str(current_router.get('_ui_remote_entry').get().strip() if current_router.get('_ui_remote_entry') else current_router.get('remote_select', 'all'))
        current_router['remote_select'] = raw or 'all'
        self.remote_context = {'router': current_router, 'machines': list(rows_for_remote), 'index': 0, 'all_rows': rows_for_remote, 'token': self.remote_context.get('token', 0) + 1}
        self._apply_remote_selection()
        self.remote_panel.bind('<Left>', lambda _e: self._step_remote(-1))
        self.remote_panel.bind('<Right>', lambda _e: self._step_remote(1))
        self.remote_panel.focus_force()
        self._append_router_log(current_router, f'REMOTE popup mở với bộ chọn riêng: {current_router["remote_select"]}')

    def _close_remote_panel(self):
        if self.remote_panel is not None:
            self.remote_panel.destroy()
            self.remote_panel = None
            self.remote_header_label = None
            self.remote_status_label = None
            self.remote_preview_label = None
            self.remote_machine_list_frame = None
            self.remote_page_label = None
            self.remote_select_entry = None
            self.remote_preview_wrap = None
            self.remote_zoom_var = None
            if self.remote_refresh_job:
                try:
                    self.after_cancel(self.remote_refresh_job)
                except Exception:
                    pass
                self.remote_refresh_job = None
            self.remote_context = {'router': None, 'machines': [], 'index': 0, 'token': self.remote_context.get('token', 0) + 1}

    def _step_remote(self, delta):
        machines = self.remote_context.get('machines') or []
        if not machines:
            return
        idx = int(self.remote_context.get('index', 0)) + int(delta)
        idx = max(0, min(len(machines) - 1, idx))
        self.remote_context['index'] = idx
        self._render_remote_panel()

    def _select_remote_machine(self, idx):
        self.remote_context['index'] = idx
        self._render_remote_panel()

    def _render_remote_panel(self):
        if self.remote_panel is None:
            return
        machines = self.remote_context.get('machines') or []
        idx = int(self.remote_context.get('index', 0))
        if not machines:
            return
        idx = max(0, min(len(machines) - 1, idx))
        self.remote_context['index'] = idx
        machine = machines[idx]
        machine_no = machine.get('machine', '?')
        if self.remote_header_label:
            self.remote_header_label.config(text=f'MÁY {machine_no}')
        if self.remote_status_label:
            self.remote_status_label.config(text=f'Đang xem remote máy {machine_no}')
        if self.remote_refresh_job:
            try:
                self.after_cancel(self.remote_refresh_job)
            except Exception:
                pass
            self.remote_refresh_job = None
        if self.remote_preview_label:
            ip = machine.get("ip", "") or "-"
            self.remote_preview_label.configure(image='', text=f'REMOTE ĐANG MỞ\n\nMÁY {machine_no}\nIP {ip}\n\nĐang tải ảnh thật...', anchor='center', compound='center', bg='#111827')
            self.remote_preview_label.image = None
            self.remote_screen_info = {'width': None, 'height': None}
            self._load_remote_snapshot(machine, self.remote_context.get('token', 0))
        if self.remote_page_label:
            self.remote_page_label.config(text=f'{idx + 1}/{len(machines)}')
        if self.remote_machine_list_frame:
            for child in self.remote_machine_list_frame.winfo_children():
                child.destroy()
            page_size = 64
            total_pages = max(1, (len(machines) + page_size - 1) // page_size)
            current_page = (idx // page_size) + 1
            start = (current_page - 1) * page_size
            end = min(start + page_size, len(machines))
            visible = machines[start:end]
            for j, item in enumerate(visible):
                real_index = start + j
                active = real_index == idx
                btn = tk.Button(
                    self.remote_machine_list_frame,
                    text=str(item.get('machine', '?')),
                    width=5,
                    bg='#16a34a' if active else '#1f2937',
                    fg='white',
                    relief='flat',
                    font=('Arial', 11, 'bold'),
                    command=lambda ii=real_index: self._select_remote_machine(ii)
                )
                btn.grid(row=j // 4, column=j % 4, padx=4, pady=4, sticky='nsew')
            if self.remote_page_label:
                self.remote_page_label.config(text=f'{current_page}/{total_pages}')

    def _apply_remote_selection(self):
        router = self.remote_context.get('router')
        rows = self.remote_context.get('all_rows') or []
        raw = self.remote_select_entry.get().strip().lower() if self.remote_select_entry else 'all'
        if router is not None:
            router['remote_select'] = raw or 'all'
            save_router_config(self.routers)
        if raw == 'all':
            machines = list(rows)
        else:
            wanted = set()
            for part in raw.split(','):
                token = part.strip()
                if not token:
                    continue
                if '-' in token:
                    a, b = token.split('-', 1)
                    try:
                        start = int(a.strip())
                        end = int(b.strip())
                        for num in range(start, end + 1):
                            wanted.add(str(num))
                    except Exception:
                        continue
                else:
                    wanted.add(token)
            machines = [row for row in rows if str(row.get('machine', '')).strip() in wanted]
        self.remote_context['machines'] = machines
        self.remote_context['index'] = 0
        self.remote_context['token'] = self.remote_context.get('token', 0) + 1
        self._render_remote_panel()
        if router:
            self._append_router_log(router, f'REMOTE chọn riêng {len(machines)} máy')

    def _schedule_remote_refresh(self, machine, token, delay_ms=250):
        if token != self.remote_context.get('token', 0) or self.remote_panel is None:
            return
        if self.remote_refresh_job:
            try:
                self.after_cancel(self.remote_refresh_job)
            except Exception:
                pass
        self.remote_refresh_job = self.after(delay_ms, lambda: self._load_remote_snapshot(machine, token))

    def _load_remote_snapshot(self, machine, token):
        current_machine = str(machine.get('machine', '?'))
        def worker():
            ip = str(machine.get('ip') or '').strip()
            if not ip:
                if token != self.remote_context.get('token', 0):
                    return
                self.after(0, lambda: self.remote_preview_label.config(text=f'REMOTE ĐANG MỞ\n\nMÁY {current_machine}\n\nThiếu IP'))
                return
            try:
                client = XXTouchOpenAPIClient(f'http://{ip}:46952', timeout=3, connect_timeout=0.35, read_timeout=1.0)
                try:
                    info_resp = client.deviceinfo()
                    info = info_resp.get('data', info_resp) if isinstance(info_resp, dict) else {}
                    screen_text = str(info.get('screen', '') or '')
                    if 'x' in screen_text.lower():
                        parts = screen_text.lower().replace(' ', '').split('x')
                        if len(parts) == 2 and parts[0].isdigit() and parts[1].isdigit():
                            self.remote_screen_info = {'width': int(parts[0]), 'height': int(parts[1])}
                except Exception:
                    pass
                image_bytes = client.snapshot()
                if token != self.remote_context.get('token', 0):
                    return
                self.after(0, lambda b=image_bytes, m=current_machine, t=token, row=machine: (self._show_remote_snapshot(m, b), self._schedule_remote_refresh(row, t, 180)) if t == self.remote_context.get('token', 0) else None)
            except Exception as e:
                if token != self.remote_context.get('token', 0):
                    return
                self.after(0, lambda err=str(e), m=current_machine, t=token, row=machine: (self.remote_preview_label.config(text=f'REMOTE ĐANG MỞ\n\nMÁY {m}\nIP {ip}\n\n{err}'), self._schedule_remote_refresh(row, t, 500)) if t == self.remote_context.get('token', 0) else None)

        threading.Thread(target=worker, daemon=True).start()

    def _refresh_remote_zoom(self):
        if not self.remote_preview_label:
            return
        source = getattr(self.remote_preview_label, '_source_image', None)
        if source:
            self._fit_remote_preview(source.width(), source.height())
            try:
                zoom = float(self.remote_zoom_var.get()) if self.remote_zoom_var else 0.82
                subsample = max(1, int(round(1.0 / max(zoom, 0.05))))
                scaled = source.subsample(subsample, subsample)
                self.remote_preview_label.configure(image=scaled, text='')
                self.remote_preview_label.image = scaled
            except Exception:
                pass

    def _fit_remote_preview(self, image_w, image_h):
        if not self.remote_preview_wrap or not self.remote_preview_label:
            return
        self.update_idletasks()
        wrap_w = max(240, self.remote_preview_wrap.winfo_width() - 80)
        wrap_h = max(320, self.remote_preview_wrap.winfo_height() - 80)
        zoom = float(self.remote_zoom_var.get()) if self.remote_zoom_var else 0.82
        screen_w = self.remote_screen_info.get('width') or image_w
        screen_h = self.remote_screen_info.get('height') or image_h
        if screen_w and screen_h and screen_w > screen_h:
            screen_w, screen_h = screen_h, screen_w
        auto_ratio = (screen_w / screen_h) if screen_w and screen_h else ((image_w / image_h) if image_w and image_h else (9 / 19.5))
        target_h = int(wrap_h * zoom)
        target_w = int(target_h * auto_ratio)
        if target_w > int(wrap_w * zoom):
            target_w = int(wrap_w * zoom)
            target_h = int(target_w / max(auto_ratio, 0.01))
        if target_h > int(wrap_h * zoom):
            target_h = int(wrap_h * zoom)
            target_w = int(target_h * auto_ratio)
        target_w = max(110, target_w)
        target_h = max(220, target_h)
        self.remote_preview_label.place(relx=0.5, rely=0.5, anchor='center', width=target_w, height=target_h)

    def _show_remote_snapshot(self, machine_no, image_bytes):
        try:
            img = tk.PhotoImage(data=base64.b64encode(image_bytes).decode('ascii'))
            self.remote_preview_label._source_image = img
            zoom = float(self.remote_zoom_var.get()) if self.remote_zoom_var else 0.82
            display_img = img
            try:
                subsample = max(1, int(round(1.0 / max(zoom, 0.05))))
                display_img = img.subsample(subsample, subsample)
            except Exception:
                display_img = img
            self._fit_remote_preview(display_img.width(), display_img.height())
            self.remote_preview_label.configure(image=display_img, text='', compound='center', anchor='center', bg='#000000')
            self.remote_preview_label.image = display_img
        except Exception as e:
            self.remote_preview_label.configure(text=f'REMOTE máy {machine_no} đang mở nhưng chưa render được ảnh thật\n{e}')

    def _home_command(self):
        return 'app = require("app")\ndevice = require("device")\nsys = require("sys")\n\nwhile (device.is_screen_locked()) do\n device.unlock_screen()\n sys.msleep(1000)\nend\n\napp.run("com.apple.springboard")\nsys.toast("HOME_OK")\nprint("HOME_OK")\n'

    def _lock_home_command(self):
        return 'key = require("key")\nkey.press(0x0C, 48)\nprint("POWER_OK")\n'

    def _clear_app_command(self):
        return 'device = require("device")\nsys = require("sys")\napp = require("app")\n\nwhile (device.is_screen_locked()) do\n device.unlock_screen()\n sys.msleep(1000)\nend\n\nlocal ids = {\n "com.apple.weather",\n "com.apple.mobileme.fmip1",\n "com.apple.Home",\n "com.apple.MobileAddressBook",\n "com.apple.stocks",\n "com.apple.Translate",\n "com.apple.iBooks",\n "com.apple.calculator",\n "com.apple.compass",\n "com.apple.facetime",\n "com.apple.mobilemail",\n "com.apple.Maps",\n "com.apple.podcasts",\n "com.apple.reminders",\n "com.apple.tv",\n "com.apple.Passbook",\n "com.apple.mobilecal",\n "com.apple.Magnifier",\n "com.apple.measure",\n "com.apple.Music",\n "com.apple.VoiceMemos",\n "com.apple.Bridge"\n}\n\nlocal removed = 0\nfor i = 1, #ids do\n local ok = pcall(app.uninstall, ids[i])\n if ok then\n  removed = removed + 1\n end\n sys.msleep(500)\nend\n\nsys.toast("Đã gỡ " .. tostring(removed) .. " ứng dụng")\n'

    def _remove_tiktok_lite_command(self):
        return 'device = require("device")\nsys = require("sys")\napp = require("app")\n\nwhile (device.is_screen_locked()) do\n device.unlock_screen()\n sys.msleep(1000)\nend\n\nlocal ok = pcall(app.uninstall, "com.ss.iphone.ugc.tiktok.lite")\nsys.toast(ok and "Gỡ Tiktok Lite Thành Công" or "Gỡ Tiktok Lite Thất Bại")\n'

    def _remove_tiktok_command(self):
        return 'device = require("device")\nsys = require("sys")\napp = require("app")\n\nwhile (device.is_screen_locked()) do\n device.unlock_screen()\n sys.msleep(1000)\nend\n\nlocal ok = pcall(app.uninstall, "com.ss.iphone.ugc.Ame")\nsys.toast(ok and "Gỡ Tiktok Thành Công" or "Gỡ Tiktok Thất Bại")\n'

    def _install_tiktok_command(self):
        return 'device = require("device")\nsys = require("sys")\napp = require("app")\n\nwhile (device.is_screen_locked()) do\n device.unlock_screen()\n sys.msleep(1000)\nend\n\npcall(app.quit, "com.apple.AppStore")\nsys.msleep(1500)\npcall(app.quit, "com.apple.mobilesafari")\nsys.msleep(1000)\n\nlocal ok = pcall(app.open_url, "https://apps.apple.com/jp/app/tiktok-%E3%83%86%E3%82%A3%E3%83%83%E3%82%AF%E3%83%88%E3%83%83%E3%82%AF/id1235601864")\nsys.toast(ok and "Đã mở link TikTok " or "Mở link thất bại")\n'

    def _install_tiktok_lite_command(self):
        return 'device = require("device")\nsys = require("sys")\napp = require("app")\n\nwhile (device.is_screen_locked()) do\n device.unlock_screen()\n sys.msleep(1000)\nend\n\npcall(app.quit, "com.apple.AppStore")\nsys.msleep(1500)\npcall(app.quit, "com.apple.mobilesafari")\nsys.msleep(1000)\n\nlocal ok = pcall(app.open_url, "https://apps.apple.com/jp/app/tiktok-lite/id6447160980?l=en-US")\nsys.toast(ok and "Đã mở link TikTok Lite" or "Mở link thất bại")\n'

    def _quit_apps_command(self):
        return 'device = require("device")\nsys = require("sys")\napp = require("app")\n\nwhile (device.is_screen_locked()) do\n device.unlock_screen()\n sys.msleep(1000)\nend\n\nlocal ids = {\n "com.apple.mobilesafari",\n "com.apple.Preferences",\n "com.apple.AppStore",\n "com.ss.iphone.ugc.Ame",\n "com.ss.iphone.tiktok.lite",\n "com.apple.DocumentsApp",\n "com.apple.camera",\n "com.apple.mobiletimer",\n "com.tigisoftware.Filza",\n "com.tigisoftware.ADManager",\n "com.apple.findmy",\n "com.apple.Health",\n "com.apple.MobileSMS",\n "com.apple.mobilenotes",\n "com.apple.mobilephone",\n "com.apple.mobileslideshow",\n "com.apple.shortcuts",\n "com.apple.tips",\n "com.opa334.TrollStore",\n "ch.xxtou.XXTExplorer"\n}\n\nfor i = 1, #ids do\n pcall(app.quit, ids[i])\n sys.msleep(300)\nend\n\nsys.toast("Đã đóng ứng dụng")\n'

    def _try_recycle_before_spawn(self, client):
        try:
            client.recycle()
            time.sleep(0.35)
            return
        except urllib.error.HTTPError as e:
            if getattr(e, 'code', None) not in (404, 405):
                raise
        except Exception:
            pass

    def _run_parallel_rows(self, router, rows, task, action_name, per_success=None):
        if not rows:
            self._append_router_log(router, f'{action_name}: không có máy nào được chọn')
            return
        self._append_router_log(router, f'{action_name}: bắt đầu chạy đồng thời {len(rows)} máy')

        def worker():
            success = 0
            failed = 0
            failed_rows = []
            failed_by_error = {}
            max_workers = min(32, max(1, len(rows)))
            with ThreadPoolExecutor(max_workers=max_workers) as pool:
                future_map = {pool.submit(task, row): row for row in rows}
                for future in as_completed(future_map):
                    row = future_map[future]
                    try:
                        future.result()
                        success += 1
                        if per_success:
                            self.after(0, lambda r=row: self._append_router_log(router, per_success(r)))
                    except Exception as e:
                        failed += 1
                        row['updated'] = now_text()
                        row['network'] = 'Lỗi'
                        err = str(e)
                        machine = str(row.get('machine', '?'))
                        failed_rows.append(machine)
                        failed_by_error.setdefault(err, []).append(machine)
                        self.after(0, lambda r=row, err=err: self._append_router_log(router, f'[{r.get("machine", "?")}] {action_name} lỗi: {err}'))
            router['last_failed_action'] = None
            if failed_rows:
                router['last_failed_action'] = {
                    'action_name': action_name,
                    'machines': failed_rows,
                }
            save_router_config(self.routers)
            self.after(0, lambda: self._refresh_router_devices(router))
            self.after(0, lambda: self._append_router_log(router, f'{action_name}: thành công {success}, lỗi {failed}'))
            if failed_by_error:
                for err, machines in failed_by_error.items():
                    self.after(0, lambda err=err, machines=machines: self._append_router_log(router, f'{err} : {",".join(machines)}'))

        threading.Thread(target=worker, daemon=True).start()

    def _stop_scripts_for_router(self, router):
        rows = self._selected_rows(router)

        def task(row):
            ip = str(row.get('ip') or '').strip()
            if not ip:
                raise XXTouchOpenAPIError('Thiếu IP')
            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=5)
            client.recycle()
            row['network'] = 'Online'
            row['xxtouch'] = 'Connected'
            row['updated'] = now_text()
            return row

        self._run_parallel_rows(router, rows, task, 'STOP SCRIPT', per_success=lambda row: f'[{row.get("machine", "?")}] STOP SCRIPT OK')

    def _run_home_for_router(self, router):
        rows = self._selected_rows(router)
        command = self._home_command()

        def task(row):
            ip = str(row.get('ip') or '').strip()
            if not ip:
                raise XXTouchOpenAPIError('Thiếu IP')
            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=5)
            self._try_recycle_before_spawn(client)
            client.spawn(command)
            row['network'] = 'Online'
            row['xxtouch'] = 'Connected'
            row['updated'] = now_text()
            return row

        self._run_parallel_rows(router, rows, task, 'HOME', per_success=lambda row: f'[{row.get("machine", "?")}] HOME OK')

    def _run_lock_home_for_router(self, router):
        rows = self._selected_rows(router)
        command = self._lock_home_command()

        def task(row):
            ip = str(row.get('ip') or '').strip()
            if not ip:
                raise XXTouchOpenAPIError('Thiếu IP')
            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=5)
            self._try_recycle_before_spawn(client)
            client.spawn(command)
            row['network'] = 'Online'
            row['xxtouch'] = 'Connected'
            row['updated'] = now_text()
            return row

        self._run_parallel_rows(router, rows, task, 'LOCK HOME', per_success=lambda row: f'[{row.get("machine", "?")}] LOCK HOME OK')

    def _run_clear_app_for_router(self, router):
        self._run_spawn_command_for_router(router, self._clear_app_command(), 'CLEAR APP')

    def _rerun_last_failed_action_for_router(self, router):
        retry = router.get('last_failed_action') or {}
        action_name = str(retry.get('action_name') or '').strip()
        machines = [str(x).strip() for x in (retry.get('machines') or []) if str(x).strip()]
        if not action_name or not machines:
            self._append_router_log(router, 'RE-ACTION: không có lỗi trước đó để chạy lại')
            return
        self._append_router_log(router, f'RE-ACTION: chạy lại {action_name} cho máy lỗi {",".join(machines)}')
        old_value = str(router.get('ui_list', 'all') or 'all')
        list_widget = router.get('_ui_list_widget')
        retry_value = ','.join(machines)
        try:
            router['ui_list'] = retry_value
            router['ui_group'] = retry_value
            if list_widget is not None:
                list_widget.delete(0, 'end')
                list_widget.insert(0, retry_value)
            action_map = {
                'STOP SCRIPT': self._stop_scripts_for_router,
                'HOME': self._run_home_for_router,
                'LOCK HOME': self._run_lock_home_for_router,
                'CLEAR APP': self._run_clear_app_for_router,
                'GỠ TIKTOK LITE': self._run_remove_tiktok_lite_for_router,
                'GỠ TIKTOK': self._run_remove_tiktok_for_router,
                'CÀI TIKTOK': self._run_install_tiktok_for_router,
                'CÀI TIKTOK LITE': self._run_install_tiktok_lite_for_router,
                'ĐÓNG ỨNG DỤNG': self._run_quit_apps_for_router,
                'SEND FILE': lambda rr: self._send_files_for_router(rr, rr.get('send_dest', 'examples')),
                'SCAN': self._scan_router,
                'UI': lambda rr: self._run_group3_action(rr, 'ui'),
                'Group3_NuoiPhoi_tiktok.lua': lambda rr: self._run_group3_action(rr, 'nurture'),
                'Group3_NuoiPhoi_tiktok_lite.lua': lambda rr: self._run_group3_action(rr, 'nurture'),
                'Group3_EventVideo180_tiktok.lua': lambda rr: self._run_group3_action(rr, 'event_video_180'),
                'Group3_EventVideo180_tiktok_lite.lua': lambda rr: self._run_group3_action(rr, 'event_video_180'),
                'Group3_EventDD20p_tiktok.lua': lambda rr: self._run_group3_action(rr, 'event_dd_20p'),
                'Group3_EventDD20p_tiktok_lite.lua': lambda rr: self._run_group3_action(rr, 'event_dd_20p'),
                'SELECT SCRIPT': lambda rr: self._append_router_log(rr, 'RE-ACTION: SELECT SCRIPT chưa hỗ trợ chạy lại tự động'),
            }
            fn = action_map.get(action_name)
            if not fn:
                self._append_router_log(router, f'RE-ACTION: chưa hỗ trợ action {action_name}')
                return
            fn(router)
        finally:
            router['ui_list'] = old_value
            router['ui_group'] = old_value
            if list_widget is not None:
                list_widget.delete(0, 'end')
                list_widget.insert(0, old_value)

    def _run_remove_tiktok_lite_for_router(self, router):
        self._run_spawn_command_for_router(router, self._remove_tiktok_lite_command(), 'GỠ TIKTOK LITE')

    def _run_remove_tiktok_for_router(self, router):
        self._run_spawn_command_for_router(router, self._remove_tiktok_command(), 'GỠ TIKTOK')

    def _run_install_tiktok_for_router(self, router):
        self._run_spawn_command_for_router(router, self._install_tiktok_command(), 'CÀI TIKTOK')

    def _run_install_tiktok_lite_for_router(self, router):
        self._run_spawn_command_for_router(router, self._install_tiktok_lite_command(), 'CÀI TIKTOK LITE')

    def _run_quit_apps_for_router(self, router):
        self._run_spawn_command_for_router(router, self._quit_apps_command(), 'ĐÓNG ỨNG DỤNG')

    def _spawn_task_for_row(self, router, row, command, action_name, stop_first=True, read_timeout=6):
        ip = str(row.get('ip') or '').strip()
        if not ip:
            raise XXTouchOpenAPIError('Thiếu IP')
        client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=read_timeout)
        if stop_first:
            self._append_router_log(router, f'[{row.get("machine", "?")}] {action_name}: STOP SCRIPT trước khi chạy')
            client.recycle()
            time.sleep(0.8)
        client.spawn(command)
        row['network'] = 'Online'
        row['xxtouch'] = 'Connected'
        row['updated'] = now_text()
        return row

    def _run_floating_ui_for_router(self, router, script_path):
        rows = self._selected_rows(router)
        if not rows:
            self._append_router_log(router, 'UI: không có máy nào được chọn')
            return

        remote_path = '/var/mobile/Media/1ferver/lua/scripts/floating_menu.lua'

        def task(row):
            ip = str(row.get('ip') or '').strip()
            if not ip:
                raise XXTouchOpenAPIError('Thiếu IP')
            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=8)
            self._append_router_log(router, f'[{row.get("machine", "?")}] UI: STOP SCRIPT trước khi chạy')
            client.recycle()
            time.sleep(0.8)
            try:
                select_resp = client._post_json('/select_script_file', {'filename': remote_path})
                conf = client._post_json('/get_selected_script_file', {})
                launch_resp = client._post_json('/launch_script_file', {'filename': remote_path})
            except Exception as e:
                raise XXTouchOpenAPIError(f'Không chạy được floating_menu.lua: {e}')
            conf_data = conf.get('data', conf) if isinstance(conf, dict) else {}
            active_script = str(conf_data.get('filename') or '').strip()
            if active_script not in ('floating_menu.lua', remote_path):
                details = select_resp.get('message') if isinstance(select_resp, dict) else select_resp
                raise XXTouchOpenAPIError(f'Set selected script chưa ăn, current={active_script or "<trống>"}, select={details}')
            launch_data = launch_resp.get('data', launch_resp) if isinstance(launch_resp, dict) else launch_resp
            launch_message = launch_resp.get('message') if isinstance(launch_resp, dict) else ''
            row['ui_selected_script'] = active_script
            row['ui_launch_result'] = str(launch_data or launch_message or 'OK')
            row['network'] = 'Online'
            row['xxtouch'] = 'Connected'
            row['updated'] = now_text()
            return row

        self._run_parallel_rows(router, rows, task, 'UI', per_success=lambda row: f'[{row.get("machine", "?")}] UI OK ({row.get("ui_selected_script", remote_path)})')

    def _run_set_selected_script_for_router(self, router, script_name, script_bytes):
        rows = self._selected_rows(router)
        if not rows:
            self._append_router_log(router, 'SELECT SCRIPT: không có máy nào được chọn')
            return
        safe_name = Path(script_name).name.strip()
        if not safe_name:
            self._append_router_log(router, 'SELECT SCRIPT: tên script không hợp lệ')
            return
        if not safe_name.lower().endswith('.lua'):
            safe_name += '.lua'
        remote_path = f'/var/mobile/Media/1ferver/lua/scripts/{safe_name}'
        self._append_router_log(router, f'SELECT SCRIPT: bắt đầu set {safe_name} cho {len(rows)} máy, đồng thời đặt click_volume_up/down = 1')

        def task(row):
            ip = str(row.get('ip') or '').strip()
            if not ip:
                raise XXTouchOpenAPIError('Thiếu IP')
            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=8)
            client.write_file(remote_path, script_bytes)
            try:
                select_resp = client._post_json('/select_script_file', {'filename': remote_path})
                client._post_raw('/set_click_volume_up_action', '1')
                client._post_raw('/set_click_volume_down_action', '1')
                conf = client._post_json('/get_selected_script_file', {})
                volume_conf = client._post_raw('/get_volume_action_conf', b'')
            except Exception as e:
                raise XXTouchOpenAPIError(f'Không set được selected script/volume action: {e}')
            conf_data = conf.get('data', conf) if isinstance(conf, dict) else {}
            active_script = str(conf_data.get('filename') or '').strip()
            if active_script not in (safe_name, remote_path):
                details = select_resp.get('message') if isinstance(select_resp, dict) else select_resp
                raise XXTouchOpenAPIError(f'Set select chưa ăn, current={active_script or "<trống>"}, select={details}')
            vol_data = volume_conf.get('data', volume_conf) if isinstance(volume_conf, dict) else {}
            up_action = str(vol_data.get('click_volume_up', '')).strip()
            down_action = str(vol_data.get('click_volume_down', '')).strip()
            if up_action != '1' or down_action != '1':
                raise XXTouchOpenAPIError(f'Set volume action chưa ăn, up={up_action or "<trống>"}, down={down_action or "<trống>"}')
            row['selected_script'] = active_script
            row['click_volume_up'] = up_action
            row['click_volume_down'] = down_action
            row['network'] = 'Online'
            row['xxtouch'] = 'Connected'
            row['updated'] = now_text()
            return row

        self._run_parallel_rows(router, rows, task, 'SELECT SCRIPT', per_success=lambda row: f'[{row.get("machine", "?")}] SELECT SCRIPT OK ({safe_name}) | VOL UP/DOWN=1')

    def _run_spawn_command_for_router(self, router, command, action_name, stop_first=True, read_timeout=6):
        rows = self._selected_rows(router)

        def task(row):
            return self._spawn_task_for_row(router, row, command, action_name, stop_first=stop_first, read_timeout=read_timeout)

        self._run_parallel_rows(router, rows, task, action_name, per_success=lambda row: f'[{row.get("machine", "?")}] {action_name} OK')

    def _run_spawn_batched_for_router(self, router, command, action_name, batch_size=10, batch_delay=10, stop_first=True, read_timeout=6):
        rows = self._selected_rows(router)
        if not rows:
            self._append_router_log(router, f'{action_name}: không có máy nào được chọn')
            return
        total = len(rows)
        self._append_router_log(router, f'{action_name}: chạy theo đợt {batch_size} máy, nghỉ {batch_delay}s giữa các đợt, tổng {total} máy')

        def worker():
            success = 0
            failed = 0
            for batch_index, start in enumerate(range(0, total, batch_size), start=1):
                batch_rows = rows[start:start + batch_size]
                self.after(0, lambda idx=batch_index, count=len(batch_rows): self._append_router_log(router, f'{action_name}: bắt đầu đợt {idx} ({count} máy)'))
                max_workers = min(batch_size, max(1, len(batch_rows)))
                with ThreadPoolExecutor(max_workers=max_workers) as pool:
                    future_map = {
                        pool.submit(self._spawn_task_for_row, router, row, command, action_name, stop_first, read_timeout): row
                        for row in batch_rows
                    }
                    for future in as_completed(future_map):
                        row = future_map[future]
                        try:
                            future.result()
                            success += 1
                            self.after(0, lambda r=row: self._append_router_log(router, f'[{r.get("machine", "?")}] {action_name} OK'))
                        except Exception as e:
                            failed += 1
                            row['updated'] = now_text()
                            row['network'] = 'Lỗi'
                            self.after(0, lambda r=row, err=str(e): self._append_router_log(router, f'[{r.get("machine", "?")}] {action_name} lỗi: {err}'))
                if start + batch_size < total:
                    self.after(0, lambda idx=batch_index, wait=batch_delay: self._append_router_log(router, f'{action_name}: đợt {idx} xong, chờ {wait}s sang đợt tiếp'))
                    time.sleep(batch_delay)
            save_router_config(self.routers)
            self.after(0, lambda: self._refresh_router_devices(router))
            self.after(0, lambda: self._append_router_log(router, f'{action_name}: thành công {success}, lỗi {failed}'))

        threading.Thread(target=worker, daemon=True).start()

    def _open_txt_lines_popup(self, router):
        win = tk.Toplevel(self)
        win.title(f'TXT theo router - {router.get("name", "")}')
        win.geometry('880x620')
        win.configure(bg='#0f172a')

        wrap = ttk.Frame(win, style='Card.TFrame', padding=12)
        wrap.pack(fill='both', expand=True, padx=12, pady=12)
        ttk.Label(wrap, text='TXT data source', style='Title.TLabel').pack(anchor='w')
        ttk.Label(wrap, text='Dán danh sách nhiều dòng. SEND TXT sẽ cấp mỗi máy 1 dòng và ghi vào lua/examples/input.txt trên từng máy.', style='Sub.TLabel').pack(anchor='w', pady=(0, 10))

        counter_var = tk.StringVar()
        columns = ('stt', 'line')
        tree_wrap = ttk.Frame(wrap, style='Card.TFrame')
        tree_wrap.pack(fill='both', expand=True)
        tree = ttk.Treeview(tree_wrap, columns=columns, show='headings', height=14)
        tree.heading('stt', text='STT')
        tree.heading('line', text='Dữ liệu')
        tree.column('stt', width=70, anchor='center', stretch=False)
        tree.column('line', width=720, anchor='w')
        ysb = ttk.Scrollbar(tree_wrap, orient='vertical', command=tree.yview)
        tree.configure(yscrollcommand=ysb.set)
        tree.pack(side='left', fill='both', expand=True)
        ysb.pack(side='right', fill='y')

        input_box = tk.Text(wrap, height=8, bg='#0f172a', fg='#e5e7eb', insertbackground='#e5e7eb', relief='solid', borderwidth=1, font=('Consolas', 11))
        input_box.pack(fill='x', pady=(10, 8))
        ttk.Label(wrap, textvariable=counter_var, style='Sub.TLabel').pack(anchor='w', pady=(0, 8))

        def current_lines():
            return [str(line).strip() for line in (self.txt_pool or []) if str(line).strip()]

        def refresh_tree():
            for item in tree.get_children():
                tree.delete(item)
            lines = current_lines()
            for idx, line in enumerate(lines, start=1):
                tree.insert('', 'end', values=(idx, line))
            counter_var.set(f'Tổng dòng: {len(lines)}')

        def save_lines(lines, log=True):
            self.txt_pool = [str(line).strip() for line in (lines or []) if str(line).strip()]
            save_txt_pool(self.txt_pool)
            refresh_tree()
            if log:
                self._append_router_log(router, f'TXT dùng chung: đã lưu {len(self.txt_pool)} dòng')

        def add_lines():
            new_lines = [line.strip() for line in input_box.get('1.0', 'end').splitlines() if line.strip()]
            if not new_lines:
                return
            merged = current_lines() + new_lines
            save_lines(merged)
            input_box.delete('1.0', 'end')

        def edit_selected():
            selected = tree.selection()
            if len(selected) != 1:
                return
            values = tree.item(selected[0], 'values')
            if not values:
                return
            input_box.delete('1.0', 'end')
            input_box.insert('1.0', str(values[1]))

        def apply_edit():
            selected = tree.selection()
            if len(selected) != 1:
                return
            new_value = input_box.get('1.0', 'end').strip()
            if not new_value:
                return
            idx = int(tree.item(selected[0], 'values')[0]) - 1
            lines = current_lines()
            if 0 <= idx < len(lines):
                lines[idx] = new_value
                save_lines(lines)
                input_box.delete('1.0', 'end')

        def remove_selected():
            selected = tree.selection()
            if not selected:
                return
            remove_indexes = sorted({int(tree.item(item, 'values')[0]) - 1 for item in selected}, reverse=True)
            lines = current_lines()
            for idx in remove_indexes:
                if 0 <= idx < len(lines):
                    lines.pop(idx)
            save_lines(lines)

        def clear_all():
            save_lines([], log=True)
            input_box.delete('1.0', 'end')

        def send_txt():
            rows = self._selected_rows(router)
            if not rows:
                self._append_router_log(router, 'SEND TXT: không có máy nào được chọn')
                return
            lines = current_lines()
            if not lines:
                self._append_router_log(router, 'SEND TXT: không có dòng nào để gửi')
                return
            needed = len(rows)
            if len(lines) < needed:
                self._append_router_log(router, f'SEND TXT: chỉ có {len(lines)} dòng, không đủ cho {needed} máy')
                return
            assigned = lines[:needed]
            remain = lines[needed:]
            target_path = 'lua/examples/input.txt'
            self._append_router_log(router, f'SEND TXT: bắt đầu gửi {needed} dòng tới {needed} máy, đích {target_path}')

            def worker():
                success = 0
                failed = 0
                max_workers = min(32, max(1, len(rows)))
                with ThreadPoolExecutor(max_workers=max_workers) as pool:
                    future_map = {}
                    for idx, row in enumerate(rows):
                        line = assigned[idx]
                        def task(target_row=row, target_line=line):
                            ip = str(target_row.get('ip') or '').strip()
                            if not ip:
                                raise XXTouchOpenAPIError('Thiếu IP')
                            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=8)
                            client.write_file(target_path, target_line.encode('utf-8'))
                            target_row['network'] = 'Online'
                            target_row['xxtouch'] = 'Connected'
                            target_row['updated'] = now_text()
                            return target_row
                        future = pool.submit(task)
                        future_map[future] = (row, line)
                    for future in as_completed(future_map):
                        row, line = future_map[future]
                        try:
                            future.result()
                            success += 1
                            self.after(0, lambda r=row, l=line: self._append_router_log(router, f'[{r.get("machine", "?")}] SEND TXT OK: {l}'))
                        except Exception as e:
                            failed += 1
                            row['updated'] = now_text()
                            row['network'] = 'Lỗi'
                            self.after(0, lambda r=row, err=str(e): self._append_router_log(router, f'[{r.get("machine", "?")}] SEND TXT lỗi: {err}'))
                if failed == 0:
                    self.txt_pool = remain
                    save_txt_pool(self.txt_pool)
                    self.after(0, refresh_tree)
                self.after(0, lambda: self._refresh_router_devices(router))
                self.after(0, lambda: self._append_router_log(router, f'SEND TXT: đã gửi {success} dòng, lỗi {failed}, còn lại {len(self.txt_pool)} dòng'))
            threading.Thread(target=worker, daemon=True).start()

        btn_row = ttk.Frame(wrap, style='Card.TFrame')
        btn_row.pack(fill='x', pady=(8, 0))
        ttk.Button(btn_row, text='Thêm danh sách', command=add_lines).pack(side='left')
        ttk.Button(btn_row, text='Sửa dòng chọn', command=edit_selected).pack(side='left', padx=(8, 0))
        ttk.Button(btn_row, text='Áp dụng sửa', command=apply_edit).pack(side='left', padx=(8, 0))
        ttk.Button(btn_row, text='Xóa dòng chọn', command=remove_selected).pack(side='left', padx=(8, 0))
        ttk.Button(btn_row, text='Clear all', command=clear_all).pack(side='left', padx=(8, 0))
        ttk.Button(btn_row, text='SEND TXT', command=send_txt).pack(side='right')
        ttk.Button(btn_row, text='Đóng', command=win.destroy).pack(side='right', padx=(0, 8))

        refresh_tree()

    def _run_inline_for_router(self, router):
        command = self.inline_editor.get('1.0', 'end-1c').strip() if self.inline_editor else ''
        if not command:
            self.after(0, lambda: messagebox.showwarning('Thiếu lệnh', 'Chưa có lệnh inline'))
            return
        rows = self._selected_rows(router)

        def task(row):
            ip = str(row.get('ip') or '').strip()
            if not ip:
                raise XXTouchOpenAPIError('Thiếu IP')
            client = XXTouchOpenAPIClient(f'http://{ip}:46952', connect_timeout=1.2, read_timeout=5)
            self._try_recycle_before_spawn(client)
            client.spawn(command)
            row['network'] = 'Online'
            row['xxtouch'] = 'Connected'
            row['updated'] = now_text()
            return row

        self._run_parallel_rows(router, rows, task, 'INLINE', per_success=lambda row: f'[{row.get("machine", "?")}] chạy inline OK')


if __name__ == '__main__':
    app = XXTouchOnlyDemo()
    app.mainloop()

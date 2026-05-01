# 2026-05-01 apply router fix/revert

- Continued work for Anh Thái on router `192.14.0.1` proxy manager apply flow.
- I incorrectly patched `run_apply()` to treat `uiState.router = All` as all configured admanager routers (`tiktok03`, `tiktok04`, `tiktok05`). User said this broke apply and those router names were unrelated/noise.
- User explicitly demanded restore. I reverted the `run_apply()` block back to the previous old-GUI call block:
  - builds `payload = build_old_gui_update_proxy_payload_from_rows(rows)`
  - calls `call_old_gui('/api/update_proxy', method='POST', data=payload)`
  - result labels are `POST old GUI /api/update_proxy`.
- Restarted `/etc/init.d/proxy-manager-v1` after revert.
- Verification grep on `/opt/proxy-manager-v1/app.py` showed `POST old GUI /api/update_proxy` present and no `LOCAL APPLY CONFIG` block in `run_apply` grep output.
- Lesson: do not touch apply again unless user gives exact requested change; do not infer admanager router `All` semantics from unrelated config names.

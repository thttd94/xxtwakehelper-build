Set shell = CreateObject("WScript.Shell")
cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Users\Administrator\.openclaw\workspace\openclaw-watchdog.ps1"""
shell.Run cmd, 0, False

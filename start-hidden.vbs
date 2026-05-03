Set WshShell = CreateObject("WScript.Shell")
cmd = """" & WScript.Arguments(0) & """"
For i = 1 To WScript.Arguments.Count - 1
  cmd = cmd & " " & """" & WScript.Arguments(i) & """"
Next
WshShell.Run cmd, 0, False

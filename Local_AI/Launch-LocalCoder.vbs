Set sh = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
sh.CurrentDirectory = root
cmd = "powershell.exe -Sta -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & root & "\run.ps1"""
sh.Run cmd, 0, False

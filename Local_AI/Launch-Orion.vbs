Set sh = CreateObject("Wscript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
root = fso.GetParentFolderName(WScript.ScriptFullName)
sh.CurrentDirectory = root
' Run the .cmd directly. cmd /c "path with spaces\file.cmd" is split by cmd.exe.
sh.Run """" & root & "\Start Orion.cmd""", 1, False

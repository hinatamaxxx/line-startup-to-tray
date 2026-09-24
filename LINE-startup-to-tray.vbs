Option Explicit

Dim shell, fso, scriptPath, commandLine
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
scriptPath = fso.BuildPath(fso.GetParentFolderName(WScript.ScriptFullName), "LINE-startup-to-tray.ps1")
commandLine = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & scriptPath & """"
shell.Run commandLine, 0, False

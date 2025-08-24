' Lanzar-ClassicUO.vbs (sin consola, sin parpadeo)
Option Explicit
Dim sh, fso, base, exe, settingsDir, dataDir, pluginsDir, latest, folder, f, newestTime, args

Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

base        = "C:\UltimaTarascaLauncher"
exe         = base & "\TazUO\ClassicUO.exe"
settingsDir = base & "\Profiles\Settings"
dataDir     = base & "\Profiles\Data"
pluginsDir  = base & "\Profiles\Plugins"

' Buscar el JSON de settings más reciente
latest = ""
If fso.FolderExists(settingsDir) Then
  Set folder = fso.GetFolder(settingsDir)
  newestTime = CDate("1970-01-01")
  For Each f In folder.Files
    If LCase(fso.GetExtensionName(f.Name)) = "json" Then
      If f.DateLastModified > newestTime Then
        newestTime = f.DateLastModified
        latest = f.Path
      End If
    End If
  Next
End If

args = ""
If latest <> "" Then args = args & " -settings """ & latest & """"
If fso.FolderExists(dataDir) Then args = args & " -data """ & dataDir & """"
If fso.FolderExists(pluginsDir) Then args = args & " -plugins """ & pluginsDir & """"

If Not fso.FileExists(exe) Then
  MsgBox "No se encontró: " & exe, vbCritical, "Error"
  WScript.Quit 1
End If

sh.CurrentDirectory = fso.GetParentFolderName(exe)
sh.Run """" & exe & """" & args, 0, False  ' 0 = oculto, False = no esperar
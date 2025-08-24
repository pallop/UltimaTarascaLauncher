' LanzadorTarasca.vbs — robusto con repregunta y diagnóstico
Option Explicit

Dim sh, fso, base, tazDir, exe, settingsDir, cfg, uopath, latest, args, silentFlag, logf
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

base        = "C:\UltimaTarascaLauncher"
tazDir      = base & "\TazUO"
exe         = tazDir & "\ClassicUO.exe"
settingsDir = base & "\Profiles\Settings"
cfg         = base & "\config.ini"
silentFlag  = base & "\.vbs_silent"
logf        = base & "\LanzadorTarasca.vbs.log"

Sub Log(msg)
  On Error Resume Next
  Dim ts : Set ts = fso.OpenTextFile(logf, 8, True)
  ts.WriteLine Now() & "  " & msg
  ts.Close
End Sub

Function LooksLikeUOClient(p)
  On Error Resume Next
  LooksLikeUOClient = (fso.FileExists(p & "\art.mul") Or fso.FileExists(p & "\artLegacyMUL.uop"))
End Function

Function ReadUOPath()
  On Error Resume Next
  Dim ts, line, val : val = ""
  If fso.FileExists(cfg) Then
    Set ts = fso.OpenTextFile(cfg, 1, False)
    Do While Not ts.AtEndOfStream
      line = Trim(ts.ReadLine)
      If LCase(Left(line,7)) = "uopath=" Then
        val = Mid(line,8)
        Exit Do
      End If
    Loop
    ts.Close
  End If
  ReadUOPath = val
End Function

Sub WriteUOPath(p)
  On Error Resume Next
  Dim ts : Set ts = fso.OpenTextFile(cfg, 2, True)
  ts.WriteLine "UOPath=" & p
  ts.Close
End Sub

Function BrowseUOPathLoop()
  On Error Resume Next
  Dim app, folder, sel
  Set app = CreateObject("Shell.Application")
  Do
    Set folder = app.BrowseForFolder(0, "Selecciona la carpeta del cliente UO (contiene art.mul o artLegacyMUL.uop)", 0, "C:\")
    If folder Is Nothing Then
      BrowseUOPathLoop = ""
      Exit Function
    End If
    sel = folder.Self.Path
    If LooksLikeUOClient(sel) Then
      BrowseUOPathLoop = sel
      Exit Function
    Else
      MsgBox "La carpeta seleccionada no parece un cliente UO válido." & vbCrLf & _
             "Debes elegir la carpeta que contiene 'art.mul' o 'artLegacyMUL.uop'.", _
             vbExclamation, "Ultima Tarasca"
    End If
  Loop
End Function

' --- MAIN ---
On Error Resume Next
Log "=== LanzadorTarasca.vbs START ==="

' 1) Resolver UOPath
uopath = ReadUOPath()
If (uopath = "") Or (Not LooksLikeUOClient(uopath)) Then
  uopath = BrowseUOPathLoop()
  If uopath = "" Then
    Log "UOPath no seleccionado (cancelado por el usuario)."
    MsgBox "Operación cancelada. No se configuró la ruta del cliente UO.", vbInformation, "Ultima Tarasca"
    WScript.Quit 1
  End If
  WriteUOPath uopath
End If
Log "UOPath=" & uopath

' 2) Settings más reciente (opcional)
latest = ""
If fso.FolderExists(settingsDir) Then
  Dim folder2, f, newest
  newest = CDate("1970-01-01")
  Set folder2 = fso.GetFolder(settingsDir)
  For Each f In folder2.Files
    If LCase(fso.GetExtensionName(f.Name)) = "json" Then
      If f.DateLastModified > newest Then
        newest = f.DateLastModified
        latest = f.Path
      End If
    End If
  Next
End If
If latest <> "" Then Log "Settings=" & latest

' 3) Comprobaciones de EXE
If Not fso.FileExists(exe) Then
  Log "ERROR: No se encontró ClassicUO.exe en " & exe
  MsgBox "No se encontró ClassicUO.exe en: " & exe, vbCritical, "Ultima Tarasca"
  WScript.Quit 1
End If

' 4) Construir argumentos
args = " -uopath """ & uopath & """"
If latest <> "" Then
  args = args & " -settings """ & latest & """"
End If

' 5) Inyectar PATH del PROCESO y forzar backend D3D11
Dim env
Set env = sh.Environment("PROCESS")
env("PATH") = tazDir & ";" & tazDir & "\x64;" & tazDir & "\lib64;" & tazDir & "\vulkan;" & env("PATH")
env("FNA3D_FORCE_DRIVER") = "D3D11"

' 6) Lanzar (visible la primera vez; oculto si .vbs_silent)
Dim winStyle : winStyle = 1
If fso.FileExists(silentFlag) Then winStyle = 0

sh.CurrentDirectory = tazDir
Dim cmd : cmd = """" & exe & """" & args
Log "CMD=" & cmd
Log "WD=" & tazDir

' Intento 1: esperar (para capturar exit code)
Dim t0, t1, rc
t0 = Timer
rc = sh.Run(cmd, winStyle, True)  ' True = esperar
t1 = Timer
Log "ExitCode=" & rc & "  Duración=" & CStr(Round(t1 - t0, 2)) & "s"

' Si duró < 2s, relanza sin esperar (por si abre otro proceso y cierra el bootstrapper)
If (t1 - t0) < 2 Then
  Log "Duración < 2s => reintento con 'start' (no espera)"
  sh.Run "cmd /c start ""UT"" " & cmd, winStyle, False
End If

Log "=== LanzadorTarasca.vbs END ==="
WScript.Quit 0

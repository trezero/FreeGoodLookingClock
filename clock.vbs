' Clock launcher: opens the clock in a chromeless Edge window, always at the
' same position and size, in its own dedicated Edge profile (so the window
' flags are honored every time). No visible console window. Fully portable —
' it locates its own folder and Edge, so the app can live anywhere.
Option Explicit

Dim sh, fso, proj, edge, udd, cfg, posX, posY, sizeW, sizeH, args
Set sh  = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

proj = fso.GetParentFolderName(WScript.ScriptFullName)

' --- Locate Microsoft Edge ---
Dim cand(2), i
cand(0) = sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%") & "\Microsoft\Edge\Application\msedge.exe"
cand(1) = sh.ExpandEnvironmentStrings("%ProgramFiles%")      & "\Microsoft\Edge\Application\msedge.exe"
cand(2) = sh.ExpandEnvironmentStrings("%LocalAppData%")      & "\Microsoft\Edge\Application\msedge.exe"
edge = ""
For i = 0 To UBound(cand)
  If fso.FileExists(cand(i)) Then edge = cand(i) : Exit For
Next
If edge = "" Then
  MsgBox "Microsoft Edge was not found. Please install Edge and try again.", vbExclamation, "Clock"
  WScript.Quit 1
End If

udd = sh.ExpandEnvironmentStrings("%LocalAppData%") & "\FreeGoodLookingClock-Edge"

' --- Window placement: read window.cfg (x / y / w / h, one per line) ---
posX = 100 : posY = 100 : sizeW = 480 : sizeH = 210
cfg = proj & "\window.cfg"
If fso.FileExists(cfg) Then
  Dim f, n, line
  Set f = fso.OpenTextFile(cfg, 1)
  n = 0
  Do While Not f.AtEndOfStream
    line = Trim(f.ReadLine)
    If line <> "" And IsNumeric(line) Then
      Select Case n
        Case 0 : posX  = CLng(line)
        Case 1 : posY  = CLng(line)
        Case 2 : sizeW = CLng(line)
        Case 3 : sizeH = CLng(line)
      End Select
      n = n + 1
    End If
  Loop
  f.Close
End If

' Start the bundled static server (hidden; exits if one is already running).
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & proj & "\server.ps1""", 0, False

' Refresh today's background (hidden; skips quickly if already done today).
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """ & proj & "\update-background.ps1""", 0, False

WScript.Sleep 1200

' Launch the chromeless clock window at the fixed position and size.
args = """" & edge & """" & _
  " --app=http://localhost:8080/index.html" & _
  " --user-data-dir=""" & udd & """" & _
  " --window-position=" & posX & "," & posY & _
  " --window-size=" & sizeW & "," & sizeH & _
  " --no-first-run --no-default-browser-check"
sh.Run args, 1, False

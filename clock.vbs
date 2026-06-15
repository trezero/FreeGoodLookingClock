' Clock launcher: opens the clock in a chromeless Edge window, always at the
' same position and size, in its own dedicated Edge profile (so the window
' flags are honored every time). No visible console window.
Option Explicit

Dim sh, proj, edge, udd, args
Set sh = CreateObject("WScript.Shell")

proj = "C:\Users\Jason Perr\projects\FreeGoodLookingClock"
edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
udd  = sh.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\FreeGoodLookingClock-Edge"

' --- Window placement (edit these to move/resize the clock) ---
Dim posX, posY, sizeW, sizeH
posX = 2343 : posY = 1224
sizeW = 403 : sizeH = 175

' Start the local server hidden. Harmless if one is already running on 8080
' (the second one simply can't bind the port and exits).
sh.CurrentDirectory = proj
sh.Run "cmd /c python -m http.server 8080", 0, False
WScript.Sleep 1000

' Launch the chromeless clock window at the fixed position and size.
args = """" & edge & """" & _
  " --app=http://localhost:8080/index.html" & _
  " --user-data-dir=""" & udd & """" & _
  " --window-position=" & posX & "," & posY & _
  " --window-size=" & sizeW & "," & sizeH & _
  " --no-first-run --no-default-browser-check"
sh.Run args, 1, False

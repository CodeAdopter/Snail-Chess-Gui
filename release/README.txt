Snail Chess GUI {version}

An open source chess GUI, written in Snail. This is an alpha: expect rough edges, and please report
what you find at https://github.com/CodeAdopter/Snail-Chess-Gui/issues.

Running it
- Unzip this folder anywhere you like and open "Snail Chess GUI.exe".
- Windows may say "Windows protected your PC", because this build is not code-signed yet. Choose
  "More info", then "Run anyway".
- It needs 64-bit Windows 10 or 11 and a graphics card with DirectX 12.

In this folder
- Snail Chess GUI.exe   the app
- snailchess.exe        Snail Chess, the chess engine that comes with it
- snailfast.exe         runs fastchess matches and SPRT tests from a terminal, shown live in the app
- SDL3.dll              the library the app opens its window with
- LICENSE.txt           the app's license, GPL-3.0-or-later
- licenses\             the licenses of the parts it includes

Your data
Settings, engines, books, games and the position database are kept in
%LOCALAPPDATA%\Snail Chess GUI. To keep them in this folder instead, create an empty file named
"portable", with no extension, next to the app.

Updating
Close the app and unzip the new version over this folder. Your data stays where it is.

Source code: https://github.com/CodeAdopter/Snail-Chess-Gui
Website: https://snail-chess-gui-web.vercel.app/

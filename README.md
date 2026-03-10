![Banner](banner.png)

# Age of Empires II: Definitive Edition - Drag Scroll

Adds drag scrolling to Age of Empires II: Definitive Edition. Hold middle mouse (or whichever bind you like) and drag to pan the camera, similarly to what you might find in games like StarCraft II.

Fork of [asieradzk's original script](https://github.com/asieradzk/AoE2Mouse_Camera_Drag), which aims to keep this functional throughout all future updates. 

---

## Requirements

- [AutoHotkey](https://www.autohotkey.com/) installed
- Run the script as **administrator** to avoid any potential permissions conflicts. 

---

## How to use

1. Download `AoE2DE-Drag-Scroll.ahk`
2. Right-click it and hit **Run as administrator**
3. Load into a game
4. Hold middle mouse (default key) and drag to pan

To stop the script, right-click the AutoHotkey icon in your taskbar and hit Exit.
To reload after making changes, press **Ctrl+Alt+R** while the script is running.

---

## Rebinding the key

Open the script in any text editor and change this line near the top:

```
PanKey := "MButton"
```

Some examples:
- `"RButton"` — right mouse button
- `"XButton1"` — mouse side button 1
- `"XButton2"` — mouse side button 2

Save the file and reload with Ctrl+Alt+R.

---

## If it breaks after a game update

The script reads camera position directly from the game's memory. When AoE2 updates, the memory addresses shift and the script stops working. You'll need to find the new offsets using Cheat Engine and update these lines in the script:

```
baseOffset    := 0x040EC3B8
cameraXOffset := 0x2F0
cameraYOffset := 0x2F4
zoomOffset    := 0x3E90FB8
```

Here's how to find them:

1. Start a Single Player game on a Tiny map
2. Open Cheat Engine as administrator and attach to `AoE2DE_s.exe`
3. In memory scan options set Writable to **solid dot** and uncheck Executable
4. Scan for a Float, Value Between **50** and **200**
5. Pan the camera right → Increased value scan, pan left → Decreased value scan
6. Repeat until you're down to a handful of results
7. Test each one by writing the value **50** in Cheat Engine — the one that moves the camera is your writable camera X address
8. Right-click that address → Pointer scan, Max level 3, Max offset 0x1000, Only static pointers, compare across two game sessions to narrow it down
9. Pick the simplest pointer chain and update `baseOffset` and `cameraXOffset` in the script
10. Camera Y is always 4 bytes after X, so add 4 to whatever you got for `cameraXOffset`
11. For zoom, scan Float between **0.1** and **5.0**, zoom in and out — look for a result showing `AoE2DE_s.exe+offset`, that's your new `zoomOffset`

---

## Troubleshooting

**Camera doesn't move at all**
Make sure you're running the script as administrator. If you are, the offsets are probably outdated — see the section above.

**Writing a value in Cheat Engine doesn't move the camera**
That address is read-only. Skip it and try the next one — there's only one writable camera address.

**Script works but zoom scaling feels off**
The zoom offset is wrong or outdated. Redo the zoom scan.

**Middle click stopped working**
The script passes through a normal middle click if you didn't drag. If this isn't working, try reloading with Ctrl+Alt+R.

---

## License

MIT — same as the original. Do whatever you want with it.

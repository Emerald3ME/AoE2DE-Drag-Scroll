# Updating Memory Offsets After a Patch

AoE2DE updates occasionally shift the memory addresses the script relies on. When this happens the script stops working and the offsets need to be found again. This guide walks you through the full process using Cheat Engine.

---

## What you need

- [Cheat Engine](https://www.cheatengine.org/) — free memory scanning tool
- AoE2DE running in the background
- About under 30 minutes of spare time. 

---

## Understanding what we're looking for

The script needs four values:

| Variable | What it is |
|---|---|
| `baseOffset` | Static pointer to the camera struct in memory |
| `cameraXOffset` | Offset from the base to camera X (left/right position) |
| `cameraYOffset` | Offset from the base to camera Y (up/down position) — always 4 bytes after X |
| `zoomOffset` | Static pointer to the current zoom level |

---

## Part 1 — Finding the writable camera X address

The game stores dozens of copies of the camera position in memory, but only one of them actually controls the camera. We need to find that one.

1. Start a **Single Player** game on a **Tiny** map
2. Open Cheat Engine as administrator and attach to `AoE2DE_s.exe`
   - Click the computer icon top left
   - Find `AoE2DE_s.exe` in the list and click Open
   - If it asks to attach a debugger click **No**
3. Open **Memory Scan Options** and configure:
   - Set **Writable** to the **solid dot** (must be writable)
   - Uncheck **Executable**
   - Enable **Pause game while scanning**
4. Set **Value Type** to **Float** and **Scan Type** to **Value Between**
5. Enter **50** and **200** as the range and click **First Scan**
6. Hold the **right arrow key** for 3 seconds → switch to Cheat Engine → **Increased value** → Next Scan
7. Hold the **left arrow key** for 3 seconds → switch to Cheat Engine → **Decreased value** → Next Scan
8. Repeat step 6 and 7 until you're down to under 20 results
9. Add all results to the address list (Ctrl+A → right-click → Add selected addresses to address list)
10. Double-click the **value** of each address and type **50** — the one that makes the camera jump is your writable camera X address. Note it down.

---

## Part 2 — Finding the static pointer chain

The address you found above changes every time the game restarts. We need a static pointer that always leads to it.

1. Right-click the confirmed camera X address → **Pointer scan for this address**
2. Settings:
   - Max Different Offsets Per Node: **3**
   - Maximum Offset Value: **0x1000**
   - Check **Only find static pointers**
3. Click OK and save the file when prompted — call it something like `scan1`
4. Let it finish, then **restart AoE2** and load back into a game
5. Redo Part 1 to find the new camera X address (it will be different after restart)
6. Open the pointer scanner again, this time check **Compare results with other saved pointmap(s)** and load your `scan1` file
7. Enter the new camera X address and run the scan
8. From the results pick the **simplest pointer** — fewest offsets, starts with `AoE2DE_s.exe+`
9. That gives you your new `baseOffset` and `cameraXOffset`

Camera Y is always **4 bytes after X** — just add 4 to `cameraXOffset`.

---

## Part 3 — Finding the zoom offset

1. Click **New Scan** in Cheat Engine
2. Value Type: **Float**, Scan Type: **Value Between**, range **0.1** to **5.0**
3. Click First Scan
4. Scroll mouse wheel **in** to zoom → **Increased value** → Next Scan
5. Scroll mouse wheel **out** to zoom → **Decreased value** → Next Scan
6. Repeat until you see a result showing `AoE2DE_s.exe+` in the address column
7. That offset is your new `zoomOffset`

---

## Part 4 — Updating the script

Open `AoE2DE-Drag-Scroll.ahk` in any text editor and update these lines near the top:

```
baseOffset    := 0xYOUR_NEW_BASE_OFFSET
cameraXOffset := 0xYOUR_NEW_X_OFFSET
cameraYOffset := 0xYOUR_NEW_Y_OFFSET
zoomOffset    := 0xYOUR_NEW_ZOOM_OFFSET
```

Save the file, reload with **Ctrl+Alt+R** and test in game.

---

## Troubleshooting

**Writing 50 in Cheat Engine doesn't move the camera**
That address is read-only — skip it and try the next one. There is only one writable camera address.

**Results drop to zero**
You used an Unchanged value scan which is too aggressive. Start over and only use Increased and Decreased scans.

**Pointer scan returns billions of results**
Make sure you checked Only find static pointers and are using the Compare feature across two game sessions.

**Script works but zoom scaling feels wrong**
The zoom offset is outdated. Redo Part 3.

---

## Current offsets (valid as of AoE2DE Update 169123)

```
baseOffset    := 0x040EC3B8
cameraXOffset := 0x2F0
cameraYOffset := 0x2F4
zoomOffset    := 0x3E90FB8
```

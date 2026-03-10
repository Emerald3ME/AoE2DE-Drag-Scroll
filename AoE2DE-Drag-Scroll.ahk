#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%
SetBatchLines, -1
Process, Priority,, High

DllCall("winmm.dll\timeBeginPeriod", UInt, 1)

; AoE2DE Drag Scroll - run as admin
; Hold the pan key and drag to scroll the camera
; Ctrl+Alt+R to reload
; Last updated March 2026 after patch broke old offsets

PanKey := "MButton"  ; change this to rebind (e.g. "RButton", "XButton1")

; -- Memory offsets - update these if the script breaks after a patch --
baseOffset    := 0x040EC3B8
cameraXOffset := 0x2F0
cameraYOffset := 0x2F4  ; always 4 bytes after X
zoomOffset    := 0x3E90FB8

; -- Feel free to tweak these --
BasePanSpeed        := 0.0341
InvertX             := 1
InvertY             := 1
SmoothingSlow       := 0.5
BaseZoom            := 1.0
HorizontalMultiplier := 0.42
VerticalMultiplier  := 0.86
DeadZonePixels      := 1.5
DragThreshold       := 12    ; pixels of travel before it counts as a drag
ClickTimeThreshold  := 180   ; ms held before it counts as a drag

DidDrag    := false
TotalTravel := 0


GetModuleBase(moduleName)
{
    Process, Exist, %moduleName%
    if (ErrorLevel = 0)
        return 0
    pid := ErrorLevel

    hProcess := DllCall("OpenProcess", "UInt", 0x0410, "Int", false, "UInt", pid, "Ptr")
    if (!hProcess)
        return 0

    VarSetCapacity(hMods, 8000, 0)
    cbNeeded := 0

    result := DllCall("Psapi.dll\EnumProcessModulesEx", "Ptr", hProcess, "Ptr", &hMods, "UInt", 8000, "UInt*", cbNeeded, "UInt", 0x03)
    if (!result)
    {
        DllCall("CloseHandle", "Ptr", hProcess)
        return 0
    }

    firstModule := NumGet(hMods, 0, "Ptr")
    VarSetCapacity(MODULEINFO, 24, 0)
    DllCall("Psapi.dll\GetModuleInformation", "Ptr", hProcess, "Ptr", firstModule, "Ptr", &MODULEINFO, "UInt", 24)

    baseAddress := NumGet(MODULEINFO, 0, "Ptr")
    DllCall("CloseHandle", "Ptr", hProcess)
    return baseAddress
}

GetProcessHandle()
{
    Process, Exist, AoE2DE_s.exe
    if (ErrorLevel = 0)
        return 0
    pid := ErrorLevel
    return DllCall("OpenProcess", "UInt", 0x1F0FFF, "Int", false, "UInt", pid, "Ptr")
}

ReadFloat(hProcess, address)
{
    VarSetCapacity(buffer, 4, 0)
    DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buffer, "UInt", 4, "Ptr", 0)
    return NumGet(buffer, 0, "Float")
}

WriteFloat(hProcess, address, value)
{
    VarSetCapacity(buffer, 4, 0)
    NumPut(value, buffer, 0, "Float")
    DllCall("WriteProcessMemory", "Ptr", hProcess, "Ptr", address, "Ptr", &buffer, "UInt", 4, "Ptr", 0)
}

; walks the pointer chain: baseAddr -> +0x28 -> camera struct
FollowCameraPointer(hProcess, baseAddr)
{
    VarSetCapacity(buffer, 8, 0)
    DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", baseAddr, "Ptr", &buffer, "UInt", 8, "Ptr", 0)
    addr := NumGet(buffer, 0, "Int64") + 0x28

    VarSetCapacity(buffer2, 8, 0)
    DllCall("ReadProcessMemory", "Ptr", hProcess, "Ptr", addr, "Ptr", &buffer2, "UInt", 8, "Ptr", 0)
    return NumGet(buffer2, 0, "Int64")
}

QPCInit()
{
    DllCall("QueryPerformanceFrequency", "Int64*", freq)
    return freq
}

QPCNow()
{
    DllCall("QueryPerformanceCounter", "Int64*", counter)
    return counter
}


#IfWinActive, ahk_exe AoE2DE_s.exe
Hotkey, $%PanKey%, StartPan
return

StartPan:
    DidDrag    := false
    TotalTravel := 0
    PressTime  := A_TickCount

    hProcess := GetProcessHandle()
    if (!hProcess)
        return

    moduleBase := GetModuleBase("AoE2DE_s.exe")
    if (!moduleBase)
        return

    baseAddr    := moduleBase + baseOffset
    cameraBase  := FollowCameraPointer(hProcess, baseAddr)
    cameraXAddr := cameraBase + cameraXOffset
    cameraYAddr := cameraBase + cameraYOffset
    zoomAddr    := moduleBase + zoomOffset

    perfFreq := QPCInit()
    lastTime := QPCNow()

    MouseGetPos, lastX, lastY
    velX := 0
    velY := 0
    lastGoodZoom := 1.0

    While GetKeyState(PanKey, "P")
    {
        if (!DidDrag)
        {
            if (A_TickCount - PressTime >= ClickTimeThreshold)
                DidDrag := true
            else if (TotalTravel >= DragThreshold)
                DidDrag := true
        }

        currentTime := QPCNow()
        deltaTime := (currentTime - lastTime) / perfFreq * 1000
        deltaTime := deltaTime < 1 ? 1 : deltaTime > 50 ? 50 : deltaTime
        timeMultiplier := deltaTime / 16.0
        lastTime := currentTime

        currentZoom := ReadFloat(hProcess, zoomAddr)
        if (currentZoom < 0.1 || currentZoom > 5.0)
            currentZoom := lastGoodZoom
        else
            lastGoodZoom := currentZoom

        PanSpeed := BasePanSpeed * (BaseZoom / currentZoom)

        MouseGetPos, currentX, currentY
        rawDeltaX := currentX - lastX
        rawDeltaY := currentY - lastY

        TotalTravel += Abs(rawDeltaX) + Abs(rawDeltaY)

        if (Abs(rawDeltaX) < DeadZonePixels)
            rawDeltaX := 0
        if (Abs(rawDeltaY) < DeadZonePixels)
            rawDeltaY := 0

        if (rawDeltaX = 0 && rawDeltaY = 0)
        {
            Sleep, 3
            continue
        }

        lastX := currentX
        lastY := currentY

        screenDeltaX := rawDeltaX * PanSpeed * timeMultiplier * HorizontalMultiplier
        screenDeltaY := rawDeltaY * PanSpeed * timeMultiplier * VerticalMultiplier

        ; rotate screen coords into AoE2's isometric space
        isoDeltaX := (screenDeltaX - screenDeltaY) * 0.707
        isoDeltaY := (screenDeltaX + screenDeltaY) * 0.707

        if (InvertX)
            isoDeltaX := -isoDeltaX
        if (InvertY)
            isoDeltaY := -isoDeltaY

        velX := velX * (1 - SmoothingSlow) + isoDeltaX * SmoothingSlow
        velY := velY * (1 - SmoothingSlow) + isoDeltaY * SmoothingSlow

        WriteFloat(hProcess, cameraXAddr, ReadFloat(hProcess, cameraXAddr) + velX)
        WriteFloat(hProcess, cameraYAddr, ReadFloat(hProcess, cameraYAddr) + velY)

        Sleep, 3
    }

    ; pass through a normal click if the user didn't drag
    if (!DidDrag)
        SendInput {MButton}

    DllCall("CloseHandle", "Ptr", hProcess)
return

^!r::Reload

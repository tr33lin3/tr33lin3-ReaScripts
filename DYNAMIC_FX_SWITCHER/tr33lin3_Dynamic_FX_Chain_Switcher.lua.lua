--[[
  Reaper ReaScript (Lua)
  Name: Dynamic FX Chain Switcher (Reposition New FX Window Below Previous Window and Set Track Focus)
  Description:
    Monitors track selection changes. When switching tracks:
      • If the previous track has an FX chain window open, its floating window
        position is captured (using JS_Window_GetRect) along with its height,
        then the window is closed.
      • The last-used FX index for the previous track is saved.
      • When switching to a new track that has FX, the script opens the FX window and
        repositions it so that its top is set relative to the previous window’s top plus
        its height. On Windows, the new window’s top becomes (stored_y + stored_h);
        on macOS it becomes (stored_y – stored_h) because of the different coordinate origin.
      • After repositioning the FX window, the script calls reaper.SetTrackSelected
        to set focus on the current track.
      • Debug messages are printed for troubleshooting.
      
    Requirements:
      - REAPER 6.24 or later with the JS_ReaScriptAPI.
      
    API Functions Used:
      - TrackFX_Show(track, fx, showFlag)
           showFlag=0 → hide FX chain window; showFlag=1 → open FX chain window.
      - JS_Window_Find(title, exact)
           → Finds a window by its title.
      - JS_Window_GetRect(hwnd, leftOut, topOut, rightOut, bottomOut)
           → Retrieves the bounding rectangle of the specified window.
           (NOTE: On Windows/Linux, coordinates are relative to the upper‑left corner;
            on macOS, they’re relative to the bottom‑left. The pixel at (right, bottom) lies just outside the window.)
      - JS_Window_SetPosition(hwnd, left, top, width, height, ZOrderOptional, flagsOptional)
           → Sets a window’s position and size.
      - GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
           → Returns the track number.
      - GetSetMediaTrackInfo_String(track, "P_NAME", ...)
           → Returns the track name.
      - reaper.SetTrackSelected(track, selected)
           → Sets focus to the specified track.
      - reaper.ShowConsoleMsg(msg)
           → Prints debug messages.
--]]

------------------------------------------
-- 1. Pre-flight Check for JS_ReaScriptAPI
------------------------------------------
if not reaper.JS_Window_GetRect then
    reaper.ShowConsoleMsg("JS_ReaScriptAPI is not available. Please install it.\n")
    return
end

------------------------------------------
-- 2. Workflow State Management
------------------------------------------
local config_file_path = reaper.GetResourcePath() .. "/Scripts/Dynamic_FX_Chain_Switcher.cfg"

local function file_exists(file_path)
    local f = io.open(file_path, "r")
    if f then f:close() return true else return false end
end

local function create_config_file()
    local f = io.open(config_file_path, "w")
    if f then
        f:write("current_mode = slow")
        f:close()
    else
        reaper.ShowMessageBox("Could not create config file: " .. config_file_path, "Error", 0)
    end
end

local function read_workflow_status()
    if not file_exists(config_file_path) then create_config_file() end
    local f = io.open(config_file_path, "r")
    local mode = f:read("*line")
    f:close()
    return mode
end

local function write_workflow_status(mode)
    local f = io.open(config_file_path, "w")
    if f then
        f:write(mode)
        f:close()
    else
        reaper.ShowMessageBox("Could not write to config file: " .. config_file_path, "Error", 0)
    end
end

local function toggle_button_on()
    local _, _, section_ID, cmd_ID = reaper.get_action_context()
    reaper.SetToggleCommandState(section_ID, cmd_ID, 1)
    reaper.RefreshToolbar2(section_ID, cmd_ID)
end

local function toggle_button_off()
    local _, _, section_ID, cmd_ID = reaper.get_action_context()
    reaper.SetToggleCommandState(section_ID, cmd_ID, 0)
    reaper.RefreshToolbar2(section_ID, cmd_ID)
end

local function init()
    write_workflow_status("current_mode = fast")
    toggle_button_on()
    -- reaper.ShowConsoleMsg("Dynamic FX Chain Switcher started\n")
end

local function exit_func()
    write_workflow_status("current_mode = slow")
    toggle_button_off()
    -- reaper.ShowConsoleMsg("Dynamic FX Chain Switcher stopped\n")
end

------------------------------------------
-- 3. Global Variables for FX Chain State
------------------------------------------
local prevTrack = nil                        -- Previously selected track.
local stored_x, stored_y, stored_h = nil, nil, nil  -- Stored left, top, and height from previous FX window.
local trackFxState = {}                      -- Stores last-used FX index per track (keyed by track GUID).

------------------------------------------
-- 4. Helper Function: Get the Index of the Open FX Window
------------------------------------------
local function getOpenFX(track)
    local fxCount = reaper.TrackFX_GetCount(track)
    for i = 0, fxCount - 1 do
        if reaper.TrackFX_GetOpen(track, i) then
            return i
        end
    end
    return nil
end

------------------------------------------
-- 5. Function: Retrieve and Move the New FX Window
------------------------------------------
local function TryMoveNewFXWindow(currentTrack, fxIndex, attempt)
    attempt = attempt or 0
    -- Build the search title based on track number and name.
    local trackNumber = math.floor(reaper.GetMediaTrackInfo_Value(currentTrack, "IP_TRACKNUMBER") or 0)
    local retval, track_name = reaper.GetSetMediaTrackInfo_String(currentTrack, "P_NAME", "", false)
    local searchStr = string.format('FX: Track %d "%s"', trackNumber, track_name or "")
    -- reaper.ShowConsoleMsg("Attempt " .. (attempt+1) .. ": Searching for window with title: " .. searchStr .. "\n")
    
    local hwnd_new = reaper.JS_Window_Find(searchStr, true)
    if hwnd_new then
        if stored_x and stored_y and stored_h then
            -- Get the new window's current dimensions.
            local ret, lx, ty, rx, by = reaper.JS_Window_GetRect(hwnd_new)
            if ret then
                local width = rx - lx
                local height = by - ty
                -- Determine OS to compute new top:
                local os = reaper.GetOS()
                local new_top = nil
                if string.find(os, "OSX") then
                    -- On macOS, coordinates are measured from the bottom left,
                    -- so to stack "below" the previous window, subtract its height.
                    new_top = stored_y - stored_h
                else
                    -- On Windows/Linux, coordinates are from the upper left,
                    -- so add the previous window's height.
                    new_top = stored_y + stored_h
                end
                
                reaper.JS_Window_SetPosition(hwnd_new, stored_x, new_top, width, height)
                -- reaper.ShowConsoleMsg(string.format("Moved new FX window to: left=%d, top=%d (prev top=%d, prev height=%d) with width=%d and height=%d\n",
                --    stored_x, new_top, stored_y, stored_h, width, height))
            else
                -- reaper.ShowConsoleMsg("JS_Window_GetRect did not return valid values for new FX window.\n")
            end
        else
            -- reaper.ShowConsoleMsg("No stored position (or height) available to move new FX window.\n")
        end
    else
        -- reaper.ShowConsoleMsg("New FX window not found using JS_Window_Find.\n")
    end
end

------------------------------------------
-- 6. Main Loop: Monitor Track Selection and Manage FX Windows
------------------------------------------
function main()
    local currentTrack = reaper.GetSelectedTrack(0, 0)  -- Get the first selected track.
    
    if currentTrack ~= prevTrack then
        -- reaper.ShowConsoleMsg("Track selection changed.\n")
        
        -- When switching away from the previous track:
        if prevTrack then
            local prevGUID = reaper.GetTrackGUID(prevTrack)
            local prev_fx_index = getOpenFX(prevTrack)
            if prev_fx_index then
                -- Build the search title for the previous track's FX window.
                local trackNumber = math.floor(reaper.GetMediaTrackInfo_Value(prevTrack, "IP_TRACKNUMBER") or 0)
                local retval, track_name = reaper.GetSetMediaTrackInfo_String(prevTrack, "P_NAME", "", false)
                local searchStr = string.format('FX: Track %d "%s"', trackNumber, track_name or "")
                -- reaper.ShowConsoleMsg("Searching for previous window with title: " .. searchStr .. "\n")
                
                local hwnd_prev = reaper.JS_Window_Find(searchStr, true)
                if hwnd_prev then
                    local ret, l, t, r, b = reaper.JS_Window_GetRect(hwnd_prev)
                    if ret and type(l) == "number" and type(t) == "number" then
                        stored_x = l
                        stored_y = t
                        stored_h = b - t
                        -- reaper.ShowConsoleMsg(string.format("Captured previous FX window position: left=%d, top=%d, height=%d\n", l, t, stored_h))
                    else
                        -- reaper.ShowConsoleMsg("JS_Window_GetRect did not return valid numeric values.\n")
                    end
                else
                    -- reaper.ShowConsoleMsg("No floating FX window found on previous track using JS_Window_Find.\n")
                end
                trackFxState[prevGUID] = prev_fx_index
                -- Close the previous track's FX window.
                reaper.TrackFX_Show(prevTrack, prev_fx_index, 0)
                -- reaper.ShowConsoleMsg("Closed previous track FX window.\n")
            else
                -- reaper.ShowConsoleMsg("No open FX window on previous track.\n")
            end
        end
        
        prevTrack = currentTrack  -- Update previous track.
        
        if currentTrack then
            local guid = reaper.GetTrackGUID(currentTrack)
            local fxCount = reaper.TrackFX_GetCount(currentTrack)
            if fxCount > 0 then
                local openIndex = getOpenFX(currentTrack)
                local fxIndex = openIndex or trackFxState[guid] or 0
                reaper.TrackFX_Show(currentTrack, fxIndex, 1)
                -- reaper.ShowConsoleMsg("Opened new track FX window.\n")
                TryMoveNewFXWindow(currentTrack, fxIndex, 0)
                -- Set focus to main window.
                main_hwnd = reaper.GetMainHwnd()
                reaper.JS_Window_SetFocus(main_hwnd)
            else
                -- reaper.ShowConsoleMsg("No FX on current track.\n")
            end
        end
    end
    
    reaper.defer(main)
end

------------------------------------------
-- 7. Script Startup and Cleanup Registration
------------------------------------------
init()
main()
reaper.atexit(exit_func)

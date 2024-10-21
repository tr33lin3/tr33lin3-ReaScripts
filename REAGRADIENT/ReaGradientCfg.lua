--[[
    ReaGradientCfg.lua
    Version: 1.0.0
    Author: Tr33lin3
    Contact: treeline.audio@gmail.com
    License: [License Type]

    Description:
    This script provides a user interface for the REAPER digital audio workstation to define and apply gradient color schemes to tracks and their children based on user-defined rules.

    Features:
    - Create, edit, and delete gradient color rules.
    - Apply gradients to tracks based on keywords and match types.
    - Save and load configurations for different projects or workflows.
    - Drag and drop color assignment for convenience and speed.
    - Move rules up and down in the priority list to refine gradient application.

    How to Use:
    1. Launch the script from the Actions menu in REAPER.
    2. Define your gradient rules, specifying keywords (each rule can have several keywords separated by comma), start/end colors, and match type.
    3. Configuration is automatically saved and it always loads the last configuration used.
    4. Apply the gradients to your tracks by clicking the "Apply Gradients" button.
    5. Adjust your rules and reapply as needed for your project.
    6. MAX_FACTOR_STEP variable in this script is limiting the maximum difference between two consecutive colors. You can adjust to taste.
    7. If you don't need to to edit any rules you can directly apply the last loaded rules with ReaGradient.lua

    Requirements:
    - SWS/S&M extension
    - This script uses the `reaImGui` library for its graphical user interface

    Installation:
    Place the ReaGradientCfg.lua script in the REAPER Scripts directory, typically found at:
    - Windows: %APPDATA%\REAPER\Scripts\
    - macOS: ~/Library/Application Support/REAPER/Scripts/

    Config files with name ReaGradient_'config name'.cfg should be placed here:
    - Windows: %APPDATA%\REAPER\
    - macOS: ~/Library/Application Support/REAPER/


    Make sure you have the required REAPER version and extensions installed. Load the script from the Actions menu in REAPER to start organizing your tracks visually with gradients.

    Changelog:
    - v1.0.0: Initial release.
]]

-- The script begins here...



-- Global variable for the maximum factor step
MAX_FACTOR_STEP = 0.3 -- Adjust as necessary

-- Debug function to print the contents of a table
function printTable(t, indent)
    indent = indent or ""
    for k, v in pairs(t) do
        if type(v) == "table" then
            debug_print(indent .. tostring(k) .. ":\n")
            printTable(v, indent .. "  ")
        else
            debug_print(indent .. tostring(k) .. ": " .. tostring(v) .. "\n")
        end
    end
end

-- Debug print function for REAPER
function debug_print(message)
    -- Uncomment the following line to enable console messages
     reaper.ShowConsoleMsg(message .. "\n")
end

-- Interpolate between two colors
function interpolate_color(start_color, end_color, factor)
    local r = start_color[1] + (end_color[1] - start_color[1]) * factor
    local g = start_color[2] + (end_color[2] - start_color[2]) * factor
    local b = start_color[3] + (end_color[3] - start_color[3]) * factor
    -- Ensure RGB values are integers
    r = math.floor(r + 0.5)
    g = math.floor(g + 0.5)
    b = math.floor(b + 0.5)
    return r, g, b
end

-- Apply a color to a track in REAPER
function color_track(track, r, g, b)
    local color = reaper.ColorToNative(r, g, b) | 0x1000000
    reaper.SetMediaTrackInfo_Value(track, "I_CUSTOMCOLOR", color)
end

-- This function gets all tracks under a specified folder track in REAPER.
function get_all_tracks_under_folder(folder_track)
    -- Validate if the folder track is a valid MediaTrack
    if not reaper.ValidatePtr(folder_track, "MediaTrack*") then
        return {}
    end

    -- Get the depth of the folder track to understand the hierarchy
    local folder_track_depth = reaper.GetMediaTrackInfo_Value(folder_track, "I_FOLDERDEPTH")
    local folder_track_number = reaper.GetMediaTrackInfo_Value(folder_track, "IP_TRACKNUMBER") -1
    local num_tracks = reaper.CountTracks(0)
    local all_tracks = {}
    local current_relative_depth = 0


    -- Include the folder track itself
    table.insert(all_tracks, folder_track)

    -- Start checking from the track after the folder
    if folder_track_depth == 1 then

        -- Start checking from the track after the folder
        for i = folder_track_number + 1, num_tracks do
            local track = reaper.GetTrack(0, i)
            local track_depth_change = reaper.GetMediaTrackInfo_Value(track, "I_FOLDERDEPTH")

            -- Update the relative depth
            current_relative_depth = current_relative_depth + track_depth_change

            if current_relative_depth < 0 then
                table.insert(all_tracks, track)
                -- We've reached the end of the folder's children
                break
            else
                -- The track is a child of the folder
                table.insert(all_tracks, track)
            end
        end
    end

    return all_tracks
end




function apply_color_gradient(folder_track, start_color, end_color)
    local all_tracks = get_all_tracks_under_folder(folder_track)
    local num_tracks = #all_tracks

    if num_tracks < 1 then
        return -- No tracks to apply gradient to
    end

    -- Ensure colors are tables with three elements
    if not (type(start_color) == "table" and type(end_color) == "table") or
       not (#start_color == 3 and #end_color == 3) then
        return -- Invalid color format
    end

    local previous_factor = 0
    for i, track in ipairs(all_tracks) do
        -- Calculate the factor for the current track
        local factor = (num_tracks > 1) and ((i - 1) / (num_tracks - 1)) or 0

        -- Limit the difference between this factor and the previous factor
        factor = math.min(factor, previous_factor + MAX_FACTOR_STEP)
        local r, g, b = interpolate_color(start_color, end_color, factor)
        color_track(track, r, g, b)

        previous_factor = factor  -- Update the previous_factor
    end
end

-- The interpolate_color function and color_track function should be defined as well.



-- Helper function to trim strings
function trim_string(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end


-- Helper function to split strings
function split_string(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
        table.insert(t, str)
    end
    return t
end


-- Function to find all tracks that match a given keyword
function find_tracks_by_keyword(keyword, exact_match)
    local num_tracks = reaper.CountTracks(0)
    local matching_tracks = {}
    local lower_keyword = string.lower(keyword)  -- Convert the keyword to lowercase

    for i = 0, num_tracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, track_name_current = reaper.GetSetMediaTrackInfo_String(track, "P_NAME", "", false)
        local lower_track_name = string.lower(track_name_current)  -- Convert the track name to lowercase

        if (exact_match and lower_track_name == lower_keyword) or
           (not exact_match and string.find(lower_track_name, lower_keyword, 1, true)) then
            table.insert(matching_tracks, track)
        end
    end
    return matching_tracks
end


-- Function to apply gradients based on the rules
function apply_gradients_based_on_rules()
    -- Determine the operating system
    local isWindows = (package.config:sub(1,1) == '\\') or (os.getenv("OS") ~= nil and os.getenv("OS"):match("Windows"))

    local loaded_rules = loadRulesFromFile(loadLastConfig())
    if not loaded_rules then
        return
    end
    reaper.Undo_BeginBlock()

    for _, rule in ipairs(loaded_rules) do
        local start_r, start_g, start_b = reaper.ColorFromNative(rule.start_color)
        local end_r, end_g, end_b = reaper.ColorFromNative(rule.end_color)

        -- Adjust the color order based on the operating system
        if isWindows then
            start_r, start_b = start_b, start_r
            end_r, end_b = end_b, end_r
        end

        -- Split keywords and trim each one
        local keywords = split_string(rule.keyword, ',')
        for _, keyword in ipairs(keywords) do
            keyword = trim_string(keyword)

            -- Find all tracks that match the keyword
            local matching_tracks = find_tracks_by_keyword(keyword, rule.exact_match)
            if matching_tracks then
                -- Apply gradient to each matching track
                for _, folder_track in ipairs(matching_tracks) do
                    apply_color_gradient(folder_track, {start_r, start_g, start_b}, {end_r, end_g, end_b})
                end
            end
        end
    end

    reaper.Undo_EndBlock("ReaGradient", -1)
end





 --Example usage (You will need to adapt this part to select the actual folder track and colors)
 --Assuming folder_track is a valid track object, and start_color and end_color are {r, g, b} tuples
 --local folder_track = reaper.GetTrack(0, 0) -- Get the second track in the project (index is 0-based)
 --local start_color = {255, 0, 0} -- Red
 --local end_color = {0, 0, 255} -- Blue
 --apply_color_gradient(folder_track, start_color, end_color)

local current_config_name = "Default Config"
local rules = {}

-- Function to save current rules to the selected configuration file
function saveCurrentConfig()
    -- Assuming saveRulesToFile handles everything including file path construction
    local success, errorMessage = saveRulesToFile(current_config_name, rules)
    if not success then
    else
        saveLastConfig(current_config_name)  -- Ensure the last config name is stored after saving successfully
    end
end



-- Function to prompt user for a new config name and add to items
function createNewConfig()
    -- Debug to ensure that 'items' is not nil
    if items == nil then
        items = {"Default Config"}
    end

    -- Prompt the user for a new configuration name
    local ret, new_config_name = reaper.GetUserInputs("New Config", 1, "Enter Config Name:", "")

    -- Handle case where user cancels or provides empty input
    if not ret or new_config_name == "" then
        new_config_name = "Config " .. (#items + 1)
    end

    -- Set the current config name to the new one
    current_config_name = new_config_name

    -- Add the new config to the items list
    table.insert(items, new_config_name)

    -- Start with an empty or default rules list
    rules = {}

    -- Save the new configuration
    saveCurrentConfig()

    -- Save the current config name in the ext state
    reaper.SetExtState("ReaGradient", "CurrentConfig", current_config_name, true)

    -- Load the new configuration
    loadConfig(current_config_name)

    -- Update the items list with the latest configurations
    items = getConfigFiles()
end



-- Function to delete a configuration
function deleteConfig(configName)
    -- Debug print to check if configName is nil at the start
    if not configName then
        return
    end

    -- Rest of the delete function code...
    local configFilePath = getConfigFilePath(configName)

    -- Perform the file deletion
    local result = os.remove(configFilePath)

    -- Check the result and print an appropriate message
    if result then
        os.execute("sleep " .. tonumber(0.5))  -- Delay for 1 second
        items = getConfigFiles()  -- Refresh the items list after deletion

        if #items > 0 then
            -- Default to the first configuration in the list or another preferred method
            current_config_name = items[1]
        else
            -- Handle the case where there are no more configurations left
            current_config_name = nil
            -- Possibly load a default state or alert the user
            -- ...
        end
    end

    -- Load the configuration that is now current, or handle the case where there are none
    if current_config_name then
        loadConfig(current_config_name)
    end
end

-- Function to get the full path for a given configuration name
function getConfigFilePath(configName)
    local basePath = reaper.GetResourcePath() -- Get the base resource path for REAPER
    return basePath .. "/ReaGradient_" .. configName .. ".cfg"
end

function getConfigFiles()
    local resource_path = reaper.GetResourcePath() -- Get the path to REAPER's resource directory
    local config_files = {} -- This will hold the paths to the config files
    local i = 0
    repeat
        local file = reaper.EnumerateFiles(resource_path, i)
        if file and file:match("^ReaGradient_(.+)%.cfg$") then -- Match files starting with "ReaGradient_" and ending with ".cfg"
            table.insert(config_files, file:sub(13, -5)) -- Extract the config name and insert into the table
        end
        i = i + 1
    until not file

    return config_files
end

function loadConfig(configName)
    if configName == nil then
        return
    end
    -- Attempt to load rules from the file
    local loadedRules = loadRulesFromFile(configName)
    if loadedRules then
        rules = loadedRules
    else
        rules = {} -- If no rules are found, start with an empty rules list
    end
    saveLastConfig(configName)  -- Save the current config as the last used one
end



-- Function to save the last selected configuration
function saveLastConfig(selectedConfigName)
    local resourcePath = reaper.GetResourcePath()
    local configFile = resourcePath .. "/ReaGradient.cfg"
    local success, message = saveConfigToFile({ lastConfig = selectedConfigName }, configFile)
    if not success then
    end
end


-- Function to load the last selected configuration
function loadLastConfig()
    local resourcePath = reaper.GetResourcePath()
    local configFile = resourcePath .. "/ReaGradient.cfg"
    local status, config = pcall(loadTableFromFile, configFile)
    if status and type(config) == 'table' then
        return config.lastConfig
    else
        return nil -- or a default config name if you prefer
    end
end

-- Function to load a table from a file
function loadTableFromFile(filename)
    local file = io.open(filename, "r")
    if file then
        local content = file:read("*a")
        file:close()
        return stringToTable(content)
    else
        return false, "Could not open file for reading."
    end
end



-- Function to save rules to a file
function saveRulesToFile(configName, rules)
    local resourcePath = reaper.GetResourcePath()
    local configFile = resourcePath .. "/ReaGradient_" .. configName .. ".cfg"

    -- Serialize the rules using the serializeTable function
    local rulesString = serializeTable(rules)

    -- Write the serialized string to a config file
    local file, err = io.open(configFile, "w")
    if not file then
        return false
    end

    file:write(rulesString)
    file:close()

    return true
end



-- Function to load rules from a file
function loadRulesFromFile(configName)
    if not configName then
        return nil
    end

    local resourcePath = reaper.GetResourcePath()
    local configFile = resourcePath .. "/ReaGradient_" .. configName .. ".cfg"

    local file, err = io.open(configFile, "r")
    if not file then
        return nil
    end

    local rulesString = file:read("*a")
    file:close()

    -- Deserialize the string back to a table
    local rulesTable = deserializeTable(rulesString)

    return rulesTable
end


-- Function to serialize a table into a string
function configToString(tbl)
    local result = "{\n"
    for k, v in pairs(tbl) do
        local key = tostring(k)
        local value
        if type(v) == "table" then
            value = configToString(v) -- Handle table within table
        else
            value = (type(v) == "string" and string.format("%q", v)) or tostring(v)
        end
        result = result .. "  [" .. string.format("%q", key) .. "] = " .. value .. ",\n"
    end
    result = result .. "}\n"
    return result
end

-- Function to deserialize a string into a table
function stringToTable(str)
    local f = load("return " .. str)
    if f then
        local status, result = pcall(f)
        if status then
            return result
        end
    end
    return nil
end

-- Function to save a table to a file
function saveConfigToFile(tbl, filename)
    local str = configToString(tbl)
    local file = io.open(filename, "w")
    if file then
        file:write(str)
        file:close()
        return true
    else
        return false, "Could not open file for writing."
    end
end


function deserializeTable(str)
    local f, err = load("return " .. str)
    if f then
        return f()
    else
        error("Failed to deserialize string: " .. (err or "unknown error"))
    end
end

function serializeTable(t)
    local serializedTable = "{\n"
    for i, v in ipairs(t) do
        serializedTable = serializedTable .. "  {\n"
        for key, value in pairs(v) do
            if type(value) == "string" then
                serializedTable = serializedTable .. string.format("    %s = %q,\n", key, value)
            else
                serializedTable = serializedTable .. string.format("    %s = %s,\n", key, tostring(value))
            end
        end
        serializedTable = serializedTable .. "  },\n"
    end
    serializedTable = serializedTable .. "}"
    return serializedTable
end



-- Variables for widget states
local keywords = ''
local start_color = reaper.ColorToNative(0, 0, 0) -- Red in RGB as default, packed into integer
local end_color = reaper.ColorToNative(255, 255, 255) -- Blue in RGB as default, packed into integer
local exact_match = false

-- Define the window title and size
local window_title = "ReaGradient"
local window_flags = reaper.ImGui_WindowFlags_NoResize()



-- Function to load the last used configuration at the start
-- Function to initialize the configuration
local function initConfig()
    local lastConfigName = loadLastConfig()
    if lastConfigName then
        current_config_name = lastConfigName
    end
    loadConfig(current_config_name)
end
initConfig()





-- Function to move a rule in the table
local function moveRule(rowIndex, direction)
    local new_index = rowIndex + direction
    -- Check if the new position is within the bounds of the rules list
    if new_index >= 1 and new_index <= #rules then
        rules[rowIndex], rules[new_index] = rules[new_index], rules[rowIndex]
    end
    saveCurrentConfig()
end

-- Define the function to handle adding a rule
local function addRule()
    local new_rule = {
        keyword = keywords,
        start_color = start_color,
        end_color = end_color,
        exact_match = exact_match
    }

    -- Add new rule to the rules table
    table.insert(rules, new_rule)

    saveCurrentConfig()

    -- Clear fields after adding (optional)
    keywords = ''
    start_color = reaper.ColorToNative(0, 0, 0)
    end_color = reaper.ColorToNative(255, 255, 255)
    exact_match = false
end

function tableContains(table, element)
    for _, value in pairs(table) do
        if value == element then
            return true
        end
    end
    return false
end


-- Create a context for ImGui
local ctx = reaper.ImGui_CreateContext(window_title)



-- Main loop to draw the window
-- Apply a custom style including colors and button rounding
local function applyCustomStyle()
    -- Dark mode color scheme
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Text(), 0xFFFFFFC8) -- Light grey text
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextDisabled(), 0x555555FF) -- Disabled text
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_WindowBg(), 0x181818FF) -- Very dark background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ChildBg(), 0x181818FF) -- Very dark background for child windows/frames
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_PopupBg(), 0x222222FF) -- Dark pop-up background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Border(), 0x292929FF) -- Border color
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_BorderShadow(), 0x00000000) -- Invisible border shadow
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBg(), 0x2D2D2DFF) -- Dark frame background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgHovered(), 0x363636FF) -- Dark frame background when hovered
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_FrameBgActive(), 0x424242FF) -- Dark frame background when active
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBg(), 0x181818FF) -- Title background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgActive(), 0x181818FF) -- Title background when active
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TitleBgCollapsed(), 0x181818FF) -- Title background when collapsed
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_MenuBarBg(), 0x222222FF) -- Menu bar background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarBg(), 0x181818FF) -- Scrollbar background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrab(), 0x2D2D2DFF) -- Scrollbar grab
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabHovered(), 0x363636FF) -- Scrollbar grab hovered
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ScrollbarGrabActive(), 0x424242FF) -- Scrollbar grab active
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_CheckMark(), 0x4286f4FF) -- Checkmark color
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrab(), 0x2D2D2DFF) -- Slider grab
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SliderGrabActive(), 0x4286f4FF) -- Slider grab active
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Button(), 0x333333FF) -- Button background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonHovered(), 0x444444FF) -- Button background when hovered
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ButtonActive(), 0x555555FF) -- Button background when active
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Header(), 0x333333FF) -- Header background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderHovered(), 0x444444FF) -- Header background when hovered
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_HeaderActive(), 0x555555FF) -- Header background when active
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Separator(), 0x292929FF) -- Separator
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorHovered(), 0x4286f4FF) -- Separator hovered
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_SeparatorActive(), 0x4286f4FF) -- Separator active
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGrip(), 0x333333FF) -- Resize grip
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripHovered(), 0x4286f4FF) -- Resize grip hovered
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ResizeGripActive(), 0x4286f4FF) -- Resize grip active
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_Tab(), 0x333333FF) -- Tab
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabHovered(), 0x4286f4FF) -- Tab hovered
--     reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabActive(), 0x2D2D2DFF) -- Tab active
--     reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocused(), 0x333333FF) -- Tab unfocused
--     reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TabUnfocusedActive(), 0x2D2D2DFF) -- Tab unfocused active
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DockingPreview(), 0x4286f4FF) -- Docking preview
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_TextSelectedBg(), 0x4286f4FF) -- Text selected background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_DragDropTarget(), 0x4286f4FF) -- Drag and drop target
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavHighlight(), 0x4286f4FF) -- Nav highlight color
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavWindowingHighlight(), 0x4286f4FF) -- Nav windowing highlight
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_NavWindowingDimBg(), 0x4286f4FF) -- Nav windowing dim background
    reaper.ImGui_PushStyleColor(ctx, reaper.ImGui_Col_ModalWindowDimBg(), 0x29292980) -- Modal window dim background

    -- Example style var for button rounding
    reaper.ImGui_PushStyleVar(ctx, reaper.ImGui_StyleVar_FrameRounding(), 4.0)

end

-- Revert style changes
local function revertCustomStyle()
    reaper.ImGui_PopStyleVar(ctx)
    reaper.ImGui_PopStyleColor(ctx, 42) -- Number of colors we've pushed
end

-- Main loop to draw the window
local function loop()
    -- Start the window with the ImGui context
    local visible, open = reaper.ImGui_Begin(ctx, window_title, true)

    if visible then
        -- Apply custom style
        applyCustomStyle()

        -- Define common style variables
        local item_spacing = reaper.ImGui_GetStyleVar(ctx, reaper.ImGui_StyleVar_ItemSpacing())
        local button_width = 160
        local input_width = 400
        local checkbox_width = reaper.ImGui_CalcTextSize(ctx, 'Exact Match') + item_spacing  -- Calculate the width based on text size


        -- Text label for configuration
        reaper.ImGui_Text(ctx, "Select a configuration:")
        reaper.ImGui_SameLine(ctx)

        -- Combo box
        -- Set next item width to align with other items
        reaper.ImGui_SetNextItemWidth(ctx, 722)

        items = getConfigFiles()

        -- When drawing the combo box, compare each item's name to current_config_name to determine if it's selected
        if reaper.ImGui_BeginCombo(ctx, '##ConfigCombo', current_config_name) then
            for i, item in ipairs(items) do
                local selected = (item == current_config_name)
                if reaper.ImGui_Selectable(ctx, item, selected) then
                    current_config_name = item -- Set the current config name to the selected one
                    -- Load the selected configuration
                    loadConfig(current_config_name)
                end
                if selected then
                    reaper.ImGui_SetItemDefaultFocus(ctx)
                end
            end
            reaper.ImGui_EndCombo(ctx)
        end


        -- New Config button
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'New Config', button_width) then
            -- Handle creating a new configuration
             createNewConfig()
        end

        -- Delete Config button
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Delete Config', button_width) then
            -- Ensure we have a config name to delete
            if items and current_config_name then
                local configNameToDelete = current_config_name
                deleteConfig(configNameToDelete)
            end
        end

        reaper.ImGui_Dummy(ctx, 0, 10)

        -- Keywords label and input
        reaper.ImGui_Text(ctx, "Keywords:")
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, input_width)
        local changed
        changed, keywords = reaper.ImGui_InputText(ctx, '##keywords', keywords, 128)

        -- Start Color label and button
        -- Define the size of the standalone color buttons
        local button_size_x = 150-- The width of the button, adjust as needed
        local button_size_y = 20  -- The height of the button, adjust as needed

        -- Start Color label and button
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, "Start Color:")
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_ColorButton(ctx, 'Start Color##startcolorbtn', start_color, reaper.ImGui_ColorEditFlags_NoAlpha(), button_size_x, button_size_y) then
            -- Open the popup only when the button is pressed
            reaper.ImGui_OpenPopup(ctx, 'Start Color Picker##startcolor')
        end

        -- Drag and drop target for Start Color
        if reaper.ImGui_BeginDragDropTarget(ctx) then
            local received, payload_color = reaper.ImGui_AcceptDragDropPayloadRGB(ctx)
            if received then
                start_color = payload_color
                saveCurrentConfig()
            end
            reaper.ImGui_EndDragDropTarget(ctx)
        end

        -- Popup for start color picker
        if reaper.ImGui_BeginPopup(ctx, 'Start Color Picker##startcolor') then
            local changed
            changed, start_color = reaper.ImGui_ColorPicker4(ctx, '##startcolorpicker', start_color, reaper.ImGui_ColorEditFlags_NoAlpha())
            if changed then
                saveCurrentConfig()
            end
            reaper.ImGui_EndPopup(ctx)
        end

        -- End Color label and button
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_Text(ctx, "End Color:")
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_ColorButton(ctx, 'End Color##endcolorbtn', end_color, reaper.ImGui_ColorEditFlags_NoAlpha(), button_size_x, button_size_y) then
            -- Open the popup only when the button is pressed
            reaper.ImGui_OpenPopup(ctx, 'End Color Picker##endcolor')
        end

        -- Drag and drop target for End Color
        if reaper.ImGui_BeginDragDropTarget(ctx) then
            local received, payload_color = reaper.ImGui_AcceptDragDropPayloadRGB(ctx)
            if received then
                end_color = payload_color
                saveCurrentConfig()
            end
            reaper.ImGui_EndDragDropTarget(ctx)
        end

        -- Popup for end color picker
        if reaper.ImGui_BeginPopup(ctx, 'End Color Picker##endcolor') then
            local changed
            changed, end_color = reaper.ImGui_ColorPicker4(ctx, '##endcolorpicker', end_color, reaper.ImGui_ColorEditFlags_NoAlpha())
            if changed then
                saveCurrentConfig()
            end
            reaper.ImGui_EndPopup(ctx)
        end




        -- Exact Match checkbox
        reaper.ImGui_SameLine(ctx)
        reaper.ImGui_SetNextItemWidth(ctx, checkbox_width)
        changed, exact_match = reaper.ImGui_Checkbox(ctx, 'Exact Match##exactmatch', exact_match)

        -- Add/Update Rule button
        reaper.ImGui_SameLine(ctx)
        if reaper.ImGui_Button(ctx, 'Add Rule##addrule', button_width) then
            addRule()
            -- Handle Add/Update Rule
        end
        reaper.ImGui_Dummy(ctx, 0, 10)

        -- Table for rules
        local table_scrollable_height = 500  -- Adjust the height as needed
        if reaper.ImGui_BeginChild(ctx, '##TableScrollable', -1, table_scrollable_height, 1) then
            -- Table for rules
            local table_flags = reaper.ImGui_TableFlags_Reorderable()
                                | reaper.ImGui_TableFlags_Hideable()
                                | reaper.ImGui_TableFlags_RowBg()
                                | reaper.ImGui_TableFlags_ScrollX()
                                | reaper.ImGui_TableFlags_ScrollY()

            if reaper.ImGui_BeginTable(ctx, "##rulesTable", 6, table_flags) then
                -- Setup columns: Keyword, Start Color, End Color, Exact Match, Move
                reaper.ImGui_TableSetupColumn(ctx, "Keyword", reaper.ImGui_TableColumnFlags_WidthStretch(), -1, MyItemColumnID_Keyword)
                reaper.ImGui_TableSetupColumn(ctx, "Start Color", reaper.ImGui_TableColumnFlags_WidthFixed(), 200, MyItemColumnID_StartColor)
                reaper.ImGui_TableSetupColumn(ctx, "End Color", reaper.ImGui_TableColumnFlags_WidthFixed(), 200, MyItemColumnID_EndColor)
                reaper.ImGui_TableSetupColumn(ctx, "Exact Match", reaper.ImGui_TableColumnFlags_WidthFixed(), 100, MyItemColumnID_ExactMatch)
                reaper.ImGui_TableSetupColumn(ctx, "Move", reaper.ImGui_TableColumnFlags_WidthFixed(), 100, MyItemColumnID_Move)  -- Change the ID to MyItemColumnID_Move or another unique ID
                reaper.ImGui_TableSetupColumn(ctx, "Delete", reaper.ImGui_TableColumnFlags_WidthFixed(), 100, MyItemColumnID_Delete)
                -- Center the column header as well
                reaper.ImGui_SetNextItemWidth(ctx, -1)  -- Use -1 to center align
                reaper.ImGui_TableSetupScrollFreeze(ctx, 0, 1)  -- This freezes the header row so it doesn't scroll
                reaper.ImGui_TableHeadersRow(ctx)

                -- Iterate over the rules to populate the table
                for i, rule in ipairs(rules) do
                    reaper.ImGui_PushID(ctx, i)
                    reaper.ImGui_TableNextRow(ctx)

                    -- Make the entire row selectable, and highlight if it's the selected row.
                    if reaper.ImGui_Selectable(ctx, '##row'..i, selected_row == i, reaper.ImGui_SelectableFlags_SpanAllColumns()) then
                        selected_row = i -- This row is now selected
                    end

                    for j = 1, 6 do
                        reaper.ImGui_TableSetColumnIndex(ctx, j - 1)
                        if j == 1 then -- Keyword column
                            -- Make keyword editable
                            local changed, newKeyword = reaper.ImGui_InputText(ctx, '##keyword'..i, rule.keyword, 256)
                            if changed then
                                rule.keyword = newKeyword
                                saveCurrentConfig()
                            end
                        elseif j == 2 then -- Start Color
                            -- Use a color button for start color
                            local button_size = 1000 -- Set the button size
                            if reaper.ImGui_ColorButton(ctx, '##startColor'..i, rule.start_color, reaper.ImGui_ColorEditFlags_NoAlpha(), button_size) then
                                -- Open popup for start color picker
                                reaper.ImGui_OpenPopup(ctx, 'Start Color Picker##'..i)
                            end

                            -- Drag and drop target for start color
                            if reaper.ImGui_BeginDragDropTarget(ctx) then
                                local rv, drop_color = reaper.ImGui_AcceptDragDropPayloadRGB(ctx)
                                if rv then
                                    rule.start_color = drop_color
                                    saveCurrentConfig()
                                end
                                reaper.ImGui_EndDragDropTarget(ctx)
                            end

                            -- Popup for start color picker
                            if reaper.ImGui_BeginPopup(ctx, 'Start Color Picker##'..i) then
                                local changed
                                changed, rule.start_color = reaper.ImGui_ColorPicker4(ctx, '##startcolorpicker'..i, rule.start_color, reaper.ImGui_ColorEditFlags_NoAlpha())
                                if changed then
                                    saveCurrentConfig()
                                end
                                reaper.ImGui_EndPopup(ctx)
                            end
                        elseif j == 3 then -- End Color
                            -- Use a color button for end color
                            local button_size = 1000 -- Set the button size
                            if reaper.ImGui_ColorButton(ctx, '##endColor'..i, rule.end_color, reaper.ImGui_ColorEditFlags_NoAlpha(), button_size) then
                                -- Open popup for end color picker
                                reaper.ImGui_OpenPopup(ctx, 'End Color Picker##'..i)
                            end

                            -- Drag and drop target for end color
                            if reaper.ImGui_BeginDragDropTarget(ctx) then
                                local rv, drop_color = reaper.ImGui_AcceptDragDropPayloadRGB(ctx)
                                if rv then
                                    rule.end_color = drop_color
                                    saveCurrentConfig()
                                end
                                reaper.ImGui_EndDragDropTarget(ctx)
                            end

                            -- Popup for end color picker
                            if reaper.ImGui_BeginPopup(ctx, 'End Color Picker##'..i) then
                                local changed
                                changed, rule.end_color = reaper.ImGui_ColorPicker4(ctx, '##endcolorpicker'..i, rule.end_color, reaper.ImGui_ColorEditFlags_NoAlpha())
                                if changed then
                                    saveCurrentConfig()
                                end
                                reaper.ImGui_EndPopup(ctx)
                            end

                        elseif j == 4 then -- Exact Match
                            -- Checkbox for exact match
                            local changed, checked = reaper.ImGui_Checkbox(ctx, '##exactMatch'..i, rule.exact_match)
                            if changed then
                                rule.exact_match = checked
                                saveCurrentConfig()
                            end
                        elseif j == 5 then
                            -- Always show the 'up' button but make it inactive for the first item
                            if i == 1 then
                                reaper.ImGui_BeginDisabled(ctx)
                            end
                            if reaper.ImGui_Button(ctx, 'up##up'..i, 40) then
                                moveRule(i, -1)
                            end
                            if i == 1 then
                                reaper.ImGui_EndDisabled(ctx)
                            end

                            reaper.ImGui_SameLine(ctx)

                            -- Always show the 'down' button but make it inactive for the last item
                            if i == #rules then
                                reaper.ImGui_BeginDisabled(ctx)
                            end
                            if reaper.ImGui_Button(ctx, 'down##down'..i, 40) then
                                moveRule(i, 1)
                            end
                            if i == #rules then
                                reaper.ImGui_EndDisabled(ctx)
                            end
                        elseif j == 6 then  -- This is the new Delete column
                            if reaper.ImGui_Button(ctx, "X##delete" .. i) then
                                -- Here you handle the deletion of the rule
                                table.remove(rules, i)
                                saveCurrentConfig()
                                -- Optionally, after deleting a rule, you might want to refresh some state or GUI elements
                                -- Depending on how you manage state, you might need to do more here
                            end
                        end
                    end
                    reaper.ImGui_PopID(ctx)
                end
                reaper.ImGui_EndTable(ctx)
            end
            -- End the child region for the table
            reaper.ImGui_EndChild(ctx)
        end

        -- Add some spacing before the big button if needed
        reaper.ImGui_Dummy(ctx, 0, 10) -- This adds some vertical space

        -- Set the width for the big button (adjust the width to your preference)
        local big_button_width = -1 -- Using -1 to span the entire available width

        -- Set the height for the big button (adjust the height to your preference)
        local big_button_height = 50

        -- Create the big Apply Gradients button
        if reaper.ImGui_Button(ctx, "Apply Gradients", big_button_width, big_button_height) then
            -- Call the function that handles the gradient application here
            apply_gradients_based_on_rules()
        end

        -- Revert custom style
        revertCustomStyle()

        -- End the window (only if it's visible)
        reaper.ImGui_End(ctx)
    end

    -- Check if the window should remain open or be destroyed
    if open then
        -- Continue looping if the window is still open
        reaper.defer(loop)
    else
        -- Only destroy the context if the function exists
        if reaper.ImGui_DestroyContext and ctx then
            reaper.ImGui_DestroyContext(ctx)
            ctx = nil -- Set ctx to nil to avoid double-destruction
        end
    end
end

-- Start the loop
reaper.defer(loop)








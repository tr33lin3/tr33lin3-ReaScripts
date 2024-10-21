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




function deserializeTable(str)
    local f, err = load("return " .. str)
    if f then
        return f()
    else
        error("Failed to deserialize string: " .. (err or "unknown error"))
    end
end



apply_gradients_based_on_rules()







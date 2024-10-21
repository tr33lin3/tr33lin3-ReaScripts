-- File path for storing workflow status
local config_dir_path = reaper.GetResourcePath() .. "/Scripts/tr33lin3-ReaScripts/Cfg/"
local config_file_path = config_dir_path .. "tr33lin3_Toggle_Shortcut_Switch.cfg"

-- Function to check if the config file exists
function file_exists(file_path)
    local file = io.open(file_path, "r")
    if file then
        file:close()
        return true
    else
        return false
    end
end

-- Function to create the config file with a default status
function create_config_file()
    local file = io.open(config_file_path, "w")
    if file then
        file:write("slow")  -- Default state is "slow"
        file:close()
    else
        reaper.ShowMessageBox("Could not create config file: " .. config_file_path, "Error", 0)
    end
end

-- Function to read the current workflow status from the file
function read_workflow_status()
    if not file_exists(config_file_path) then
        create_config_file()  -- Create the file if it doesn't exist
    end

    local file = io.open(config_file_path, "r")
    local mode = file:read("*line")
    file:close()
    return mode
end

-- Function to trigger a native or custom action/script
function trigger_action(command_id)
    if type(command_id) == "number" then
        -- Native Reaper action
        reaper.Main_OnCommand(command_id, 0)
    elseif type(command_id) == "string" then
        -- Custom script (ReaScript)
        local resolved_command = reaper.NamedCommandLookup(command_id)
        if resolved_command ~= 0 then
            reaper.Main_OnCommand(resolved_command, 0)
        else
            reaper.ShowMessageBox("Could not resolve command ID: " .. command_id, "Error", 0)
        end
    else
        reaper.ShowMessageBox("Invalid command ID type", "Error", 0)
    end
end

-- Read the current state
local current_mode = read_workflow_status()

-- Trigger different actions/scripts based on the current mode
if current_mode == "current_mode = fast" then
    trigger_action("_RSfbae2056c1bd41f73c193478115695c03f6a8944")
else
    trigger_action(41305)
end

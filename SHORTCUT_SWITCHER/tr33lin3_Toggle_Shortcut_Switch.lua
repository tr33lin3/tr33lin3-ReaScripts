-- File path for storing workflow status
local config_file_path = reaper.GetResourcePath() .. "/Scripts/tr33lin3-ReaScripts/Cfg/tr33lin3_Toggle_Shortcut_Switch.cfg"

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
        file:write("current_mode = slow")  -- Default workflow is "slow"
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

-- Function to write the current workflow status to the file
function write_workflow_status(mode)
    local file = io.open(config_file_path, "w")
    if file then
        file:write(mode)
        file:close()
    else
        reaper.ShowMessageBox("Could not write to config file: " .. config_file_path, "Error", 0)
    end
end

-- Toggle toolbar button state to "on"
function toggle_button_on()
    is_new_value, filename, section_ID, cmd_ID, mode, resolution, val = reaper.get_action_context()
    reaper.SetToggleCommandState(section_ID, cmd_ID, 1) -- Set toolbar button to "on"
    reaper.RefreshToolbar2(section_ID, cmd_ID) -- Refresh toolbar
end

-- Toggle toolbar button state to "off"
function toggle_button_off()
    is_new_value, filename, section_ID, cmd_ID, mode, resolution, val = reaper.get_action_context()
    reaper.SetToggleCommandState(section_ID, cmd_ID, 0) -- Set toolbar button to "off"
    reaper.RefreshToolbar2(section_ID, cmd_ID) -- Refresh toolbar
end

-- Workflow initialization: set to "fast" when the script starts
function init()
    write_workflow_status("current_mode = fast")
    toggle_button_on()  -- Set toolbar button to on
end

-- Workflow cleanup: set to "slow" when the script ends
function exit()
    write_workflow_status("current_mode = slow")
    toggle_button_off()  -- Set toolbar button to off
end

-- Background loop to keep the script running
function loop()
    reaper.defer(loop)  -- Keep the script alive by calling itself continuously
end

-- Initialize workflow when the script starts
init()

-- Start the loop to keep the script running
loop()

-- Register exit function to run when the script stops
reaper.atexit(exit)


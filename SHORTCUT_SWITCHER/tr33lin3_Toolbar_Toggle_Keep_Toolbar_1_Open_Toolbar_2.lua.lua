-- @noindex
-- Function to open a specific toolbar and close the others (except toolbar 1)
function openToolbarAndCloseOthersExceptToolbar1(toolbarIndex)
    -- Open the specified toolbar
    reaper.Main_OnCommand(41680 + toolbarIndex, 0)  -- Open/close toolbar (41680 is for toolbar 2, + (toolbarIndex - 2) adjusts for others)

    -- Close all other toolbars except toolbar 1 and the specified toolbar
    for i = 2, 16 do  -- toolbars are from 2 to 16
        if i ~= toolbarIndex then
            reaper.Main_OnCommand(41696 + i - 2, 0)  -- Close toolbar (41696 is for close toolbar 2, + (i - 2) adjusts for others)
        end
    end
end



-- Specify the toolbar index to open (other than 1)
toolbarIndex = 2  -- This will be toolbar 2; change as needed

-- Call the function
openToolbarAndCloseOthersExceptToolbar1(toolbarIndex)

reaper.defer(function() end)  -- Prevent script from automatically closing the ReaScript console


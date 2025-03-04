-- -----------------------------------------------------------------------
-- DEPENDENCIES
-- -----------------------------------------------------------------------

require('hs.ipc')

-- -----------------------------------------------------------------------
-- SETTINGS
-- -----------------------------------------------------------------------

hs.console.darkMode(true)
hs.window.animationDuration = 0.3

-- -----------------------------------------------------------------------
-- MODULE - AUTO RELOAD ON SAVE
-- -----------------------------------------------------------------------

local function reloadConfig(files)
    for _, file in pairs(files) do
        if file:sub(-4) == ".lua" then
            hs.reload()
            hs.alert.show('Config Reloaded')
            return
        end
    end
end

local reloadConfigWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
reloadConfigWatcher:start()

-- -----------------------------------------------------------------------
-- MODULE - JJK Clipboard Manager
-- -----------------------------------------------------------------------

hs.loadSpoon("ClipboardFormatter")

-- Bind hotkeys to the clipboard formatter
spoon.ClipboardFormatter:bindHotkeys({
    format = {{"ctrl", "alt", "cmd", "shift"}, "v"},          -- Control+V to format clipboard contents
    formatSelection = {{"ctrl", "alt", "cmd"}, "v"}   -- Ctrl+Opt+Cmd+A to format selected text
})

-- Variables to track command key double-tap
local rightCmdTap = nil
local lastRightCmdTime = 0
local doubleTapDelay = 0.3 -- seconds

-- Create a tap event for right command key
rightCmdTap = hs.eventtap.new({ hs.eventtap.event.types.flagsChanged }, function(event)
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()
    
    -- Right Command key code is 54 (0x36)
    if keyCode == 54 then
        -- Key was pressed
        if flags.cmd then
            local now = hs.timer.secondsSinceEpoch()
            
            -- Check if this is a double tap
            if (now - lastRightCmdTime) < doubleTapDelay then
                hs.timer.doAfter(0.1, function()
                    spoon.ClipboardFormatter:formatSelection()
                end)
                hs.alert.show("Formatted selection via double-tap")
                lastRightCmdTime = 0
            else
                lastRightCmdTime = now
            end
        end
    end
    
    -- Let the event propagate
    return false
end)

-- Start the event tap
rightCmdTap:start()

-- -----------------------------------------------------------------------
-- MODULE - MIRO WINDOWS MANAGEMENT
-- -----------------------------------------------------------------------

local hyper = {"ctrl", "alt", "cmd"}

hs.loadSpoon("MiroWindowsManager")

hs.window.animationDuration = 0.3
spoon.MiroWindowsManager:bindHotkeys({
  up = {hyper, "up"},
  right = {hyper, "right"},
  down = {hyper, "down"},
  left = {hyper, "left"},
  fullscreen = {hyper, "f"},
  nextscreen = {hyper, "n"}
})

-- -----------------------------------------------------------------------

-- Update the alert message to include the new functionality
hs.alert.show("Clipboard Monitor Running")
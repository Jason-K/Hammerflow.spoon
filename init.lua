-- -----------------------------------------------------------------------
-- DEPENDENCIES
-- -----------------------------------------------------------------------

require('hs.ipc')

-- -----------------------------------------------------------------------
-- SETTINGS
-- -----------------------------------------------------------------------
hs.console.clearConsole()
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

hs.loadSpoon("MiroWindowsManager")

local hyper = {"ctrl", "alt", "cmd"}

hs.window.animationDuration = 0.0
spoon.MiroWindowsManager:bindHotkeys({
  up = {hyper, "up"},
  right = {hyper, "right"},
  down = {hyper, "down"},
  left = {hyper, "left"},
  fullscreen = {hyper, "f"},
  nextscreen = {hyper, "n"}
})

-- -----------------------------------------------------------------------
-- MODULE - RESIZE AND MOVE WINDOWS
-- -----------------------------------------------------------------------

hs.window.animationDuration = 0  -- Disable animations for snappier movement

local draggingWindow = nil
local resizingWindow = nil
local originalMousePos = nil
local originalFrame = nil

-- Function to start resizing a window (Ctrl + Shift + Left Click)
local function startResizeWindow(event)
    if event:getFlags():containExactly({'ctrl', 'shift'}) and event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) == 0 then
        local win = hs.window.frontmostWindow()
        if not win then return end
        resizingWindow = win
        originalMousePos = hs.mouse.absolutePosition()
        originalFrame = win:frame()
        return true
    end
end

-- Function to start moving a window (Ctrl + Shift + Right Click)
local function startMoveWindow(event)
    if event:getFlags():containExactly({'ctrl', 'shift'}) and event:getProperty(hs.eventtap.event.properties.mouseEventButtonNumber) == 1 then
        local win = hs.window.frontmostWindow()
        if not win then return end
        draggingWindow = win
        originalMousePos = hs.mouse.absolutePosition()
        originalFrame = win:frame()
        return true
    end
end

-- Function to update window size while resizing
local function resizeWindow()
    if not resizingWindow then return end
    local newMousePos = hs.mouse.absolutePosition()
    local dx = newMousePos.x - originalMousePos.x
    local dy = newMousePos.y - originalMousePos.y

    resizingWindow:setFrame({
        x = originalFrame.x,
        y = originalFrame.y,
        w = math.max(100, originalFrame.w + dx),
        h = math.max(100, originalFrame.h + dy)
    })
end

-- Function to update window position while dragging
local function moveWindow()
    if not draggingWindow then return end
    local newMousePos = hs.mouse.absolutePosition()
    local dx = newMousePos.x - originalMousePos.x
    local dy = newMousePos.y - originalMousePos.y

    draggingWindow:setFrame({
        x = originalFrame.x + dx,
        y = originalFrame.y + dy,
        w = originalFrame.w,
        h = originalFrame.h
    })
end

-- Stop moving or resizing when the mouse button is released
local function stopWindowAction()
    draggingWindow = nil
    resizingWindow = nil
end

-- Mouse event listener for starting window actions
hs.eventtap.new({hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.rightMouseDown}, function(event)
    return startResizeWindow(event) or startMoveWindow(event)
end):start()

-- Mouse event listener for dragging actions
hs.eventtap.new({hs.eventtap.event.types.leftMouseDragged, hs.eventtap.event.types.rightMouseDragged}, function()
    moveWindow()
    resizeWindow()
end):start()

-- Mouse event listener for stopping actions on button release
hs.eventtap.new({hs.eventtap.event.types.leftMouseUp, hs.eventtap.event.types.rightMouseUp}, function()
    stopWindowAction()
end):start()

-- -----------------------------------------------------------------------
-- MODULE - jjkHotkeys
-- -----------------------------------------------------------------------

-- Load the Spoon
hs.loadSpoon("jjkHotkeys")

-- Optionally enable debug logging
spoon.jjkHotkeys:toggleDebug(true)

-- Define our actual hotkeys:
-- This example shows:
--   - Single tap of 'a' -> alert "Single A"
--   - Double tap of 'a' -> alert "Double A"
--   - Press/hold 'a' -> alert "Held A"
--   - Left+right specific combos: left cmd + v triggers a different action than right cmd + v
--   - Double-tap of modifiers: double-tap right cmd
--   - A sequence: a -> b -> calls a function
--   - A layer "myLayer" that triggers if user does hold=layer, etc.
spoon.jjkHotkeys:bindHotkeys({
  taps = {
    ["a"] = {
      single  = function() hs.alert("Single A!") end,
      double  = function() hs.alert("Double A!") end,
      hold    = function() hs.alert("Held A!") end,
    },
  },
  combos = {
    ["v"] = {
      ["lcmd"] = function() hs.alert("Left CMD + V!") end,
      ["rcmd"] = function() hs.alert("Right CMD + V!") end,
    },
  },
  modTaps = {
    ["rcmd"] = {
      double = function() hs.alert("Double-tap right cmd!") end,
    },
  },
  sequences = {
    seqAB = {sequence={"a","b"}, action=function() hs.alert("You typed a,b!") end},
  },
  layers = {
    myLayer = {
      sequences = {
        -- For instance, once you're in 'myLayer', pressing x->y triggers a function
        xy = {sequence={"x","y"}, action=function() hs.alert("myLayer X->Y") end},
      },
    }
  }
})

-- Finally, start it
spoon.jjkHotkeys:start()


-- -----------------------------------------------------------------------

-- Update the alert message to include the new functionality
hs.alert.show("Hammerspoon running")
-- -----------------------------------------------------------------------
-- DEPENDENCIES
-- -----------------------------------------------------------------------

require('hs.ipc')

-- -----------------------------------------------------------------------
-- SETTINGS
-- -----------------------------------------------------------------------

hs.console.clearConsole()
hs.console.darkMode(true)
hs.window.animationDuration = 0.0

-- -----------------------------------------------------------------------
-- LOAD SPOON LIBRARIES
-- -----------------------------------------------------------------------

hs.loadSpoon("SpoonInstall")
hs.loadSpoon("MiroWindowsManager")
hs.loadSpoon("ClipboardFormatter")
hs.loadSpoon("jjkHotkeys")

-- -----------------------------------------------------------------------
-- CROSS-LIBRARY VARIABLES
-- -----------------------------------------------------------------------

local hyper       = { "lcmd", "lalt", "lctrl" }
local super       = { "lcmd", "lalt", "lctrl", "lshift" }
local superduper  = { "lcmd", "lalt", "lctrl", "lshift", "fn" }
local ctrl_cmd    = { "lcmd", "lctrl" }
local meh         = { "ralt", "rctrl" , "rshift" }
local Install     = spoon.SpoonInstall

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

-- Bind hotkeys to the clipboard formatter
spoon.ClipboardFormatter:bindHotkeys({
  format = { super, "v" },   -- Control+V to format clipboard contents
  formatSelection = { hyper, "v" } -- Ctrl+Opt+Cmd+A to format selected text
})

-- -----------------------------------------------------------------------
-- MODULE - MIRO WINDOWS MANAGEMENT
-- -----------------------------------------------------------------------

spoon.MiroWindowsManager:bindHotkeys({
  up = { hyper, "up" },
  right = { hyper, "right" },
  down = { hyper, "down" },
  left = { hyper, "left" },
  fullscreen = { hyper, "f" },
  nextscreen = { hyper, "n" }
})

-- -----------------------------------------------------------------------
-- WINDOWSHALFSANDTHIRDS AND WINDOWSGRID MODULES
-- -----------------------------------------------------------------------

local myGrid = { w = 6, h = 4 }
Install:andUse("WindowGrid",
  {
    config = {
      gridGeometries =
      { { myGrid.w .. "x" .. myGrid.h } }
    },
    hotkeys = { show_grid = { hyper, "g" } },
    start = true
  }
)

-- -----------------------------------------------------------------------
-- MODULE - Heaadphone autopause
-- -----------------------------------------------------------------------

Install:andUse("AutoMuteOnSleep")

Install:andUse("HeadphoneAutoPause",
  {
    start = true,
    disable = true,
  }
)


-- -----------------------------------------------------------------------
-- MODULE - jjkHotkeys
-- -----------------------------------------------------------------------

-- Optionally enable debug logging
spoon.jjkHotkeys:toggleDebug(false)



--[[
  
-- Define our actual hotkeys:
-- This example shows:
--   - Single tap of 'a' -> alert "Single A"
--   - Double tap of 'a' -> alert "Double A"
--   - Press/hold 'a' -> alert "Held A"
--   - Left+right specific combos: left cmd + v triggers a different action than right cmd + v
--   - Double-tap of modifiers: double tap right cmd
--   - A sequence: a > b > calls a function
--   - A layer "myLayer" that triggers if user does hold=layer, etc.

-- EXAMPLE DEFINITIONS

spoon.jjkHotkeys:bindHotkeys({
  taps = {
    ["a"] = {
      single = function() hs.alert("Single A!") end,
      double = function() hs.alert("Double A!") end,
      hold   = function() hs.alert("Held A!") end,
    },
  },
  combos = {
    ["v"] = {
      ["lcmd"] = function() hs.alert("Left CMD + V!") end,
      ["rcmd"] = function() hs.alert("Right CMD + V!") end,
    },
    ["f"] = {
      ["lcmd"] = function() hs.alert("Single F with Command!") end,
      ["lcmd2"] = function() hs.alert("Double F with Command!") end,
    },
  },
  modTaps = {
    ["rcmd"] = {
      double = function() spoon.ClipboardFormatter:formatSelection() end,
    },
    ["rctrl"] = {
      double = function() spoon.ClipboardFormatter:format() end,
    },
    ["lcmd"] = {
      -- single = function() hs.alert("Single left command!") end,
      double = function() hs.alert("Double-tap left command!") end,
      -- hold = function() hs.alert("Held left command!") end,
    },
    ["lctrl"] = {
      single = function() hs.alert("Single left control!") end,
      double = function() hs.alert("Double-tap left control!") end,
    }
  },
  sequences = {
    seqAB = { sequence = { "a", "b" }, action = function() hs.alert("You typed a,b!") end },
  },
  layers = {
    myLayer = {
      sequences = {
        -- For instance, once you're in 'myLayer', pressing x->y triggers a function
        xy = { sequence = { "x", "y" }, action = function() hs.alert("myLayer X->Y") end },
      },
    }
  }
})
    
]]

spoon.jjkHotkeys:bindHotkeys({
  modTaps = {
    ["rcmd"] = {
      double = function() spoon.ClipboardFormatter:formatSelection() end,
      hold = function() spoon.ClipboardFormatter:formatClipboard() end,
    },
  },
})

-- Finally, start it
spoon.jjkHotkeys:start()

-- -----------------------------------------------------------------------

-- Update the alert message to include the new functionality
hs.alert.show("Hammerspoon running")

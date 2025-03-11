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
hs.loadSpoon("jjkUserScripts")

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
local reloadConfigWatcher2 = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/Spoons", reloadConfig)
reloadConfigWatcher:start()
reloadConfigWatcher2:start()

-- -----------------------------------------------------------------------
-- MODULE - JJK Clipboard Manager
-- -----------------------------------------------------------------------

-- Bind hotkeys to the clipboard formatter
spoon.ClipboardFormatter:bindHotkeys({
  format = { super, "v" },   -- Super+V to format clipboard contents
  formatSelection = { hyper, "v" } -- Hyper+V to format selected text
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
-- MODULE - Headphone autopause
-- -----------------------------------------------------------------------

Install:andUse("HeadphoneAutoPause",
  {
    start = true,
    disable = true,
  }
)

-- -----------------------------------------------------------------------
-- MODULE - jjkUserScripts
-- -----------------------------------------------------------------------

spoon.jjkUserScripts:start()

-- -----------------------------------------------------------------------
-- DIRECT EVENT MONITORING FOR HYPER+S (CURRENT WORKING VERSION)
-- -----------------------------------------------------------------------
--[[ 
-- Create a simple hotkey watcher rather than using the complex eventtap
local hyperSHotkey = hs.hotkey.new(hyper, "s", function()
  hs.alert.show("Processing selection...")
  spoon.jjkUserScripts:doSearchOrOpen()
end)

-- Enable the hotkey
hyperSHotkey:enable()
 
-- Also provide a test hotkey using hyper+x
hs.hotkey.bind(hyper, "x", function()
  hs.alert.show("Processing selection...")
  spoon.jjkUserScripts:doSearchOrOpen()
end)
]]

-- -----------------------------------------------------------------------
-- MODULE - jjkHotkeys IMPLEMENTATION (ALTERNATIVE APPROACH)
-- -----------------------------------------------------------------------

-- Enable debug logging for initial testing
spoon.jjkHotkeys:toggleDebug(true)

-- Update functionality for various key combinations
spoon.jjkHotkeys:bindHotkeys({
  -- Right command functionality
  modTaps = {
    ["rcmd"] = {
      double = function() 
          spoon.ClipboardFormatter:formatSelection()
      end,
      hold = function() 
          spoon.ClipboardFormatter:formatClipboard()
      end,
    },
  },
  -- Add combos for "s" key with hyper modifiers
  combos = {
    ["s"] = {
      ["lcmd+lalt+lctrl"] = function()
        spoon.jjkUserScripts:searchOrOpen()
      end,
    },
  }
})

-- Start jjkHotkeys
spoon.jjkHotkeys:start()

-- -----------------------------------------------------------------------

-- Update the alert message to indicate the changes
hs.alert.show("Hammerspoon running with dual hyper+s implementations")

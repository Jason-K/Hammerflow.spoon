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
spoon.jjkHotkeys:toggleDebug(false)  -- Enable debug to see events in the console

spoon.jjkHotkeys:bindHotkeys({
  modTaps = {
    ["rcmd"] = {
      double = function() 
          print("Double-tap rcmd detected - calling ClipboardFormatter:formatSelection()")
          spoon.ClipboardFormatter:formatSelection()
      end,
      hold = function() 
          print("Hold rcmd detected - calling ClipboardFormatter:formatClipboard()")
          spoon.ClipboardFormatter:formatClipboard()
      end,
    },
  },
})

-- Optimized timing parameters for rcmd tap/double-tap/hold detection
spoon.jjkHotkeys.doubleTapDelay = 0.2    -- Shorter double tap window (200ms) for faster responsiveness
spoon.jjkHotkeys.holdDelay = 0.35        -- Moderate hold delay (350ms)
spoon.jjkHotkeys.multiTapTimeout = 0.25  -- Multi-tap timeout slightly longer than double tap delay

-- Finally, start it
spoon.jjkHotkeys:start()

-- -----------------------------------------------------------------------

-- Update the alert message to include the new functionality
hs.alert.show("Hammerspoon running")

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

-- Safely load Spoons with error handling
local function safeLoadSpoon(spoonName)
  local status, spoonOrError = pcall(function() return hs.loadSpoon(spoonName) end)
  if not status then
    hs.alert.show("Error loading " .. spoonName .. " Spoon")
    print("Error loading " .. spoonName .. ": " .. tostring(spoonOrError))
    return nil
  end
  return spoonOrError
end

safeLoadSpoon("SpoonInstall")
safeLoadSpoon("jjkHotkeys")
safeLoadSpoon("ClipboardFormatter")
safeLoadSpoon("jjkUserScripts")

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
-- CROSS-LIBRARY VARIABLES
-- -----------------------------------------------------------------------

local hyper      = { "lcmd", "lalt", "lctrl" }
local super      = { "lcmd", "lalt", "lctrl", "lshift" }
local superduper = { "lcmd", "lalt", "lctrl", "lshift", "fn" }
local ctrl_cmd   = { "lcmd", "lctrl" }
local meh        = { "ralt", "rctrl", "rshift" }
local Install    = spoon.SpoonInstall

-- -----------------------------------------------------------------------
-- MODULE - JJK Clipboard Manager
-- -----------------------------------------------------------------------

-- ClipboardFormatter is now configured through jjkHotkeys below

-- -----------------------------------------------------------------------
-- MODULE - jjkUserScripts
-- -----------------------------------------------------------------------

if spoon.jjkUserScripts then
  spoon.jjkUserScripts:start()
  -- Direct hotkey binding removed in favor of jjkHotkeys approach
else
  hs.alert.show("jjkUserScripts Spoon not loaded")
end

-- -----------------------------------------------------------------------
-- MODULE - jjkHotkeys IMPLEMENTATION (CENTRAL HOTKEY MANAGER)
-- -----------------------------------------------------------------------

if spoon.jjkHotkeys then
  spoon.jjkHotkeys:bindHotkeys({
    -- Right command functionality
    modTaps = {
      ["rcmd"] = {
        double = function()
          if spoon.ClipboardFormatter then
            spoon.ClipboardFormatter:formatSelection()
          end
        end,
        hold = function()
          if spoon.ClipboardFormatter then
            spoon.ClipboardFormatter:formatClipboard()
          end
        end,
      },
    },
    -- Consolidated key combos
    combos = {
      ["s"] = {
        ["lcmd+lalt+lctrl"] = function()
          if spoon.jjkUserScripts then
            spoon.jjkUserScripts:searchOrOpen()
          end
        end,
      },
      ["v"] = {
        ["lcmd+lalt+lctrl"] = function()
          if spoon.ClipboardFormatter then
            spoon.ClipboardFormatter:formatSelection()
          end
        end,
        ["lcmd+lalt+lctrl+lshift"] = function()
          if spoon.ClipboardFormatter then
            spoon.ClipboardFormatter:formatClipboard()
          end
        end,
      },
    }
  })

  -- Start jjkHotkeys
  spoon.jjkHotkeys:start()
else
  hs.alert.show("jjkHotkeys Spoon not loaded")
end

-- -----------------------------------------------------------------------

hs.alert.show("Hammerspoon configuration loaded")

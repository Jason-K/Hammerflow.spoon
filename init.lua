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


-- Bind Ctrl + Alt + Cmd + ' to wrap selected text in quotes
hs.hotkey.bind({"ctrl", "alt", "cmd"}, "'", function()
  -- Step 1: Copy whatever is currently selected
  hs.eventtap.keyStroke({"cmd"}, "c")

  -- Step 2: Small delay to allow copy operation to complete
  hs.timer.doAfter(0.2, function()
      -- Step 3: Get the copied text
      local selectedText = hs.pasteboard.getContents()
      if selectedText then
          -- Step 4: Add quotes
          local quotedText = '"' .. selectedText .. '"'
          hs.pasteboard.setContents(quotedText)

          -- Step 5: Paste new text
          hs.eventtap.keyStroke({"cmd"}, "v")
      end
  end)
end)

----------------------------------------------------------------

hs.alert.show("Hammerspoon configuration loaded")

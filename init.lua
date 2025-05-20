-- -----------------------------------------------------------------------
-- DEBUGGING HELPERS
-- -----------------------------------------------------------------------

-- Use hs.logger for logging
local mainLogger = hs.logger.new("mainInit", "debug") -- Changed "mainConfig" to "mainInit" for clarity

mainLogger:d("Starting Hammerspoon initialization") -- Replaced debugLog

-- Error handling wrapper
local function safeCall(description, func)
  mainLogger:d("Attempting: " .. description) -- Replaced debugLog
  local success, result = pcall(func)
  if not success then
    mainLogger:e("ERROR in " .. description .. ": " .. tostring(result)) -- Replaced debugLog
    hs.alert.show("Error: " .. description)
  -- else
    -- mainLogger:d("Success: " .. description) -- Replaced debugLog (optional)
  end
  return success, result
end

-- -----------------------------------------------------------------------
-- DEPENDENCIES
-- -----------------------------------------------------------------------

safeCall("Loading hs.ipc", function() require('hs.ipc') end)

-- -----------------------------------------------------------------------
-- SETTINGS
-- -----------------------------------------------------------------------

safeCall("Configuring console", function()
  hs.console.clearConsole()
  hs.console.darkMode(true)
  hs.window.animationDuration = 0.0
end)

-- -----------------------------------------------------------------------
-- LOAD SPOON LIBRARIES
-- -----------------------------------------------------------------------

-- Initialize spoon table if it doesn't exist
if spoon == nil then
  mainLogger:d("Initializing spoon table") -- Replaced debugLog
  spoon = {}
end

-- Safely load Spoons with error handling
local function safeLoadSpoon(spoonName)
  mainLogger:d("Loading Spoon: " .. spoonName) -- Replaced debugLog
  local status, spoonOrError = pcall(function() return hs.loadSpoon(spoonName) end)
  if not status then
    local errorMsg = "Error loading " .. spoonName .. ": " .. tostring(spoonOrError)
    mainLogger:e(errorMsg) -- Replaced debugLog and print
    hs.alert.show("Error loading " .. spoonName .. " Spoon")
    -- Removed print(errorMsg) as logger handles it
    return nil
  end
  mainLogger:d("Successfully loaded Spoon: " .. spoonName) -- Replaced debugLog
  return spoonOrError
end

safeCall("Loading spoons", function()
  -- Assign each spoon properly
  -- local spoonInst = safeLoadSpoon("SpoonInstall")
  -- if spoonInst then spoon.SpoonInstall = spoonInst end
  
  local jjkHotkeys = safeLoadSpoon("jjkHotkeys")
  if jjkHotkeys then spoon.jjkHotkeys = jjkHotkeys end
  
  local clipFormatter = safeLoadSpoon("ClipboardFormatter")
  if clipFormatter then spoon.ClipboardFormatter = clipFormatter end

  local stringWrapper = safeLoadSpoon("StringWrapper")
  if stringWrapper then spoon.StringWrapper = stringWrapper end
  end)

-- -----------------------------------------------------------------------
-- MODULE - AUTO RELOAD ON SAVE
-- -----------------------------------------------------------------------

local function reloadConfig(files)
  for _, file in pairs(files) do
    if file:sub(-4) == ".lua" then
      mainLogger:d("Config file changed: " .. file .. ", reloading...") -- Replaced debugLog
      hs.reload()
      hs.alert.show('Config Reloaded')
      return
    end
  end
end

safeCall("Setting up config reload watcher", function()
  local reloadConfigWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
  reloadConfigWatcher:start()
end)

-- -----------------------------------------------------------------------
-- CROSS-LIBRARY VARIABLES
-- -----------------------------------------------------------------------

local hyper      = { "lcmd", "lalt", "lctrl" }
local super      = { "lcmd", "lalt", "lctrl", "lshift" }
local superduper = { "lcmd", "lalt", "lctrl", "lshift", "fn" }
local ctrl_cmd   = { "lcmd", "lctrl" }
local meh        = { "ralt", "rctrl", "rshift" }

-- -----------------------------------------------------------------------
-- QUOTE WRAPPER HELPER FUNCTION
-- -----------------------------------------------------------------------
local function wrapSelectionWithQuotes()
  mainLogger:d("wrapSelectionWithQuotes called")
  -- Step 1: Copy whatever is currently selected
  hs.eventtap.keyStroke({"cmd"}, "c")
  -- Step 2: Small delay to allow copy operation to complete
  hs.timer.doAfter(0.1, function() -- Reduced delay slightly
      -- Step 3: Get the copied text
      local selectedText = hs.pasteboard.getContents()
      if selectedText and #selectedText > 0 then -- Check if text is not empty
          -- Step 4: Add quotes
          local quotedText = '"' .. selectedText .. '"'
          hs.pasteboard.setContents(quotedText)
          -- Step 5: Paste new text
          hs.eventtap.keyStroke({"cmd"}, "v")
          mainLogger:d("Selection wrapped with quotes and pasted: " .. quotedText)
      else
          mainLogger:w("No text selected or clipboard empty, cannot wrap with quotes")
      end
  end)
end

-- -----------------------------------------------------------------------
-- MODULE - jjkHotkeys IMPLEMENTATION (CENTRAL HOTKEY MANAGER)
-- -----------------------------------------------------------------------

safeCall("Setting up jjkHotkeys", function()
  if spoon.jjkHotkeys then
    mainLogger:d("Binding hotkeys for jjkHotkeys") -- Replaced debugLog

    -- Enable debug mode to help troubleshoot
    spoon.jjkHotkeys:toggleDebug(true) -- This might use its own logger or print, review jjkHotkeys spoon later

    spoon.jjkHotkeys:bindHotkeys({
      -- Right command functionality
      modTaps = {
        ["rcmd"] = {
          double = function()
            mainLogger:d("rcmd double-tap detected") -- Replaced debugLog
            if spoon.ClipboardFormatter then
              spoon.ClipboardFormatter:formatSelection()
            end
          end,
          hold = function()
            mainLogger:d("rcmd hold detected") -- Replaced debugLog
            if spoon.ClipboardFormatter then
              spoon.ClipboardFormatter:formatClipboard()
            end
          end,
        },
      },
      -- Consolidated key combos
      combos = {
        ["v"] = {
          ["lcmd+lalt+lctrl"] = function() -- hyper+v
            mainLogger:d("hyper+v detected for ClipboardFormatter:formatSelection()") 
            if spoon.ClipboardFormatter then
              spoon.ClipboardFormatter:formatSelection()
            else
              mainLogger:e("ClipboardFormatter spoon not available for hyper+v")
            end
          end,
          ["lcmd+lalt+lctrl+lshift"] = function() -- super+v
            mainLogger:d("super+v detected for ClipboardFormatter:formatClipboard()") 
            if spoon.ClipboardFormatter then
              spoon.ClipboardFormatter:formatClipboard()
            else
              mainLogger:e("ClipboardFormatter spoon not available for super+v")
            end
          end,
        },
        ["w"] = {
          ["lcmd+lalt+lctrl+lshift"] = function() -- super+w
            mainLogger:d("super+w detected in init.lua") 
            if spoon.StringWrapper then
              mainLogger:d("Found spoon.StringWrapper, attempting to call :wrapSelection()")
              spoon.StringWrapper:wrapSelection()
            else
              mainLogger:e("StringWrapper spoon not available when super+w was pressed.")
            end
          end,
        },
        ["'"] = { -- New entry for quote wrapper
          ["lcmd+lalt+lctrl"] = function() -- hyper+'
            mainLogger:d("hyper+' detected for wrapSelectionWithQuotes()")
            wrapSelectionWithQuotes()
          end,
        },
      }
    })

    -- Start jjkHotkeys
    mainLogger:d("Starting jjkHotkeys") -- Replaced debugLog
    spoon.jjkHotkeys:start()
  else
    mainLogger:e("jjkHotkeys Spoon not loaded") -- Replaced debugLog
    hs.alert.show("jjkHotkeys Spoon not loaded")
  end
end)

-- -----------------------------------------------------------------------
-- STANDALONE WRAPPER FUNCTIONALITY (REMOVED - Integrated into jjkHotkeys)
-- -----------------------------------------------------------------------

-- -----------------------------------------------------------------------
-- QUOTE WRAPPER FUNCTIONALITY (REMOVED - Integrated into jjkHotkeys)
-- -----------------------------------------------------------------------

-- -----------------------------------------------------------------------
-- FINALIZATION
-- -----------------------------------------------------------------------

safeCall("Finalizing initialization", function()
  mainLogger:i("Hammerspoon configuration loaded successfully") -- Replaced debugLog, changed to info
  hs.alert.show("Hammerspoon configuration loaded")
  -- Removed debugLogFile:close() as hs.logger handles its output streams
end)

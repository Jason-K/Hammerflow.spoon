-- -----------------------------------------------------------------------
-- DEBUGGING HELPERS
-- -----------------------------------------------------------------------

-- Create a log file for debugging
local debugLogFile = io.open(os.getenv("HOME") .. "/.hammerspoon/debug_log.txt", "w")
local function debugLog(message)
  if debugLogFile then
    debugLogFile:write(os.date("%Y-%m-%d %H:%M:%S") .. ": " .. tostring(message) .. "\n")
    debugLogFile:flush()
  end
end

debugLog("Starting Hammerspoon initialization")

-- Error handling wrapper
local function safeCall(description, func)
  debugLog("Attempting: " .. description)
  local success, result = pcall(func)
  if not success then
    debugLog("ERROR in " .. description .. ": " .. tostring(result))
    hs.alert.show("Error: " .. description)
  else
    debugLog("Success: " .. description)
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
  debugLog("Initializing spoon table")
  spoon = {}
end

-- Safely load Spoons with error handling
local function safeLoadSpoon(spoonName)
  debugLog("Loading Spoon: " .. spoonName)
  local status, spoonOrError = pcall(function() return hs.loadSpoon(spoonName) end)
  if not status then
    local errorMsg = "Error loading " .. spoonName .. ": " .. tostring(spoonOrError)
    debugLog(errorMsg)
    hs.alert.show("Error loading " .. spoonName .. " Spoon")
    print(errorMsg)
    return nil
  end
  debugLog("Successfully loaded Spoon: " .. spoonName)
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
      debugLog("Config file changed: " .. file .. ", reloading...")
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
-- MODULE - jjkHotkeys IMPLEMENTATION (CENTRAL HOTKEY MANAGER)
-- -----------------------------------------------------------------------

safeCall("Setting up jjkHotkeys", function()
  if spoon.jjkHotkeys then
    debugLog("Binding hotkeys for jjkHotkeys")

    -- Enable debug mode to help troubleshoot
    spoon.jjkHotkeys:toggleDebug(true)

    spoon.jjkHotkeys:bindHotkeys({
      -- Right command functionality
      modTaps = {
        ["rcmd"] = {
          double = function()
            debugLog("rcmd double-tap detected")
            if spoon.ClipboardFormatter then
              spoon.ClipboardFormatter:formatSelection()
            end
          end,
          hold = function()
            debugLog("rcmd hold detected")
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
            debugLog("hyper+v detected")
            if spoon.ClipboardFormatter then
              spoon.ClipboardFormatter:formatSelection()
            end
          end,
          ["lcmd+lalt+lctrl+lshift"] = function()
            debugLog("super+v detected")
            if spoon.ClipboardFormatter then
              spoon.ClipboardFormatter:formatClipboard()
            end
          end,
        },
        ["w"] = {
          ["lcmd+lalt+lctrl+lshift"] = function()
            debugLog("super+w detected")
            if spoon.StringWrapper then
              debugLog("Calling StringWrapper:wrapSelection()")
              spoon.StringWrapper:wrapSelection()
            else
              debugLog("StringWrapper spoon not available")
              hs.alert.show("StringWrapper spoon not available")
            end
          end,
        },
      }
    })

    -- Start jjkHotkeys
    debugLog("Starting jjkHotkeys")
    spoon.jjkHotkeys:start()
  else
    debugLog("jjkHotkeys Spoon not loaded")
    hs.alert.show("jjkHotkeys Spoon not loaded")
  end
end)

-- -----------------------------------------------------------------------
-- STANDALONE WRAPPER FUNCTIONALITY
-- -----------------------------------------------------------------------

safeCall("Setting up standalone wrapper hotkey", function()
  debugLog("Setting up standalone wrapper hotkey with ctrl+alt+cmd+shift+w")
  
  -- Create a direct hotkey binding as a fallback to see if that works
  hs.hotkey.bind({"ctrl", "alt", "cmd", "shift"}, "w", function()
    debugLog("Direct hotkey (ctrl+alt+cmd+shift+w) triggered")
    
    if spoon.StringWrapper then
      debugLog("Calling StringWrapper:wrapSelection() via direct hotkey")
      spoon.StringWrapper:wrapSelection()
    else
      debugLog("StringWrapper spoon not available (direct hotkey)")
      hs.alert.show("StringWrapper spoon not available")
    end
  end)
end)

-- -----------------------------------------------------------------------
-- QUOTE WRAPPER FUNCTIONALITY
-- -----------------------------------------------------------------------

safeCall("Setting up quote wrapper hotkey", function()
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
end)

-- -----------------------------------------------------------------------
-- FINALIZATION
-- -----------------------------------------------------------------------

safeCall("Finalizing initialization", function()
  debugLog("Hammerspoon configuration loaded successfully")
  hs.alert.show("Hammerspoon configuration loaded")
  if debugLogFile then
    debugLogFile:close()
    debugLogFile = nil
  end
end)

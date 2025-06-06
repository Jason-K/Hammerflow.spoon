-- -----------------------------------------------------------------------
-- LOCAL VARIABLES
-- -----------------------------------------------------------------------

local hyper      = { "lcmd", "lalt", "lctrl" }
local super      = { "lcmd", "lalt", "lctrl", "lshift" }
local superduper = { "lcmd", "lalt", "lctrl", "lshift", "fn" }
local ctrl_cmd   = { "lcmd", "lctrl" }
local meh        = { "ralt", "rctrl", "rshift" }

-- -----------------------------------------------------------------------
-- LOCAL FUNCTIONS
-- -----------------------------------------------------------------------

-- Use hs.logger for logging
local mainLogger = hs.logger.new("mainInit", "debug") -- Changed "mainConfig" to "mainInit" for clarity

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

-- Reload configuration when files change in ~/.hammerspoon/
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

-- -----------------------------------------------------------------------
-- AUTOINIT
-- -----------------------------------------------------------------------

mainLogger:d("Starting Hammerspoon initialization") -- Replaced debugLog

safeCall("Loading hs.ipc", function() require('hs.ipc') end)

safeCall("Configuring console", function()
  hs.console.clearConsole()
  hs.console.darkMode(true)
  hs.window.animationDuration = 0.0
end)

safeCall("Setting up config reload watcher", function()
  local reloadConfigWatcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
  mainLogger:d("Reloading after changes to ".. os.getenv("HOME") .. "/.hammerspoon/")
  reloadConfigWatcher:start()
end)

-- -----------------------------------------------------------------------
-- LOAD SPOON LIBRARIES
-- -----------------------------------------------------------------------

-- Initialize spoon table if it doesn't exist
if spoon == nil then
  mainLogger:d("Initializing spoon table") -- Replaced debugLog
  spoon = {}
end

safeCall("Loading spoons", function()
  
  -- local jjkHotkeys = safeLoadSpoon("jjkHotkeys")
  -- if jjkHotkeys then 
  --   spoon.jjkHotkeys = jjkHotkeys 
  -- end

  local clipFormatter = safeLoadSpoon("ClipboardFormatter")
  if clipFormatter then 
    spoon.ClipboardFormatter = clipFormatter 
    formatClip = function() spoon.ClipboardFormatter:formatClipboard() end
    formatSelected = function() spoon.ClipboardFormatter:formatSelection() end
  end

  local stringWrapper = safeLoadSpoon("StringWrapper")
  if stringWrapper then 
    spoon.StringWrapper = stringWrapper 
    wrapString = function() stringWrapper:wrapSelection() end
    quoteString = function() stringWrapper:wrapSelectionWithQuotes() end
  end

end)

-- -----------------------------------------------------------------------
-- FINALIZATION
-- -----------------------------------------------------------------------

safeCall("Finalizing initialization", function()
  mainLogger:i("Hammerspoon configuration loaded successfully") -- Replaced debugLog, changed to info
  hs.alert.show("Hammerspoon configuration loaded")
end)

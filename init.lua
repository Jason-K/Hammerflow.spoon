-- Initialize loading variables

-- Use hs.logger for logging
local mainLogger = hs.logger.new("mainInit", "error") -- Changed "mainConfig" to "mainInit" for clarity

-- Safely load Spoons with error handling
local safeLoad = hs.loadSpoon("SafeLoad")

-- Initialize spoon table if it doesn't exist
if not SpoonTable then
    SpoonTable = {}
    _G.SpoonTable = SpoonTable
end


-- -----------------------------------------------------------------------
-- LOCAL FUNCTIONS
-- -----------------------------------------------------------------------

local function safeLoadSpoon(spoonName)
    if safeLoad then
        return safeLoad:load(spoonName)
    else
        mainLogger:e("SafeLoad Spoon is not available")
        return nil
    end
end

local function safeCallSpoon(description, func)
    if safeLoad then
        -- Use pcall directly as SafeCall doesn't appear to exist in the SafeLoad spoon
        local ok, result = pcall(func)
        if not ok then
            mainLogger:e("Error executing: " .. description .. " - " .. tostring(result))
        end
        return ok, result
    else
        mainLogger:e("SafeLoad Spoon is not available for: " .. description)
        -- Fall back to pcall if SafeLoad isn't available
        local ok, result = pcall(func)
        if not ok then
            mainLogger:e("Error executing: " .. description .. " - " .. tostring(result))
        end
        return ok, result
    end
end

-- -----------------------------------------------------------------------
-- AUTOINIT
-- -----------------------------------------------------------------------

mainLogger:d("Starting Hammerspoon initialization") -- Replaced debugLog

safeCallSpoon("Loading hs.ipc", function() require('hs.ipc') end)

safeCallSpoon("Configuring console", function()
    hs.console.clearConsole()
    hs.console.darkMode(true)
    hs.window.animationDuration = 0
end)

-- -----------------------------------------------------------------------
-- LOAD SPOON LIBRARIES
-- -----------------------------------------------------------------------


mainLogger:d("Initializing spoon table") -- Replaced debugLog

safeCallSpoon("Loading spoons", function()
    -- TO DO: Problem loading emmyLua - reason unclear. Need to address at some point in the future
    --
    local emmyLua = safeLoadSpoon("EmmyLua")
    if emmyLua and type(emmyLua.start) == "function" then
        SpoonTable.EmmyLua = emmyLua
        emmyLua:start()
    else
        mainLogger:w("EmmyLua spoon or its start method not found.")
    end

    local scriptReloader = safeLoadSpoon("ReloadConfiguration")
    if scriptReloader and type(scriptReloader.start) == "function" then
        SpoonTable.ReloadConfiguration = scriptReloader
        local reloadIgnorePatterns = {
            '/Spoons/hsLauncher.spoon/logs/',
            '/Spoons/hsLauncher.spoon/backups/',
            '/Spoons/hsLauncher.spoon/temp/',
            '/Spooons/hsLauncher.spoon/tests/',
            '/Spoons/hsLauncher.spoon/docs/',
            '/.vscode/',
            '.editorconfig',
            '.DS_Store',
            '/.git/',
            '/node_modules/',
            '.luacheckrc',
            '.README.md',
            '.gitignore',
            '/logs/',
            '/logs/reloadLog.txt',
        }

        local function shouldReloadFor(paths)
            for _, path in ipairs(paths) do
                local ignore = false
                for _, pattern in ipairs(reloadIgnorePatterns) do
                    if path:find(pattern, 1, true) then
                        ignore = true
                        break
                    end
                end
                if not ignore then
                    return true
                end
            end
            return false
        end
        function scriptReloader:start()
            if self.watchers then
                for _, watcher in pairs(self.watchers) do
                    watcher:stop()
                end
            end
            self.watchers = {}

            -- Ensure logs directory exists
            local logDir = hs.configdir .. "/logs"
            if not hs.fs.attributes(logDir) then
                hs.fs.mkdir(logDir)
            end

            local logFile = logDir .. "/reloadLog.txt"

            local function logReload(paths)
                local file = io.open(logFile, "a")
                if file then
                    file:write(os.date("%Y-%m-%d %H:%M:%S") .. " - Configuration reloaded due to changes in:\n")
                    for _, path in ipairs(paths) do
                        file:write("  - " .. path .. "\n")
                    end
                    file:write("\n")
                    file:close()
                end
            end

            local callback = function(paths)
                if shouldReloadFor(paths) then
                    logReload(paths)
                    hs.reload()
                end
            end

            for _, dir in pairs(self.watch_paths or {}) do
                self.watchers[dir] = hs.pathwatcher.new(dir, callback):start()
            end
            return self
        end

        SpoonTable.ReloadConfiguration.watch_paths = { hs.configdir }
        SpoonTable.ReloadConfiguration:start()
    else
        mainLogger:w("ReloadConfiguration spoon or its start method not found.")
    end

    local clipFormatter = safeLoadSpoon("ClipboardFormatter")
    if clipFormatter then
        SpoonTable.ClipboardFormatter = clipFormatter
        FormatClip = function() SpoonTable.ClipboardFormatter:formatClipboard() end
        FormatSelected = function() SpoonTable.ClipboardFormatter:formatSelection() end
    end

    local stringWrapper = safeLoadSpoon("StringWrapper")
    if stringWrapper then
        SpoonTable.StringWrapper = stringWrapper
        WrapString = function() SpoonTable.StringWrapper:wrapSelection() end
        QuoteString = function() SpoonTable.StringWrapper:wrapSelectionWithQuotes() end
        WrapWithParam = function(param) SpoonTable.StringWrapper:wrapSelectionWithParam(param) end
    end

    local hsLauncher = safeLoadSpoon("hsLauncher")
    if hsLauncher then
        SpoonTable.hsLauncher = hsLauncher
        hsLauncher:start()
    else
        mainLogger:w("hsLauncher spoon or its start method not found.")
    end
end)

safeCallSpoon("Finalizing initialization", function()
    mainLogger:i("Hammerspoon configuration loaded successfully") -- Replaced debugLog, changed to info
    hs.alert.show("Hammerspoon configuration loaded")
end)

---@diagnostic disable-next-line: undefined-global
local hs = hs

-- Initialize loading variables

-- Use hs.logger for logging
local mainLogger = hs.logger.new("mainInit", "info") -- Surface informational startup logs

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

---@param base string
local function extendPackagePath(base)
    local patterns = {
        base .. "/?.lua",
        base .. "/?/init.lua",
    }
    for _, pattern in ipairs(patterns) do
        if not package.path:find(pattern, 1, true) then
            package.path = package.path .. ";" .. pattern
        end
    end
end

local hsLauncher2Root = nil
local hsStringEvalRoot = nil

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

safeCallSpoon("Extending package paths for hsLauncher2", function()
    local candidates = {
        hs.configdir .. "/hsLauncher2",
        hs.configdir .. "/../hsLauncher2",
        os.getenv("HOME") .. "/Scripts/Metascripts/hsLauncher2",
    }
    for _, base in ipairs(candidates) do
        if type(base) == "string" then
            local attrs = hs.fs.attributes(base)
            if type(attrs) == "table" and attrs.mode == "directory" then
                hsLauncher2Root = hsLauncher2Root or base
                extendPackagePath(base)
            end
        end
    end
    if not hsLauncher2Root then
        mainLogger:w("hsLauncher2 directory not found in expected locations; launcher will not start")
    else
        mainLogger:i("hsLauncher2 root detected at " .. hsLauncher2Root)
    end
end)

safeCallSpoon("Extending package paths for hsStringEval", function()
    local candidates = {
        hs.configdir .. "/hsStringEval",
        hs.configdir .. "/../hsStringEval",
        os.getenv("HOME") .. "/Scripts/Metascripts/hsStringEval",
    }
    for _, base in ipairs(candidates) do
        if type(base) == "string" then
            local attrs = hs.fs.attributes(base)
            if type(attrs) == "table" and attrs.mode == "directory" then
                hsStringEvalRoot = hsStringEvalRoot or base
                extendPackagePath(base)
            end
        end
    end
    if not hsStringEvalRoot then
        mainLogger:w("hsStringEval directory not found; refactored ClipboardFormatter unavailable")
    else
        mainLogger:i("hsStringEval root detected at " .. hsStringEvalRoot)
    end
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

    --[[
    local clipFormatter = safeLoadSpoon("ClipboardFormatter")
    if clipFormatter then
        SpoonTable.ClipboardFormatter = clipFormatter
        FormatClip = function() SpoonTable.ClipboardFormatter:formatClipboard() end
        FormatSelected = function() SpoonTable.ClipboardFormatter:formatSelection() end
    end
    --]]

    if type(hsStringEvalRoot) == "string" then
        local ok, moduleOrErr = pcall(require, "src.init")
        if not ok then
            mainLogger:e("Failed to require refactored ClipboardFormatter: " .. tostring(moduleOrErr))
        elseif moduleOrErr then
            package.loaded["hsStringEval.src.init"] = moduleOrErr
            moduleOrErr.spoonPath = hsStringEvalRoot .. "/src"
            local formatterInstance = moduleOrErr:init()
            SpoonTable.ClipboardFormatter = formatterInstance
            FormatClip = function()
                return SpoonTable.ClipboardFormatter:formatClipboardDirect()
            end
            FormatSelected = function()
                return SpoonTable.ClipboardFormatter:formatSelection()
            end
            mainLogger:i("Refactored ClipboardFormatter loaded")
        else
            mainLogger:e("Refactored ClipboardFormatter module returned nil")
        end
    else
        mainLogger:w("Skipping refactored ClipboardFormatter load; hsStringEval root not detected")
    end

    if not FormatClip then
        FormatClip = function()
            if type(hs) == "table" and hs.alert then
                hs.alert.show("ClipboardFormatter unavailable")
            end
            return false
        end
    end

    if not FormatSelected then
        FormatSelected = function()
            if type(hs) == "table" and hs.alert then
                hs.alert.show("ClipboardFormatter unavailable")
            end
            return false
        end
    end

    local stringWrapper = safeLoadSpoon("StringWrapper")
    if type(stringWrapper) == "table" then
        SpoonTable.StringWrapper = stringWrapper
        WrapString = function() SpoonTable.StringWrapper:wrapSelection() end
        QuoteString = function() SpoonTable.StringWrapper:wrapSelectionWithQuotes() end
        WrapWithParam = function(param) SpoonTable.StringWrapper:wrapSelectionWithParam(param) end
    end


end)

safeCallSpoon("Starting hsLauncher2", function()
    if not hsLauncher2Root then
        mainLogger:w("Skipping hsLauncher2 startup because root directory was not detected")
        return
    end
    local entry = hsLauncher2Root .. "/init.lua"
    local attrs = hs.fs.attributes(entry)
    if not attrs then
        error("hsLauncher2 entry file missing at " .. entry)
    end
    local ok, result = pcall(dofile, entry)
    if not ok then
        error(result)
    end
    return result
end)

safeCallSpoon("Finalizing initialization", function()
    mainLogger:i("Hammerspoon configuration loaded successfully") -- Replaced debugLog, changed to info
    hs.alert.show("Hammerspoon configuration loaded")
end)

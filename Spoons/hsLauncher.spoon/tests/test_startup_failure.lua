local scriptPath = debug.getinfo(1, "S").source:sub(2)
if scriptPath:sub(1, 1) ~= '/' then
    local cwd = assert(io.popen('pwd'):read('*l'), 'Unable to determine working directory')
    scriptPath = cwd .. '/' .. scriptPath
end
local testDir = scriptPath:match('(.*/)')
assert(testDir, 'Unable to determine test directory from ' .. tostring(scriptPath))
local projectRoot = testDir:gsub('/tests/?$', '/')
local parentRoot = projectRoot:gsub('/[^/]+/?$', '/')

package.path = table.concat({
    projectRoot .. '?.lua',
    projectRoot .. '?/init.lua',
    projectRoot .. 'main/?.lua',
    projectRoot .. 'main/?/init.lua',
    parentRoot .. '?.lua',
    parentRoot .. '?/init.lua',
    parentRoot .. 'main/?.lua',
    parentRoot .. 'main/?/init.lua',
    package.path,
}, ';')

local LOADER_GUARD = '__hslauncher_loader_startup'

local function registerHsLauncherLoader(root)
    if package[LOADER_GUARD] then return end
    table.insert(package.searchers, 2, function(moduleName)
        local relative = moduleName:match('^hsLauncher%.(.+)$')
        if not relative then return nil end
        local base = root .. relative:gsub('%.', '/')
        local attempts = {}
        local function try(path)
            local chunk, err = loadfile(path)
            if chunk then return chunk end
            attempts[#attempts + 1] = err or ('no file ' .. path)
            return nil
        end
        local chunk = try(base .. '.lua') or try(base .. '/init.lua')
        if chunk then return chunk end
        return nil, table.concat(attempts, '\n')
    end)
    package[LOADER_GUARD] = true
end

registerHsLauncherLoader(projectRoot)

if package.loaded['hs.fs'] == nil then
    package.loaded['hs.fs'] = {
        attributes = function()
            return nil
        end,
        mkdir = function()
            return true
        end,
        touch = function()
            return true
        end,
        dir = function()
            return function()
                return nil
            end
        end,
        pathToAbsolute = function(path)
            return path
        end,
    }
end

local logHistory = {
    info = {},
    warn = {},
    error = {},
}

local function resetLogs()
    logHistory.info = {}
    logHistory.warn = {}
    logHistory.error = {}
end

local function record(level, message)
    local bucket = logHistory[level]
    bucket[#bucket + 1] = message
end

local loggerStub = {
    info = function(message)
        record('info', message)
    end,
    warn = function(message)
        record('warn', message)
    end,
    error = function(message)
        record('error', message)
    end,
    history = logHistory,
}

local function installStub(moduleName, stub)
    local original = {
        loaded = package.loaded[moduleName],
        preload = package.preload[moduleName],
    }
    package.loaded[moduleName] = stub
    package.preload[moduleName] = function()
        return stub
    end
    return function()
        if original.loaded ~= nil then
            package.loaded[moduleName] = original.loaded
        else
            package.loaded[moduleName] = nil
        end
        if original.preload ~= nil then
            package.preload[moduleName] = original.preload
        else
            package.preload[moduleName] = nil
        end
    end
end

local registryStub = {
    loadCalls = 0,
    state = nil,
}

function registryStub.load()
    registryStub.loadCalls = registryStub.loadCalls + 1
    return registryStub.state
end

function registryStub.declarativeState()
    return registryStub.state
end

function registryStub.setState(state)
    registryStub.state = state
end

function registryStub.reset()
    registryStub.loadCalls = 0
    registryStub.state = nil
end

local restoreLogger = installStub('hsLauncher.main.core.logger', loggerStub)
local restoreRegistry = installStub('hsLauncher.main.user.registry', registryStub)

local function reloadLauncher()
    package.loaded['hsLauncher.main.init'] = nil
    package.loaded['hsLauncher.main.runtime.init'] = nil
    return require('hsLauncher.main.init')
end

local function assertTrue(condition, message)
    if not condition then
        error(message or 'assertTrue failed')
    end
end

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format('%s\nexpected: %s\nactual  : %s', message or 'assertEquals failed', tostring(expected), tostring(actual)))
    end
end

local function assertLogContains(level, expected)
    for _, entry in ipairs(logHistory[level] or {}) do
        if entry:find(expected, 1, true) then
            return
        end
    end
    error(string.format('expected %s log to contain [%s]', level, expected))
end

local function loaderFailureScenario()
    local Launcher = reloadLauncher()
    registryStub.reset()
    registryStub.setState({
        loader = { ok = false, diagnostics = { errors = { { message = 'loader failed' } } } },
        builder = {},
    })
    resetLogs()
    local instance, err = Launcher.start()
    assertEquals(instance, nil, 'launcher should not start when config loader fails')
    assertEquals(err, 'config loader did not complete successfully', 'unexpected error for loader failure')
    assertEquals(registryStub.loadCalls, 1, 'registry.load should be invoked once per start')
    assertLogContains('info', 'hsLauncher start')
    assertLogContains('error', 'config loader did not complete successfully')
    Launcher.stop()
end


local function builderFailureScenario()
    local Launcher = reloadLauncher()
    registryStub.reset()
    registryStub.setState({
        loader = { ok = true, actions = {} },
        builder = { ok = false, diagnostics = { errors = { { message = 'builder failed' } } } },
    })
    resetLogs()
    local instance, err = Launcher.start()
    assertEquals(instance, nil, 'launcher should not start when menu builder fails')
    assertEquals(err, 'menu builder did not complete successfully', 'unexpected error for builder failure')
    assertEquals(registryStub.loadCalls, 1, 'registry.load should be invoked once per start')
    assertLogContains('info', 'hsLauncher start')
    assertLogContains('error', 'menu builder did not complete successfully')
    Launcher.stop()
end

local function run()
    loaderFailureScenario()
    builderFailureScenario()
end

local function cleanup()
    restoreRegistry()
    restoreLogger()
    package.loaded['hsLauncher.main.init'] = nil
    package.loaded['hsLauncher.main.runtime.init'] = nil
end

local ok, err = xpcall(run, debug.traceback)
cleanup()
if not ok then
    error(err)
end

print('[PASS] hsLauncher start failure diagnostics')

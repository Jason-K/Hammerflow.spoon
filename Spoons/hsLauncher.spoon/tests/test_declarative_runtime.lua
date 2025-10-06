local scriptPath = debug.getinfo(1, "S").source:sub(2)
if scriptPath:sub(1, 1) ~= '/' then
    local cwd = assert(io.popen('pwd'):read('*l'), 'Unable to determine working directory')
    scriptPath = cwd .. '/' .. scriptPath
end
local testDir = scriptPath:match('(.*/)')
assert(testDir, 'Unable to determine test directory from ' .. tostring(scriptPath))
local projectRoot = testDir:gsub('/tests/?$', '/')
local parentRoot = projectRoot:gsub('/[^/]+/?$', '/')

local pathParts = {
    projectRoot .. '?.lua',
    projectRoot .. '?/init.lua',
    projectRoot .. 'main/?.lua',
    projectRoot .. 'main/?/init.lua',
    parentRoot .. '?.lua',
    parentRoot .. '?/init.lua',
    parentRoot .. 'main/?.lua',
    parentRoot .. 'main/?/init.lua',
    package.path,
}
package.path = table.concat(pathParts, ';')

local loaderRegistered = false

local function registerHsLauncherLoader(root)
    if package.__hslauncher_loader ~= nil then return end
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
    package.__hslauncher_loader = true
end

registerHsLauncherLoader(projectRoot)

require('tests.fixtures.legacy_user_actions').install()

if package.preload['hs.fs'] == nil then
    package.preload['hs.fs'] = function()
        return {
            attributes = function()
                return nil
            end,
            mkdir = function()
                return true
            end,
            touch = function()
                return true
            end,
            pathToAbsolute = function(path)
                return path
            end,
            dir = function()
                return function()
                    return nil
                end
            end,
        }
    end
end

if package.preload['hs.json'] == nil then
    package.preload['hs.json'] = function()
        return {
            encode = function()
                return '{}'
            end,
            decode = function()
                return nil, 'not implemented'
            end,
        }
    end
end

if package.preload['hs.pasteboard'] == nil then
    package.preload['hs.pasteboard'] = function()
        return {
            getContents = function()
                return ''
            end,
            writeObjects = function() end,
        }
    end
end

if package.preload['hs.application'] == nil then
    package.preload['hs.application'] = function()
        local frontmost = {
            name = function()
                return 'Finder'
            end,
            bundleID = function()
                return 'com.apple.finder'
            end,
        }
        return {
            get = function()
                return frontmost
            end,
            frontmostApplication = function()
                return frontmost
            end,
        }
    end
end

if package.preload['hs.eventtap'] == nil then
    package.preload['hs.eventtap'] = function()
        return {
            checkKeyboardModifiers = function()
                return {}
            end,
            keyStroke = function() end,
            event = {
                types = {},
            },
        }
    end
end

if package.preload['hs.chooser'] == nil then
    package.preload['hs.chooser'] = function()
        local chooser = {}
        chooser.__index = chooser
        function chooser.new(callback)
            return setmetatable({ _callback = callback }, chooser)
        end

        function chooser:choices()
            return self
        end

        function chooser:searchSubText()
            return self
        end

        function chooser:placeholderText()
            return self
        end

        function chooser:width()
            return self
        end

        function chooser:show()
            return self
        end

        return chooser
    end
end

if package.preload['hs.alert'] == nil then
    package.preload['hs.alert'] = function()
        return {
            show = function() end,
        }
    end
end

if not _G.hs then _G.hs = {} end
hs.execute = hs.execute or function()
    return true
end

local function ensurePreload(name, factory)
    if package.preload[name] ~= nil then return end
    package.preload[name] = factory
end

ensurePreload('hsLauncher.main.core.logger', function()
    local function noop()
    end
    local logs = { info = {}, warn = {}, error = {} }
    local function record(level, message)
        logs[level][#logs[level] + 1] = message
    end
    return {
        info = function(message)
            record('info', message)
        end,
        warn = function(message)
            record('warn', message)
        end,
        error = function(message)
            record('error', message)
        end,
        history = logs,
        flush = noop,
    }
end)

ensurePreload('hsLauncher.main.core.action_runner', function()
    return {
        exec = function()
        end,
    }
end)

ensurePreload('hsLauncher.main.core.windows_native', function()
    return setmetatable({}, {
        __index = function(_, key)
            return function()
                return key
            end
        end,
    })
end)

ensurePreload('hsLauncher.main.modules.hotkeys.assign_hotkey', function()
    return {
        assign = function() end,
    }
end)

ensurePreload('hsLauncher.main.modules.hotkeys.assign_global', function()
    return {
        assignForFrontmost = function() end,
        removeForFrontmost = function() end,
        listForFrontmost = function()
            return {}
        end,
    }
end)

ensurePreload('hsLauncher.main.core.hyper_modal', function()
    return {
        exitMode = function() end,
        defineMode = function() end,
        addSequence = function() end,
        enterMode = function() end,
        bind = function() end,
    }
end)

ensurePreload('hsLauncher.main.core.window_history', function()
    return {}
end)

ensurePreload('hsLauncher.main.core.window_geometry', function()
    return {}
end)

ensurePreload('hsLauncher.main.core.window_neighbors', function()
    return {}
end)

ensurePreload('hsLauncher.main.core.modal_gui', function()
    return {
        show = function() end,
        hide = function() end,
    }
end)

ensurePreload('hsLauncher.main.core.config', function()
    return {}
end)

local function registerHsLauncherLoader(root)
    if loaderRegistered then return end
    local loader = function(moduleName)
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
    end
    table.insert(package.searchers, 2, loader)
    loaderRegistered = true
end

registerHsLauncherLoader(projectRoot)

local function ensurePreload(name, factory)
    if package.preload[name] == nil then
        package.preload[name] = factory
    end
end

ensurePreload('hs.fs', function()
    return {
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
    }
end)

ensurePreload('hsLauncher.main.core.logger', function()
    return {
        info = function() end,
        warn = function() end,
        error = function() end,
    }
end)

ensurePreload('hsLauncher.main.core.window_history', function()
    return {}
end)

ensurePreload('hsLauncher.main.core.window_geometry', function()
    return {}
end)

ensurePreload('hsLauncher.main.core.window_neighbors', function()
    return {}
end)

ensurePreload('hsLauncher.main.core.modal_gui', function()
    return { show = function() end, hide = function() end }
end)

ensurePreload('hsLauncher.main.core.hyper_modal', function()
    return {
        exitMode = function() end,
    }
end)

ensurePreload('hsLauncher.main.core.windows_native', function()
    return {}
end)

ensurePreload('hsLauncher.main.modules.hotkeys.assign_hotkey', function()
    return {
        assign = function() end,
    }
end)

ensurePreload('hsLauncher.main.modules.hotkeys.assign_global', function()
    return {
        assignForFrontmost = function() end,
        removeForFrontmost = function() end,
        listForFrontmost = function()
            return {}
        end,
    }
end)

ensurePreload('hsLauncher.main.core.action_runner', function()
    return {
        exec = function() end,
    }
end)

local Runtime = require('hsLauncher.main.runtime.init')
local Registry = require('hsLauncher.main.user.registry')

local function assertTrue(value, message)
    if not value then
        error(message or 'assertTrue failed')
    end
end

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(string.format('%s\nexpected: %s\nactual: %s', message or 'assertEquals failed', tostring(expected),
            tostring(actual)))
    end
end

local function fakeRegistrar()
    local adapter = {
        contexts = {},
        teardownCalls = 0,
    }
    function adapter:registerContext(contextId, assignments)
        self.contexts[#self.contexts + 1] = {
            context = contextId,
            assignments = #(assignments or {}),
        }
        return {
            bindings = {},
            assignments = assignments,
        }
    end

    function adapter:teardownAll()
        self.teardownCalls = self.teardownCalls + 1
        return 0
    end

    return adapter
end

local function resetRuntime()
    Runtime.stop()
end

local function runHappyPath()
    resetRuntime()
    local state = Registry.load({
        featureFlags = {
            menuBuilder = true,
        },
    })
    assertTrue(state and state.loader and state.loader.ok, 'config loader should succeed for declarative runtime')
    assertTrue(state.builder and state.builder.ok, 'menu builder should succeed for declarative runtime')

    local sampleAction = {
        name = 'runtime.testAction',
        description = 'Runtime Test Action',
        actions = {
            function() end,
        },
        hotkey = {
            trigger = {
                keys = {
                    {
                        key = 'r',
                        mods = { 'cmd' },
                    },
                },
            },
        },
        menuDetails = {
            description = 'Runtime Test Action',
        },
    }

    local rootMenu = {
        id = 'globalRoot',
        title = 'Runtime Test',
        items = {
            {
                id = sampleAction.name,
                type = 'action',
                label = 'Runtime Test Action',
                description = 'Runtime Test Action',
                shortcut = 'cmd+r',
                menu = { id = 'globalRoot' },
                action = sampleAction,
            },
        },
        subMenuIds = {},
    }

    local mockedDeclarative = {
        state = state,
        loader = {
            ok = true,
            actions = { sampleAction },
        },
        builder = {
            ok = true,
            root = rootMenu,
            menus = {
                globalRoot = rootMenu,
            },
        },
        diagnostics = {
            errors = {},
            warnings = {},
            conflicts = {},
        },
        features = state.features,
        legacy = {
            menuOrder = {},
        },
    }

    local originalDeclarativeState = Registry.declarativeState

    local ok, resultErr = pcall(function()
        Registry.declarativeState = function()
            return mockedDeclarative
        end

        local registrar = fakeRegistrar()
        local instance, err = Runtime.start({ registrar = registrar })
        assertTrue(instance ~= nil, 'runtime should start successfully')
        assertTrue(err == nil, 'runtime should not return an error on success')

        local summary = Runtime.summary()
        assertTrue(type(summary) == 'table' and #summary > 0, 'runtime summary should include registered contexts')
        assertEquals(registrar.teardownCalls, 0, 'registrar should not be torn down before stop')

        Runtime.stop()
        assertEquals(registrar.teardownCalls, 1, 'registrar teardown should be called during stop')
        assertTrue(Runtime.current() == nil, 'runtime current state should be cleared after stop')
    end)

    Registry.declarativeState = originalDeclarativeState
    if not ok then error(resultErr) end
end

local function runFailurePath()
    resetRuntime()
    local original = Registry.declarativeState
    Registry.declarativeState = function()
        return nil
    end

    local instance, err = Runtime.start()
    assertTrue(instance == nil, 'runtime should not start when declarative state is unavailable')
    assertTrue(type(err) == 'string' and err ~= '', 'runtime should return an error message when start fails')

    Registry.declarativeState = original
end

local function main()
    runHappyPath()
    runFailurePath()
    print('[PASS] Declarative runtime start/stop behavior')
end

main()

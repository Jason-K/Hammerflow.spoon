local Logger = require('hsLauncher.main.core.logger')
local userRegistry = require('hsLauncher.main.user.registry')
local HotkeyResolver = require('hsLauncher.main.runtime.hyper.hotkey_resolver')
local Dispatcher = require('hsLauncher.main.runtime.hyper.dispatcher')
local MenuUI = require('hsLauncher.main.runtime.menu.ui')
local MenuSequences = require('hsLauncher.main.runtime.menu.sequences')

local Runtime = {}
local active

local function log(level, message)
    if not Logger then return end
    local handler = Logger[level]
    if type(handler) == 'function' then
        handler(message)
    end
end

local function ensureDeclarativeState()
    local state = userRegistry.declarativeState()
    if not state then return nil, 'declarative state unavailable' end
    local loader = state.loader or {}
    if not loader.ok then
        return nil, 'config loader did not complete successfully'
    end
    local builder = state.builder or {}
    if not builder.ok then
        return nil, 'menu builder did not complete successfully'
    end
    return {
        state = state,
        loader = loader,
        builder = builder,
    }
end

local function registerHotkeys(resolution, options)
    local dispatcher = Dispatcher.new(resolution or {}, {
        logger = options and options.logger or Logger,
        registrar = options and options.registrar,
        registrarOptions = options and options.registrarOptions,
    })
    dispatcher:registerAll()
    return dispatcher
end

---@param options table|nil
---@return table|nil, string|nil
function Runtime.start(options)
    if active then
        Runtime.stop()
    end
    local declarative, err = ensureDeclarativeState()
    if not declarative then
        return nil, err
    end

    local resolution = HotkeyResolver.resolve(declarative.loader.actions or {}, options and options.hotkeyOptions or nil)
    local dispatcher = registerHotkeys(resolution, options)
    local ui = MenuUI.new(declarative.builder)
    local sequences = MenuSequences.new(declarative.builder)

    active = {
        options = options or {},
        state = declarative.state,
        loader = declarative.loader,
        builder = declarative.builder,
        resolution = resolution,
        dispatcher = dispatcher,
        ui = ui,
        sequences = sequences,
    }

    log('info', 'hsLauncher declarative runtime started')
    return active
end

function Runtime.stop()
    if not active then return end
    local dispatcher = active.dispatcher
    if dispatcher and type(dispatcher.teardown) == 'function' then
        dispatcher:teardown()
    end
    log('info', 'hsLauncher declarative runtime stopped')
    active = nil
end

function Runtime.current()
    return active
end

function Runtime.summary()
    if not active or not active.dispatcher then return {} end
    if type(active.dispatcher.summary) == 'function' then
        return active.dispatcher:summary()
    end
    return {}
end

function Runtime.menu()
    return active and active.ui or nil
end

function Runtime.show(menuId, options)
    if not active or not active.ui then return nil, 'runtime inactive' end
    return active.ui:show(menuId, options)
end

function Runtime.sequences(menuId)
    if not active or not active.sequences then return {} end
    if menuId then
        return active.sequences:forMenu(menuId)
    end
    return active.sequences:allSequences()
end

return Runtime

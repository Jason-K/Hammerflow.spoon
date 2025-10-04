-- hsLauncher/core/actions.lua
-- Centralized action constructors and resolvers for mode bindings

local logger = require('hsLauncher.main.core.logger')
local Mods = require('hsLauncher.main.core.mods')

local Actions = {}

local function lazyRequire(path)
	local ok, mod = pcall(require, path)
	if not ok then
		logger.error(string.format('actions: require failed for %s -> %s', tostring(path), tostring(mod)))
		return nil
	end
	return mod
end

local handlerCache

local function buildHandlerContext()
	return {
		hyper = lazyRequire('hsLauncher.main.core.hyper_modal'),
		win = lazyRequire('hsLauncher.main.core.windows_native'),
		hsWindow = lazyRequire('hs.window'),
		assignHotkey = lazyRequire('hsLauncher.main.modules.hotkeys.assign_hotkey'),
		assignGlobal = lazyRequire('hsLauncher.main.modules.hotkeys.assign_global'),
		logger = logger,
		userRegistry = lazyRequire('hsLauncher.main.user.registry'),
	}
end

local function loadHandlers()
	if handlerCache ~= nil then return handlerCache end
	local builder = lazyRequire('hsLauncher.main.modules.hotkeys.handlers')
	if not builder then
		handlerCache = {}
		return handlerCache
	end
	local ok, handlers = pcall(builder, buildHandlerContext())
	if not ok then
		logger.error('actions: failed to build handler registry -> ' .. tostring(handlers))
		handlerCache = {}
		return handlerCache
	end
	handlerCache = handlers or {}
	return handlerCache
end

local function wrapSafe(fn, label)
	return function (...)
		local ok, err = pcall(fn, ...)
		if not ok then
			logger.error(string.format('actions: %s failed -> %s', label or 'callback', tostring(err)))
		end
	end
end

local resolvers = {}

local function register(kind, handler)
	resolvers[kind] = handler
end

register('function', function (action)
	return action.fn
end)

register('module_fn', function (action)
	return function ()
		local mod = lazyRequire(action.module)
		if not mod then return end
		local fn = mod[action.method]
		if type(fn) ~= 'function' then
			logger.error(string.format('actions: method %s.%s missing or not callable', tostring(action.module),
									   tostring(action.method)))
			return
		end
		fn(table.unpack(action.args or {}))
	end
end)

register('exec', function (action)
	return function ()
		local Act = lazyRequire('hsLauncher.main.core.action_runner')
		if not Act or type(Act.exec) ~= 'function' then return end
		Act.exec(action.spec)
	end
end)

register('exit', function (_)
	return function ()
		local modal = lazyRequire('hsLauncher.main.core.hyper_modal')
		if not modal or type(modal.exitMode) ~= 'function' then return end
		modal.exitMode()
	end
end)

register('noop', function (_) return function () end end)

register('sequence', function (action)
	return function ()
		for _, sub in ipairs(action.steps or {}) do
			local fn = Actions.resolve(sub)
			if fn then fn() end
		end
	end
end)

register('handler', function (action)
	local handlers = loadHandlers()
	local name = action.name or action.id or action.handler
	if not name or name == '' then
		logger.error('actions: handler spec missing name')
		return nil
	end
	local factory = handlers and handlers[name]
	if not factory then
		logger.error('actions: unknown handler ' .. tostring(name))
		return nil
	end
	local spec = factory(action.args or action.parameters or action.params)
	if not spec then
		logger.error('actions: handler ' .. tostring(name) .. ' returned nil spec')
		return nil
	end
	if spec == action then
		logger.error('actions: handler ' .. tostring(name) .. ' returned its own spec')
		return nil
	end
	return Actions.resolve(spec)
end)

function Actions.call(fn)
	assert(type(fn) == 'function', 'Actions.call expects function')
	return { kind = 'function', fn = fn }
end

function Actions.moduleFn(modulePath, methodName, args)
	assert(type(modulePath) == 'string', 'Actions.moduleFn expects module path string')
	assert(type(methodName) == 'string', 'Actions.moduleFn expects method name string')
	return { kind = 'module_fn', module = modulePath, method = methodName, args = args }
end

function Actions.exec(spec)
	assert(type(spec) == 'table', 'Actions.exec expects action spec table')
	return { kind = 'exec', spec = spec }
end

function Actions.exit()
	return { kind = 'exit' }
end

function Actions.noop()
	return { kind = 'noop' }
end

function Actions.sequence(steps)
	assert(type(steps) == 'table', 'Actions.sequence expects steps table')
	return { kind = 'sequence', steps = steps }
end

function Actions.resolve(action)
	if not action then return nil end
	if type(action) == 'function' then return wrapSafe(action, 'function action') end
	if type(action) == 'table' then
		local kind = action.kind or action.__action
		local handler = kind and resolvers[kind]
		if handler then
			local fn = handler(action)
			if fn then return wrapSafe(fn, kind .. ' action') end
		end
	end
	local extra = ''
	if type(action) == 'table' then
		local kind = action.kind or action.__action
		if kind then extra = string.format(' (kind=%s)', tostring(kind)) end
		local keys = {}
		for k, _ in pairs(action) do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		if #keys > 0 then
			extra = string.format('%s keys=[%s]', extra, table.concat(keys, ','))
		end
	end
	logger.error(string.format('actions: unable to resolve action of type %s%s', type(action), extra))
	return nil
end

-- Convenience helpers for common modules

local function requireString(value, name)
	assert(type(value) == 'string' and value ~= '', string.format('%s must be a non-empty string', name))
	return value
end

local function requireTable(value, name)
	assert(type(value) == 'table', string.format('%s must be a table', name))
	return value
end

function Actions.keystroke(key, mods)
	requireString(key, 'Actions.keystroke key')
	local normalizedMods = nil
	if mods ~= nil then
		local modType = type(mods)
		assert(modType == 'table' or modType == 'string', 'Actions.keystroke mods must be table or string when provided')
		normalizedMods = Mods.normalizeMods(mods)
	end
	return Actions.exec({ type = 'keystroke', key = key, mods = normalizedMods })
end

function Actions.open(target)
	requireTable(target, 'Actions.open target')
	return Actions.exec({ type = 'open', target = target })
end

function Actions.shell(cmd)
	requireString(cmd, 'Actions.shell command')
	return Actions.exec({ type = 'shell', cmd = cmd })
end

function Actions.applescript(scriptPath)
	requireString(scriptPath, 'Actions.applescript scriptPath')
	return Actions.exec({ type = 'applescript', script_path = scriptPath })
end

function Actions.hsFunction(name, args)
	requireString(name, 'Actions.hsFunction name')
	if args ~= nil then requireTable(args, 'Actions.hsFunction args') end
	return Actions.exec({ type = 'hs_function', name = name, args = args })
end

function Actions.sequenceExec(specs)
	requireTable(specs, 'Actions.sequenceExec specs')
	local steps = {}
	for index, spec in ipairs(specs) do
		requireTable(spec, string.format('Actions.sequenceExec step %d', index))
		steps[index] = Actions.exec(spec)
	end
	return Actions.sequence(steps)
end

function Actions.window(methodName)
	return Actions.moduleFn('hsLauncher.main.core.windows_native', methodName)
end

function Actions.enterMode(modeName)
	requireString(modeName, 'Actions.enterMode modeName')
	return Actions.moduleFn('hsLauncher.main.core.hyper_modal', 'enterMode', { modeName })
end

function Actions.assignHotkey()
	return Actions.moduleFn('hsLauncher.main.modules.hotkeys.assign_hotkey', 'assign')
end

function Actions.assignGlobal()
	return Actions.moduleFn('hsLauncher.main.modules.hotkeys.assign_global', 'assignForFrontmost')
end

function Actions.removeGlobal()
	return Actions.moduleFn('hsLauncher.main.modules.hotkeys.assign_global', 'removeForFrontmost')
end

function Actions.listGlobals()
	return Actions.moduleFn('hsLauncher.main.modules.hotkeys.assign_global', 'listForFrontmost')
end

function Actions.invalidateHandlers()
	handlerCache = nil
end

return Actions

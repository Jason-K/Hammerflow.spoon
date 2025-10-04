--- @diagnostic disable: undefined-global
local Actions = require('hsLauncher.main.core.actions')
local fs = require('hsLauncher.main.core.fs')

local ModuleActions = {}

local function copyOptions(opts)
	if not opts then return {} end
	local out = {}
	for k, v in pairs(opts) do out[k] = v end
	return out
end

local function base(label, opts)
	assert(type(label) == 'string' and label ~= '', 'ModuleActions: label must be a non-empty string')
	local spec = {
		label = label,
		description = label,
	}
	if opts then
		if opts.description then spec.description = opts.description end
		if opts.note ~= nil then spec.note = opts.note end
		if opts.section ~= nil then spec.section = opts.section end
		if opts.exitAfter ~= nil then spec.exitAfter = opts.exitAfter end
		if opts.badge ~= nil then spec.badge = opts.badge end
		if opts.defaultKey ~= nil then spec.defaultKey = opts.defaultKey end
		if opts.tags ~= nil then spec.tags = opts.tags end
		if opts.metadata ~= nil then spec.metadata = opts.metadata end
	end
	return spec
end

local function ensureExitAfter(spec, defaultValue)
	if spec.exitAfter == nil then spec.exitAfter = defaultValue end
end

local function normalizeTarget(target)
	if target == nil then return nil end
	if type(target) == 'string' then
		return { path = fs.expandUser(target) }
	end
	assert(type(target) == 'table', 'ModuleActions.open target must be string or table')
	local out = {}
	if target.path or target.appPath or target.application then
		out.path = fs.expandUser(target.path or target.appPath or target.application)
	end
	if target.bundleId or target.bundle_id then
		out.bundle_id = target.bundleId or target.bundle_id
	end
	if target.appName or target.app_name then
		out.app_name = target.appName or target.app_name
	end
	if target.url then out.url = target.url end
	return out
end

function ModuleActions.shell(label, command, opts)
	assert(type(command) == 'string' and command ~= '', 'ModuleActions.shell requires a non-empty command string')
	local spec = base(label, opts)
	spec.actionSpec = Actions.shell(command)
	if spec.note == nil then spec.note = command end
	ensureExitAfter(spec, true)
	return spec
end

function ModuleActions.exec(label, execSpec, opts)
	assert(type(execSpec) == 'table', 'ModuleActions.exec requires an exec spec table')
	local spec = base(label, opts)
	spec.actionSpec = Actions.exec(execSpec)
	ensureExitAfter(spec, true)
	return spec
end

function ModuleActions.url(label, url, opts)
	assert(type(url) == 'string' and url ~= '', 'ModuleActions.url requires a non-empty url string')
	local spec = base(label, opts)
	spec.actionSpec = Actions.open({ url = url })
	if spec.note == nil then spec.note = url end
	ensureExitAfter(spec, true)
	return spec
end

function ModuleActions.open(label, target, opts)
	local normalized = normalizeTarget(target)
	assert(normalized and (normalized.path or normalized.bundle_id or normalized.app_name or normalized.url),
		'ModuleActions.open requires a path, bundleId, appName, or url')
	local spec = base(label, opts)
	spec.actionSpec = Actions.open(normalized)
	ensureExitAfter(spec, true)
	return spec
end

function ModuleActions.openApp(label, target, opts)
	return ModuleActions.open(label, target, opts)
end

function ModuleActions.openWithApplication(label, applicationName, path, opts)
	assert(type(applicationName) == 'string' and applicationName ~= '',
		'ModuleActions.openWithApplication requires applicationName')
	local command = string.format([[open -a %q]], applicationName)
	if path and path ~= '' then
		command = string.format('%s %q', command, fs.expandUser(path))
	end
	return ModuleActions.shell(label, command, opts)
end

function ModuleActions.openWithBundle(label, path, bundleId, opts)
	assert(type(path) == 'string' and path ~= '', 'ModuleActions.openWithBundle requires path')
	assert(type(bundleId) == 'string' and bundleId ~= '', 'ModuleActions.openWithBundle requires bundleId')
	local command = string.format([[open %q -b %q]], fs.expandUser(path), bundleId)
	return ModuleActions.shell(label, command, opts)
end

function ModuleActions.openPath(label, path, opts)
	assert(type(path) == 'string' and path ~= '', 'ModuleActions.openPath requires path')
	local command = string.format([[open %q]], fs.expandUser(path))
	return ModuleActions.shell(label, command, opts)
end

function ModuleActions.python(label, scriptPath, opts)
	opts = opts or {}
	assert(type(scriptPath) == 'string' and scriptPath ~= '', 'ModuleActions.python requires scriptPath')
	local python = opts.python or 'python3'
	local parts = { python, string.format('%q', fs.expandUser(scriptPath)) }
	local args = opts.args
	if args then
		if type(args) == 'table' then
			for _, arg in ipairs(args) do table.insert(parts, arg) end
		else
			table.insert(parts, args)
		end
	end
	local specOpts = copyOptions(opts)
	specOpts.args = nil
	specOpts.python = nil
	local command = table.concat(parts, ' ')
	return ModuleActions.shell(label, command, specOpts)
end

function ModuleActions.call(label, fn, opts)
	assert(type(fn) == 'function', 'ModuleActions.call requires a function')
	local spec = base(label, opts)
	spec.actionSpec = Actions.call(fn)
	ensureExitAfter(spec, false)
	return spec
end

function ModuleActions.moduleFn(label, modulePath, methodName, args, opts)
	assert(type(modulePath) == 'string' and modulePath ~= '', 'ModuleActions.moduleFn requires modulePath')
	assert(type(methodName) == 'string' and methodName ~= '', 'ModuleActions.moduleFn requires methodName')
	local spec = base(label, opts)
	spec.actionSpec = Actions.moduleFn(modulePath, methodName, args)
	ensureExitAfter(spec, false)
	return spec
end

function ModuleActions.fromSpec(label, actionSpec, opts)
	assert(type(actionSpec) == 'table', 'ModuleActions.fromSpec requires actionSpec table')
	local spec = base(label, opts)
	spec.actionSpec = actionSpec
	ensureExitAfter(spec, false)
	return spec
end

function ModuleActions.textProcessorFactory(scriptPath, factoryOpts)
	factoryOpts = factoryOpts or {}
	assert(type(scriptPath) == 'string' and scriptPath ~= '', 'textProcessorFactory requires scriptPath')
	local python = factoryOpts.python or 'python3'
	local defaultTail = factoryOpts.defaultTail or '--source clipboard --dest paste'
	local defaults = factoryOpts.defaults or {}
	local expandedScript = fs.expandUser(scriptPath)
	return function (label, commandName, extraArgs, actionOpts)
		assert(type(commandName) == 'string' and commandName ~= '', 'textProcessorFactory action requires commandName')
		local parts = { commandName }
		if extraArgs then
			if type(extraArgs) == 'table' then
				for _, arg in ipairs(extraArgs) do table.insert(parts, arg) end
			else
				table.insert(parts, extraArgs)
			end
		end
		local argsString = table.concat(parts, ' ')
		local command = string.format('%s %q %s', python, expandedScript, argsString)
		if defaultTail and defaultTail ~= '' and not argsString:find('%-%-source') then
			command = command .. ' ' .. defaultTail
		end
		local mergedOpts = copyOptions(defaults)
		if actionOpts then
			for k, v in pairs(actionOpts) do mergedOpts[k] = v end
		end
		return ModuleActions.shell(label, command, mergedOpts)
	end
end

function ModuleActions.buildMap(definitions, builder)
	assert(type(definitions) == 'table', 'ModuleActions.buildMap requires definitions table')
	assert(type(builder) == 'function', 'ModuleActions.buildMap requires builder function')
	local actions = {}
	for _, def in ipairs(definitions) do
		assert(def.id, 'ModuleActions.buildMap requires each definition to include an id')
		local spec = builder(def)
		if spec then actions[def.id] = spec end
	end
	return actions
end

return ModuleActions

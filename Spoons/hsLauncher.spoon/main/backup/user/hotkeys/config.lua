--- @diagnostic disable: undefined-global

local logger = require('hsLauncher.main.core.logger')
local fs = require('hs.fs')

local function loadUserConfig()
	local ok, cfg = pcall(require, 'hsLauncher.main.user.config')
	if not ok then
		logger.error('hotkeys.config: unable to load user config -> ' .. tostring(cfg))
		return {}
	end
	if type(cfg) ~= 'table' then
		logger.error('hotkeys.config: user config must return a table')
		return {}
	end
	return cfg
end

local function scriptDirectory()
	local source = debug.getinfo(1, 'S').source or ''
	local path = source:match('^@(.*/)')
	return path
end

local function appendUnique(list, value)
	for _, existing in ipairs(list) do
		if existing == value then return end
	end
	list[#list + 1] = value
end

local function normalizeContextName(name)
	if type(name) ~= 'string' then return nil end
	local trimmed = name:match('^%s*(.-)%s*$') or ''
	if trimmed == '' then return nil end
	return trimmed:lower()
end

local function discoverContexts()
	local dir = scriptDirectory()
	if not dir then return {} end
	if type(fs) ~= 'table' or type(fs.dir) ~= 'function' then return {} end
	local found = {}
	for file in fs.dir(dir) do
		if file ~= '.' and file ~= '..' then
			local name = file:match('^hotkeys_(.+)%.lua$')
			if name and name ~= 'config' then
				local normalized = normalizeContextName(name)
				if normalized then appendUnique(found, normalized) end
			end
		end
	end
	table.sort(found)
	return found
end

local function determineContexts()
	local cfg = loadUserConfig()
	local declared = cfg.hotkeys and cfg.hotkeys.contexts
	local resolved = {}
	if type(declared) == 'table' then
		for _, name in ipairs(declared) do
			local normalized = normalizeContextName(name)
			if normalized then
				appendUnique(resolved, normalized)
			end
		end
	end
	if #resolved == 0 then
		for _, name in ipairs(discoverContexts()) do appendUnique(resolved, name) end
	end
	appendUnique(resolved, 'global')
	for index, name in ipairs(resolved) do
		if name == 'global' and index ~= 1 then
			table.remove(resolved, index)
			table.insert(resolved, 1, 'global')
			break
		end
	end
	return resolved
end

local contexts = determineContexts()

local function shallowCopy(tbl)
	if type(tbl) ~= 'table' then return tbl end
	local out = {}
	for k, v in pairs(tbl) do out[k] = v end
	return out
end

local function copyArray(list)
	if type(list) ~= 'table' then return {} end
	local out = {}
	for index, value in ipairs(list) do
		out[index] = shallowCopy(value)
	end
	return out
end

local function mergeContext(into, ctx, name)
	local sourceLabel = string.format('hotkeys_%s', name or ctx.id or 'context')

	for _, binding in ipairs(ctx.hyperBindings or {}) do
		local copy = shallowCopy(binding)
		copy.source = copy.source or sourceLabel
		table.insert(into.hyperBindings, copy)
	end

	for modeName, modeDef in pairs(ctx.modes or {}) do
		if into.modes[modeName] then
			logger.warn(string.format('hotkeys.config: mode %s already defined, keeping first definition', modeName))
		else
			into.modes[modeName] = shallowCopy(modeDef)
		end
	end

	for _, seq in ipairs(ctx.sequences or {}) do
		local copy = shallowCopy(seq)
		copy.source = copy.source or sourceLabel
		table.insert(into.sequences, copy)
	end

	for _, app in ipairs(ctx.apps or {}) do
		local copy = shallowCopy(app)
		if copy.entries then copy.entries = copyArray(copy.entries) end
		if copy.triggers then copy.triggers = copyArray(copy.triggers) end
		table.insert(into.apps, copy)
	end
end

local merged = {
	hyperBindings = {},
	modes = {},
	sequences = {},
	apps = {},
}

for _, name in ipairs(contexts) do
	local moduleName = 'hsLauncher.main.user.hotkeys.hotkeys_' .. name
	local ok, ctx = pcall(require, moduleName)
	if not ok then
		logger.error(string.format('hotkeys.config: failed to load %s -> %s', moduleName, tostring(ctx)))
	elseif type(ctx) ~= 'table' then
		logger.error(string.format('hotkeys.config: module %s must return a table', moduleName))
	else
		mergeContext(merged, ctx, name)
	end
end

return merged

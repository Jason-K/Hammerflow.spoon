local M = {}
local json = require('hs.json')
local log = require('hsLauncher.main.core.logger')
local fs = require('hsLauncher.main.core.fs')
local BasePaths = require('hsLauncher.main.core.base_paths')
local Combos = require('hsLauncher.main.modules.hotkeys.combo_utils')

local registryPath = BasePaths.runtimeFile('logs', 'hotkey_registry.json')

local state = {
	global = { reserved = {}, assigned = {} },
	hs = { bindings = {} },
	perApp = {},
	chassisOrder = {},
}

local comboKey = Combos.comboKey

local function deepCopy(value)
	if type(value) ~= 'table' then return value end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function mergeInto(dest, source)
	if type(dest) ~= 'table' or type(source) ~= 'table' then return end
	for key, value in pairs(source) do
		if type(value) == 'table' then
			dest[key] = deepCopy(value)
		else
			dest[key] = value
		end
	end
end

local function loadFromDisk(path)
	local data, err = fs.readFile(path)
	if not data then return nil, err end
	local ok, decoded = pcall(json.decode, data)
	if not ok then return nil, decoded end
	if type(decoded) ~= 'table' then return nil, 'not-table' end
	return decoded
end

local function saveToDisk(path, payload)
	local ok, encoded = pcall(json.encode, payload, true)
	if not ok then return nil, encoded end
	local okWrite, err = fs.writeFile(path, encoded)
	if not okWrite then return nil, err end
	return true
end

local function ensureGlobalState()
	state.global = state.global or { reserved = {}, assigned = {} }
	state.global.reserved = state.global.reserved or {}
	state.global.assigned = state.global.assigned or {}
	state.hs = state.hs or { bindings = {} }
	state.hs.bindings = state.hs.bindings or {}
	state.perApp = state.perApp or {}
end

function M.path()
	return registryPath
end

function M.load()
	local decoded, err = loadFromDisk(registryPath)
	if decoded then
		state = decoded
		ensureGlobalState()
		return true
	end
	if err and err ~= 'no-path' then
		log.error('hotkey_registry load failed: ' .. tostring(err))
	end
	ensureGlobalState()
	return false
end

function M.save()
	ensureGlobalState()
	local ok, err = saveToDisk(registryPath, state)
	if not ok then
		log.error('hotkey_registry save failed: ' .. tostring(err))
		return false
	end
	return true
end

function M.init(defaults)
	M.load()
	state.chassisOrder = defaults and defaults.chassisOrder or state.chassisOrder or {}
	ensureGlobalState()
	local seed = defaults and defaults.reservedGlobals or {}
	local reserved = state.global.reserved
	local seen = {}
	for _, combo in ipairs(reserved) do seen[combo] = true end
	for _, combo in ipairs(seed) do
		if not seen[combo] then
			table.insert(reserved, combo)
			seen[combo] = true
		end
	end
	M.save()
end

function M.reserveGlobal(mods, key)
	ensureGlobalState()
	local ck = comboKey(mods, key)
	for _, existing in ipairs(state.global.reserved) do
		if existing == ck then return end
	end
	table.insert(state.global.reserved, ck)
	M.save()
end

function M.registerHS(mods, key, name)
	ensureGlobalState()
	local ck = comboKey(mods, key)
	state.hs.bindings[ck] = name or true
	M.save()
end

function M.registerApp(bundleID, mods, key, name)
	ensureGlobalState()
	state.perApp[bundleID] = state.perApp[bundleID] or { assigned = {}, reserved = {} }
	local ck = comboKey(mods, key)
	state.perApp[bundleID].assigned[ck] = name or true
	M.save()
end

function M.isReservedGlobal(combo)
	ensureGlobalState()
	for _, existing in ipairs(state.global.reserved) do
		if existing == combo then return true end
	end
	return false
end

function M.isUsedByHS(combo)
	ensureGlobalState()
	return state.hs.bindings[combo] ~= nil
end

function M.isUsedByApp(bundleID, combo)
	ensureGlobalState()
	local appEntry = state.perApp[bundleID]
	if not appEntry then return false end
	return (appEntry.assigned or {})[combo] ~= nil
end

function M.isFree(bundleID, mods, key)
	local ck = comboKey(mods, key)
	if M.isReservedGlobal(ck) then return false, 'global-reserved' end
	if M.isUsedByHS(ck) then return false, 'hs-used' end
	if bundleID and M.isUsedByApp(bundleID, ck) then return false, 'app-used' end
	return true
end

function M.comboKey(mods, key)
	return comboKey(mods, key)
end

function M.normalizeMods(mods)
	return Combos.normalizeMods(mods)
end

function M.normalizeKey(key)
	return Combos.normalizeKey(key)
end

function M.registerGlobal(mods, key, info)
	ensureGlobalState()
	local ck = comboKey(mods, key)
	local existing = state.global.assigned[ck]
	if type(existing) == 'table' then
		mergeInto(existing, info or {})
	elseif info ~= nil then
		if type(info) == 'table' then
			state.global.assigned[ck] = deepCopy(info)
		else
			state.global.assigned[ck] = info
		end
	else
		state.global.assigned[ck] = true
	end
	M.save()
end

function M.getGlobal(mods, key)
	ensureGlobalState()
	local ck = comboKey(mods, key)
	local entry = state.global.assigned[ck]
	if type(entry) == 'table' then
		return deepCopy(entry)
	end
	return entry
end

function M.setGlobalScript(mods, key, scriptInfo)
	ensureGlobalState()
	local ck = comboKey(mods, key)
	local entry = state.global.assigned[ck]
	if type(entry) ~= 'table' then
		if not scriptInfo then return end
		entry = {}
		state.global.assigned[ck] = entry
	end
	if scriptInfo then
		entry.script = deepCopy(scriptInfo)
	else
		entry.script = nil
	end
	M.save()
end

function M.getGlobals(bundle)
	ensureGlobalState()
	local results = {}
	for combo, record in pairs(state.global.assigned) do
		if type(record) == 'table' and record.bundle == bundle then
			results[combo] = record
		end
	end
	return results
end

function M.setGlobalDefault(bundle, combo)
	ensureGlobalState()
	for c, record in pairs(state.global.assigned) do
		if type(record) == 'table' and record.bundle == bundle then
			record.default = (c == combo)
		end
	end
	M.save()
end

function M.setGlobalDescription(bundle, combo, desc)
	ensureGlobalState()
	local entry = state.global.assigned[combo]
	if type(entry) == 'table' and entry.bundle == bundle then
		entry.description = desc
		M.save()
		return true
	end
	return false
end

function M.findGlobalsByBundle(bundle)
	ensureGlobalState()
	local results = {}
	for combo, record in pairs(state.global.assigned) do
		if type(record) == 'table' and record.bundle == bundle then
			table.insert(results, { combo = combo, info = record })
		end
	end
	table.sort(results, function (a, b)
		return (a.combo or '') < (b.combo or '')
	end)
	return results
end

function M.clearGlobalsForBundle(bundle)
	ensureGlobalState()
	local toRemove = {}
	for combo, record in pairs(state.global.assigned) do
		if type(record) == 'table' and record.bundle == bundle then
			table.insert(toRemove, combo)
		end
	end
	for _, combo in ipairs(toRemove) do
		state.global.assigned[combo] = nil
	end
	M.save()
end

function M.snapshot()
	ensureGlobalState()
	return deepCopy(state)
end

function M.export(path)
	ensureGlobalState()
	if not path or path == '' then return nil, 'no-path' end
	local ok, encoded = pcall(json.encode, state, true)
	if not ok then return nil, encoded end
	local okWrite, err = fs.writeFile(path, encoded)
	if not okWrite then return nil, err end
	return true
end

local function mergeTables(base, incoming)
	for k, v in pairs(incoming) do
		if type(v) == 'table' and type(base[k]) == 'table' then
			mergeTables(base[k], v)
		else
			base[k] = deepCopy(v)
		end
	end
end

function M.import(path, opts)
	opts = opts or {}
	if not path or path == '' then return nil, 'no-path' end
	local data, err = fs.readFile(path)
	if not data then return nil, err end
	local ok, decoded = pcall(json.decode, data)
	if not ok then return nil, decoded end
	if type(decoded) ~= 'table' then return nil, 'not-table' end
	if opts.merge then
		mergeTables(state, decoded)
	else
		state = deepCopy(decoded)
	end
	ensureGlobalState()
	M.save()
	return true
end

return M

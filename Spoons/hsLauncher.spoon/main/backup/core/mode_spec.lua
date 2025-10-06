-- hsLauncher/core/mode_spec.lua
-- Defines structured mode specifications and legacy compatibility helpers.

local logger = require('hsLauncher.main.core.logger')
local Actions = require('hsLauncher.main.core.actions')
local ExitKeys = require('hsLauncher.main.backup.core.exit_keys')

local ModeSpec = {}

local function shallowCopy(tbl)
	local out = {}
	if not tbl then return out end
	for k, v in pairs(tbl) do out[k] = v end
	return out
end

local function ensureExitKeys(def)
	return ExitKeys.normalize(def and def.exitKeys)
end

local function exitFunction()
	local fn = Actions.resolve(Actions.exit())
	return fn or function () end
end

local function wrapWithExit(fn, shouldExit)
	if not shouldExit or not fn then return fn end
	local exitFn = exitFunction()
	return function (...)
		fn(...)
		exitFn()
	end
end

local function mergeMetadata(base, extras)
	if not extras then return base end
	for k, v in pairs(extras) do base[k] = v end
	return base
end

local function computeLegendEntry(entry, key, defaultOrder)
	local meta = {
		description = entry.description or '',
		label = entry.label,
		order = entry.order or defaultOrder,
		passive = entry.passive or false,
	}
	meta.section = entry.section or entry.category
	if entry.lines then meta.lines = entry.lines end
	if entry.wrap ~= nil then meta.wrap = entry.wrap end
	if entry.multiline ~= nil then meta.multiline = entry.multiline end
	if entry.note then meta.note = entry.note end
	if entry.badge then meta.badge = entry.badge end
	if entry.style then meta.style = shallowCopy(entry.style) end
	if entry.displayKey then meta.displayKey = entry.displayKey end
	if entry.keyLabel then meta.keyLabel = entry.keyLabel end
	if entry.icon then meta.icon = entry.icon end
	if entry.category then meta.category = entry.category end
	if entry.metadata then mergeMetadata(meta, entry.metadata) end
	if meta.description == '' and entry.label then
		meta.description = entry.label
	end
	return meta
end

local function compileStructured(name, def)
	local compiled = {
		name = name,
		consume = def.consume,
		onEnter = def.onEnter,
		onExit = def.onExit,
		chords = def.chords,
		exitKeys = ensureExitKeys(def),
		exitDescription = def.exitDescription or string.format('Exit %s mode', tostring(name)),
		map = {},
		legend = {},
	}

	compiled.layout = shallowCopy(def.layout)

	local layout = compiled.layout or {}
	local defaultSection = def.defaultSection or layout.defaultSection or 'Shortcuts'
	local exitSection = def.exitSection or layout.exitSection or 'Exit'
	local chordSection = layout.chordSection or 'Chords'

	local defaultOrder = 10
	for index, entry in ipairs(def.entries or {}) do
		local key = entry.key
		if key then
			local kind = type(entry.action) == 'table' and (entry.action.kind or entry.action.__action)
			local fn = Actions.resolve(entry.action)
			local shouldExit = entry.exitAfter or false
			if kind == 'exit' then shouldExit = false end
			fn = wrapWithExit(fn, shouldExit)
			if fn and not entry.passive then
				compiled.map[key] = fn
			elseif entry.passive and entry.action then
				local passiveFn = Actions.resolve(entry.action)
				passiveFn = wrapWithExit(passiveFn, shouldExit)
				if passiveFn then compiled.map[key] = passiveFn end
			end
			local legendEntry = computeLegendEntry(entry, key, entry.order or (defaultOrder * index))
			legendEntry.key = key
			legendEntry.section = legendEntry.section or defaultSection
			legendEntry.isChord = entry.isChord or false
			if entry.lines then legendEntry.lines = entry.lines end
			if entry.wrap ~= nil then legendEntry.wrap = entry.wrap end
			if entry.multiline ~= nil then legendEntry.multiline = entry.multiline end
			if entry.note then legendEntry.note = entry.note end
			if entry.badge then legendEntry.badge = entry.badge end
			compiled.legend[key] = legendEntry
		else
			logger.warn(string.format('ModeSpec[%s]: entry missing key', tostring(name)))
		end
	end

	local exitFn = exitFunction()
	local exitOrderBase = 1000
	local ensuredExitKeys = ExitKeys.ensure(compiled.legend, {
		modeName = name,
		description = compiled.exitDescription,
		exitSection = exitSection,
		keys = compiled.exitKeys,
		orderBase = exitOrderBase,
	})
	for _, key in ipairs(ensuredExitKeys) do
		if not compiled.map[key] then
			compiled.map[key] = exitFn
		end
	end
	compiled.exitKeys = ensuredExitKeys

	if type(def.chordEntries) == 'table' then
		for idx, entry in ipairs(def.chordEntries) do
			local rawKey = entry.key or entry.combo or entry.label or ('chord_' .. tostring(idx))
			local storageKey = 'chord:' .. rawKey
			local legendEntry = computeLegendEntry(entry, storageKey, entry.order or (2000 + idx))
			legendEntry.label = legendEntry.label or entry.combo or entry.key or rawKey
			legendEntry.displayKey = legendEntry.displayKey or legendEntry.label
			legendEntry.section = legendEntry.section or chordSection
			legendEntry.isChord = true
			legendEntry.key = storageKey
			compiled.legend[storageKey] = legendEntry
		end
	end

	compiled.displayBindings = {}
	for key, meta in pairs(compiled.legend) do
		local copy = shallowCopy(meta)
		copy.key = meta.key or key
		compiled.displayBindings[key] = copy
	end

	return compiled
end

local function compileLegacy(name, def)
	local compiled = {
		name = name,
		consume = def.consume,
		onEnter = def.onEnter,
		onExit = def.onExit,
		chords = def.chords,
		map = {},
		legend = {},
		exitKeys = ensureExitKeys(def),
		exitDescription = def.exitDescription or string.format('Exit %s mode', tostring(name)),
	}

	compiled.layout = shallowCopy(def.layout)
	local layout = compiled.layout or {}
	local defaultSection = def.defaultSection or layout.defaultSection or 'Shortcuts'
	local exitSection = def.exitSection or layout.exitSection or 'Exit'
	local chordSection = layout.chordSection or 'Chords'

	for key, fn in pairs(def.map or {}) do
		if type(fn) == 'function' then
			compiled.map[key] = fn
		elseif type(fn) == 'table' then
			local resolved = Actions.resolve(fn)
			if resolved then compiled.map[key] = resolved end
		end
	end

	for key, meta in pairs(def.legend or {}) do
		if type(meta) == 'table' then
			local copy = shallowCopy(meta)
			copy.key = key
			copy.section = copy.section or defaultSection
			compiled.legend[key] = copy
		end
	end

	local exitFn = exitFunction()
	local exitOrderBase = 1000
	local ensuredExitKeys = ExitKeys.ensure(compiled.legend, {
		modeName = name,
		description = compiled.exitDescription,
		exitSection = exitSection,
		keys = compiled.exitKeys,
		orderBase = exitOrderBase,
	})
	for _, key in ipairs(ensuredExitKeys) do
		if not compiled.map[key] then compiled.map[key] = exitFn end
	end
	compiled.exitKeys = ensuredExitKeys

	if type(def.chordEntries) == 'table' then
		for idx, entry in ipairs(def.chordEntries) do
			local rawKey = entry.key or entry.combo or entry.label or ('chord_' .. tostring(idx))
			local storageKey = 'chord:' .. rawKey
			local legendEntry = computeLegendEntry(entry, storageKey, entry.order or (2000 + idx))
			legendEntry.label = legendEntry.label or entry.combo or entry.key or rawKey
			legendEntry.displayKey = legendEntry.displayKey or legendEntry.label
			legendEntry.section = legendEntry.section or chordSection
			legendEntry.isChord = true
			legendEntry.key = storageKey
			compiled.legend[storageKey] = legendEntry
		end
	end

	compiled.displayBindings = {}
	for key, meta in pairs(compiled.legend) do
		local copy = shallowCopy(meta)
		copy.key = meta.key or key
		compiled.displayBindings[key] = copy
	end

	return compiled
end

function ModeSpec.compile(name, def)
	if type(def) ~= 'table' then
		logger.error(string.format('ModeSpec: expected table for %s definition', tostring(name)))
		return compileLegacy(name, {})
	end
	if type(def.entries) == 'table' then
		return compileStructured(name, def)
	end
	return compileLegacy(name, def)
end

return ModeSpec

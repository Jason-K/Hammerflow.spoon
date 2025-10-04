--- @diagnostic disable: undefined-global, undefined-field

local M = {}
local log = require('hsLauncher.main.core.logger')
local application = require('hs.application')
local Engine = require('hsLauncher.main.core.input_engine')
local Actions = require('hsLauncher.main.core.actions')
local Mods = require('hsLauncher.main.core.mods')
local HotkeyManifest = require('hsLauncher.main.core.hotkey_manifest')
local userRegistry = require('hsLauncher.main.user.registry')
local buildHandlers = require('hsLauncher.main.modules.hotkeys.handlers')

local function runAction(action)
	local fn = Actions.resolve(action)
	if fn then fn() end
end

local function flattenSpecs(spec)
	if spec == nil then return nil end
	local out = {}
	local function push(value)
		if value ~= nil then out[#out + 1] = value end
	end
	local function process(value)
		if value == nil then return end
		local valueType = type(value)
		if valueType == 'table' then
			if value[1] ~= nil then
				for _, item in ipairs(value) do process(item) end
			else
				push(value)
			end
		else
			push(value)
		end
	end
	process(spec)
	if #out == 0 then return nil end
	return out
end

local quickSearchActionCache

local function buildQuickSearchAction()
	userRegistry.load()
	local spec = userRegistry.resolveAction('quicksearch.open_or_search_selection')
	if not spec then
		log.warn('global_shortcuts: quick search user action not found; disabling Hyper+S action')
		return Actions.noop()
	end
	local steps = {
		Actions.keystroke('c', { 'cmd' }),
		Actions.hsFunction('sleep', { 0.3 }),
		spec,
	}
	return Actions.sequence(steps)
end

local function quickSearchAction()
	if not quickSearchActionCache then
		quickSearchActionCache = buildQuickSearchAction()
	end
	return quickSearchActionCache
end

local handlerCache

local function safeRequire(path)
	local ok, mod = pcall(require, path)
	if ok then return mod end
	log.warn('global_shortcuts: unable to load optional dependency ' .. tostring(path) .. ' -> ' .. tostring(mod))
	return nil
end

local function getHandlers()
	if handlerCache ~= nil then return handlerCache end
	local context = {
		hyper = safeRequire('hsLauncher.main.core.hyper_modal'),
		win = safeRequire('hsLauncher.main.core.windows_native'),
		hsWindow = safeRequire('hs.window'),
		assignHotkey = safeRequire('hsLauncher.main.modules.hotkeys.assign_hotkey'),
		assignGlobal = safeRequire('hsLauncher.main.modules.hotkeys.assign_global'),
		logger = log,
		userRegistry = userRegistry,
	}
	local ok, handlers = pcall(buildHandlers, context)
	if not ok then
		log.error('global_shortcuts: unable to build handlers -> ' .. tostring(handlers))
		handlerCache = {}
		return handlerCache
	end
	handlerCache = handlers or {}
	return handlerCache
end

local function matchesAppSpec(app, spec)
	if not spec then return false end
	if not app then return false end
	local bundle = app:bundleID()
	local name = app:name()

	local specType = type(spec)
	if specType == 'table' then
		local expectedBundle = spec.bundle or spec.bundleID or spec.bundleId
		if expectedBundle and bundle == expectedBundle then return true end
		local expectedName = spec.name or spec.app or spec.title
		if expectedName and name == expectedName then return true end
		if type(spec.matches) == 'function' then
			local ok, result = pcall(spec.matches, app)
			if ok and result then return true end
		end
		if spec.pattern and name and name:find(spec.pattern) then return true end
		if spec.prefix and name and name:find(spec.prefix, 1, true) == 1 then return true end
		if spec.contains and name and name:find(spec.contains, 1, true) then return true end
	elseif specType == 'string' then
		local prefix, value = spec:match('^(%w+):(.+)$')
		if prefix == 'bundle' or prefix == 'id' or prefix == 'bundleId' then
			return bundle == value
		elseif prefix == 'name' or prefix == 'app' then
			return name == value
		elseif prefix == 'notBundle' then
			return bundle ~= value
		elseif prefix == 'notName' then
			return name ~= value
		elseif prefix == 'contains' then
			return name and name:find(value, 1, true) ~= nil
		end
		if bundle and bundle == spec then return true end
		if name and name == spec then return true end
	end
	return false
end

local function summarizeAppSpec(spec)
	if type(spec) == 'table' then
		local expectedBundle = spec.bundle or spec.bundleID or spec.bundleId
		if expectedBundle then return 'bundle:' .. expectedBundle end
		local expectedName = spec.name or spec.app or spec.title
		if expectedName then return 'name:' .. expectedName end
		if spec.pattern then return 'pattern:' .. tostring(spec.pattern) end
		if spec.contains then return 'contains:' .. tostring(spec.contains) end
		if spec.prefix then return 'prefix:' .. tostring(spec.prefix) end
	elseif type(spec) == 'string' then
		return spec
	end
	return tostring(spec)
end

local function metadataForApps(entry)
	local include = flattenSpecs(entry.apps or entry.app or entry.onlyFor or entry.appBundles or entry.appNames)
	local exclude = flattenSpecs(entry.exceptApps or entry.exceptApp or entry.appBlacklist or entry.excludeApps or
	entry.blockApps)
	if not include and not exclude then return nil end
	local metadata = {}
	if include then
		metadata.include = {}
		for _, spec in ipairs(include) do metadata.include[#metadata.include + 1] = summarizeAppSpec(spec) end
	end
	if exclude then
		metadata.exclude = {}
		for _, spec in ipairs(exclude) do metadata.exclude[#metadata.exclude + 1] = summarizeAppSpec(spec) end
	end
	return metadata
end

local function shouldHandleEntry(entry)
	local include = flattenSpecs(entry.apps or entry.app or entry.onlyFor or entry.appBundles or entry.appNames)
	local exclude = flattenSpecs(entry.exceptApps or entry.exceptApp or entry.appBlacklist or entry.excludeApps or
	entry.blockApps)
	local when = entry.when or entry.condition

	local appResolved = false
	local app

	local function getApp()
		if not appResolved then
			app = application.frontmostApplication()
			appResolved = true
		end
		return app
	end

	if include then
		local active = getApp()
		if not active then return false end
		local matched = false
		for _, spec in ipairs(include) do
			if matchesAppSpec(active, spec) then
				matched = true
				break
			end
		end
		if not matched then return false end
	end

	if exclude then
		local active = getApp()
		if active then
			for _, spec in ipairs(exclude) do
				if matchesAppSpec(active, spec) then return false end
			end
		end
	end

	if when ~= nil then
		local result = true
		local active = getApp()
		local bundle = active and active:bundleID() or nil
		local name = active and active:name() or nil
		local whenType = type(when)

		if whenType == 'function' then
			local ok, value = pcall(when, {
				app = active,
				bundle = bundle,
				name = name,
				entry = entry,
			})
			if not ok then
				log.warn('global_shortcuts: condition callback failed -> ' .. tostring(value))
				result = false
			else
				result = value ~= false
			end
		elseif whenType == 'string' then
			local prefix, value = when:match('^(%w+):(.+)$')
			if prefix == 'bundle' then
				result = (bundle == value)
			elseif prefix == 'name' then
				result = (name == value)
			elseif prefix == 'notBundle' then
				result = (bundle ~= value)
			elseif prefix == 'notName' then
				result = (name ~= value)
			else
				result = matchesAppSpec(active, when)
			end
		elseif whenType == 'table' then
			result = matchesAppSpec(active, when)
		else
			result = when and when ~= false
		end

		if not result then return false end
	end

	return true
end

local function hyperAlone()
	runAction(Actions.keystroke('c', { 'cmd' }))
	local registry = require('hsLauncher.main.modules.hotkeys.hotkey_registry')
	local globals = registry.getGlobals('com.brnbw.Leader-Key')
	local foundDefault
	for combo, info in pairs(globals or {}) do
		if info.default then
			foundDefault = combo
			break
		end
	end
	if foundDefault ~= nil then
		local parts = {}
		for part in foundDefault:gmatch('[^+]+') do table.insert(parts, part) end
		local key = parts[#parts]
		if key == 'comma' then key = ',' elseif key == 'space' then key = ' ' end
		local mods = {}
		for i = 1, #parts - 1 do mods[i] = parts[i] end
		runAction(Actions.keystroke(key, mods))
	else
		runAction(Actions.keystroke('l', { 'cmd', 'alt', 'shift' }))
	end
end

local defaultConfig = {
	thresholds = { tap_ms = 230, hold_ms = 300, double_ms = 320 },
	taps = {
		{ key = 'capslock', alone = true,       handler = 'hyperDefault' },
		{ key = 'padclear', alone = true,       action = Actions.open({ app_name = 'PiPad' }) },
		{ key = 'home',     alone = true,       action = Actions.keystroke('left', { 'cmd' }) },
		{ key = 'home',     mods = { 'shift' }, alone = true,                                  action = Actions.keystroke('left', { 'cmd', 'shift' }) },
		{ key = 'end',      alone = true,       action = Actions.keystroke('right', { 'cmd' }) },
		{ key = 'end',      mods = { 'shift' }, alone = true,                                  action = Actions.keystroke('right', { 'cmd', 'shift' }) },
	},
	chords = {
		{ mods = { 'alt' },                key = 'm',      action = Actions.keystroke('f20', { 'cmd', 'alt', 'ctrl' }) },
		{
			mods = 'hyper',
			key = 's',
			action = quickSearchAction(),
		},
		{ mods = { 'cmd', 'alt', 'ctrl' }, key = '=',      action = Actions.shell([["/opt/homebrew/bin/hs" -c 'formatSelected()']]) },
		{ mods = { 'alt', 'ctrl' },        key = 'escape', action = Actions.open({ path = '/System/Applications/Utilities/Activity Monitor.app' }) },
	},
	sequences = {
		{
			keys = {
				{ mods = { 'cmd' }, key = 'q' },
				{ mods = { 'cmd' }, key = 'q' },
			},
			timeout = 600,
			action = Actions.hsFunction('quitActiveApp'),
		},
	},
	doubleTaps = {
		{ key = 'escape', mods = { 'alt', 'ctrl' }, alone = true, action = Actions.keystroke('escape', { 'cmd', 'alt' }) },
	},
	disabled = {
		{ mods = { 'cmd' },        key = 'h' },
		{ mods = { 'cmd', 'alt' }, key = 'h' },
		{ mods = { 'cmd', 'alt' }, key = 'm' },
		{ mods = { 'cmd' },        key = 'q' },
	},
}

local function shallowCopyList(list)
	local copy = {}
	for _, item in ipairs(list or {}) do table.insert(copy, item) end
	return copy
end

local function mergeList(defaultList, override)
	if override == nil then return shallowCopyList(defaultList) end
	if type(override) ~= 'table' then return shallowCopyList(defaultList) end
	if override.appendDefaults or override.inheritDefaults then
		local combined = shallowCopyList(defaultList)
		for _, item in ipairs(override) do table.insert(combined, item) end
		return combined
	end
	return shallowCopyList(override)
end

local function loadUserConfig()
	local ok, moduleValueOrErr = pcall(require, 'hsLauncher.main.user.hotkeys_Global')
	if not ok then
		local reason = tostring(moduleValueOrErr)
		if not reason:match('module .+ not found') then
			log.warn('global_shortcuts: unable to load user config -> ' .. reason)
		end
		return {}
	end
	local moduleValue = moduleValueOrErr
	if type(moduleValue) ~= 'table' then
		log.error('global_shortcuts: hotkeys_Global must return a table to supply global shortcuts')
		return {}
	end
	local cfg = moduleValue.globalShortcuts or moduleValue.global_shortcuts or moduleValue.global or
	moduleValue.shortcuts
	if cfg == nil then
		log.warn('global_shortcuts: hotkeys_Global returned without globalShortcuts table; using defaults')
		return {}
	end
	if type(cfg) ~= 'table' then
		log.error('global_shortcuts: globalShortcuts entry must be a table')
		return {}
	end
	return cfg
end

local function buildConfig()
	local userCfg = loadUserConfig()
	return {
		thresholds = userCfg.thresholds or defaultConfig.thresholds,
		taps = mergeList(defaultConfig.taps, userCfg.taps),
		chords = mergeList(defaultConfig.chords, userCfg.chords),
		sequences = mergeList(defaultConfig.sequences, userCfg.sequences),
		doubleTaps = mergeList(defaultConfig.doubleTaps, userCfg.doubleTaps),
		disabled = mergeList(defaultConfig.disabled, userCfg.disabled),
	}
end

local function resolveAction(value)
	if value == nil then return nil end
	local valueType = type(value)
	if valueType == 'function' then
		return value
	elseif valueType == 'string' then
		if value == 'hyper_alone' or value == 'hyperDefault' or value == 'hyper.default' then
			return hyperAlone
		end
		userRegistry.load()
		local spec = select(1, userRegistry.resolveAction(value))
		if spec then return Actions.resolve(spec) end
		log.warn('global_shortcuts: unknown action reference ' .. value)
		return nil
	elseif valueType == 'table' then
		if value.enabled == false then return nil end
		if value.action ~= nil then return resolveAction(value.action) end
		if value.handler ~= nil then return resolveAction(value.handler) end
		if value.actionSpec ~= nil then return resolveAction(value.actionSpec) end
		if value.ref ~= nil then return resolveAction(value.ref) end
		if value.actionRef ~= nil then return resolveAction(value.actionRef) end
		if value.mode ~= nil then return resolveAction(Actions.enterMode(value.mode)) end
		if value.kind then
			if value.kind == 'handler' then
				local handlers = getHandlers()
				local handler = handlers and handlers[value.name]
				if not handler then
					log.warn('global_shortcuts: unknown handler ' .. tostring(value.name))
					return nil
				end
				local spec = handler(value.args)
				if not spec then return nil end
				return Actions.resolve(spec)
			end
			return Actions.resolve(value)
		end
	end
	return nil
end

local function handlerFor(entry, triggerType)
	local fn = resolveAction(entry)
	if not fn then
		return function () return true end
	end
	local passThrough = entry.passThrough
	if passThrough == nil then passThrough = true end
	return function (...)
		if not shouldHandleEntry(entry) then
			if passThrough then
				if triggerType == 'chord' or triggerType == 'doubleTap' then
					local mods = Mods.normalizeMods(entry.mods)
					local key = entry.key
					if key then
						Engine.reemitKey(mods, key)
					end
					return true
				end
				return false
			end
			return true
		end
		local ok, result = pcall(fn, ...)
		if not ok then
			log.error('global_shortcuts: action failed -> ' .. tostring(result))
			return true
		end
		if result == nil then return true end
		return result
	end
end

local function normalizeMods(mods)
	return Mods.normalizeMods(mods)
end

local function captureCaller(depth)
	local info = debug.getinfo(depth or 3, 'Sl')
	if not info then return 'global_shortcuts' end
	local src = info.short_src or info.source or 'global_shortcuts'
	local line = info.currentline or info.linedefined or 0
	return string.format('%s:%d', src, line)
end

local function describeActionSpec(spec)
	if spec == nil then return nil end
	local t = type(spec)
	if t == 'string' then return spec end
	if t == 'function' then
		local info = debug.getinfo(spec, 'Sn')
		if not info then return 'function' end
		local src = info.short_src or info.source or 'function'
		local line = info.linedefined or 0
		if info.name and info.name ~= '' then
			return string.format('%s:%d (%s)', src, line, info.name)
		end
		return string.format('%s:%d', src, line)
	end
	if t == 'table' then
		local kind = spec.kind or spec.type
		if kind then return kind end
		if spec.handler then return 'handler:' .. tostring(spec.handler) end
		if spec.action then return describeActionSpec(spec.action) end
	end
	return tostring(spec)
end

local function manifestTrigger(key, mods, extras)
	local trigger = {
		key = key,
		mods = mods,
	}
	if extras then
		for k, v in pairs(extras) do trigger[k] = v end
	end
	return trigger
end

local function registerTaps(list)
	for _, tap in ipairs(list or {}) do
		if tap ~= nil and tap.enabled ~= false then
			if not tap.key then
				log.warn('global_shortcuts: tap entry missing key')
			else
				local alone = tap.alone
				if alone == nil then alone = true end
				Engine.onTap(tap.key, normalizeMods(tap.mods), alone, handlerFor(tap, 'tap'))
				local metadata = {
					label = tap.label,
					note = tap.note,
				}
				local appMeta = metadataForApps(tap)
				if appMeta then metadata.appFilters = appMeta end
				HotkeyManifest.recordGlobal({
					scope = 'global.tap',
					triggerType = 'tap',
					trigger = manifestTrigger(tap.key, normalizeMods(tap.mods), { alone = alone }),
					description = tap.description or tap.label,
					action = describeActionSpec(tap.action or tap.handler or tap.actionSpec or tap.actionRef),
					source = captureCaller(4),
					metadata = metadata,
				})
			end
		end
	end
end

local function registerChords(list)
	for _, chord in ipairs(list or {}) do
		if chord ~= nil and chord.enabled ~= false then
			if not chord.key then
				log.warn('global_shortcuts: chord entry missing key')
			else
				Engine.onChord(normalizeMods(chord.mods) or {}, chord.key, handlerFor(chord, 'chord'))
				local metadata = {
					note = chord.note,
				}
				local appMeta = metadataForApps(chord)
				if appMeta then metadata.appFilters = appMeta end
				HotkeyManifest.recordGlobal({
					scope = 'global.chord',
					triggerType = 'chord',
					trigger = manifestTrigger(chord.key, normalizeMods(chord.mods)),
					description = chord.description or chord.label,
					action = describeActionSpec(chord.action or chord.handler or chord.actionSpec or chord.actionRef),
					source = captureCaller(4),
					metadata = metadata,
				})
			end
		end
	end
end

local function registerDoubleTaps(list)
	for _, entry in ipairs(list or {}) do
		if entry ~= nil and entry.enabled ~= false then
			if not entry.key then
				log.warn('global_shortcuts: double tap entry missing key')
			else
				local alone = entry.alone
				if alone == nil then alone = true end
				Engine.onDoubleTap(entry.key, normalizeMods(entry.mods), alone, handlerFor(entry, 'doubleTap'))
				local metadata = {
					note = entry.note,
				}
				local appMeta = metadataForApps(entry)
				if appMeta then metadata.appFilters = appMeta end
				HotkeyManifest.recordGlobal({
					scope = 'global.doubleTap',
					triggerType = 'doubleTap',
					trigger = manifestTrigger(entry.key, normalizeMods(entry.mods), { alone = alone }),
					description = entry.description or entry.label,
					action = describeActionSpec(entry.action or entry.handler or entry.actionSpec or entry.actionRef),
					source = captureCaller(4),
					metadata = metadata,
				})
			end
		end
	end
end

local function isHyper(mods)
	if mods == nil then return false end
	if mods == 'hyper' then return true end
	if type(mods) == 'table' then
		for _, value in ipairs(mods) do
			if value == 'hyper' then return true end
		end
	end
	return false
end

local function normalizeSequenceMods(mods)
	if mods == nil then return nil end
	if isHyper(mods) then return 'hyper' end
	return normalizeMods(mods)
end

local function normalizeSequenceStep(step)
	if type(step) ~= 'table' then return nil end
	if step.mods or step.key then
		return { normalizeSequenceMods(step.mods), step.key }
	end
	if #step >= 2 then
		return { normalizeSequenceMods(step[1]), step[2] }
	end
	return nil
end

local function registerSequences(list)
	for _, seq in ipairs(list or {}) do
		if seq ~= nil and seq.enabled ~= false then
			local sourceSteps = seq.keys or seq.steps or {}
			local steps = {}
			for _, step in ipairs(sourceSteps) do
				local normalized = normalizeSequenceStep(step)
				if normalized then table.insert(steps, normalized) end
			end
			if #steps == 0 then
				log.warn('global_shortcuts: sequence entry missing steps')
			else
				Engine.onSequence(steps, seq.timeout or seq.within or 600, handlerFor(seq, 'sequence'))
				local metadata = {
					originalSteps = sourceSteps,
				}
				local appMeta = metadataForApps(seq)
				if appMeta then metadata.appFilters = appMeta end
				HotkeyManifest.recordGlobal({
					scope = 'global.sequence',
					triggerType = 'sequence',
					trigger = { steps = steps, timeout = seq.timeout or seq.within or 600 },
					description = seq.description or seq.label,
					action = describeActionSpec(seq.action or seq.handler or seq.actionSpec or seq.actionRef),
					source = captureCaller(5),
					metadata = metadata,
				})
			end
		end
	end
end

local function registerDisabled(list)
	for _, entry in ipairs(list or {}) do
		if entry ~= nil and entry.enabled ~= false then
			local key = entry.key or entry[#entry]
			local mods = entry.mods or entry[1]
			if not key then
				log.warn('global_shortcuts: disabled entry missing key')
			else
				Engine.onChord(normalizeMods(mods) or {}, key, function () return true end)
				HotkeyManifest.recordGlobal({
					scope = 'global.disabled',
					triggerType = 'disabled',
					trigger = manifestTrigger(key, normalizeMods(mods)),
					description = entry.description or 'Disabled shortcut',
					action = 'disabled',
					source = captureCaller(4),
				})
			end
		end
	end
end

local function setup()
	local config = buildConfig()
	if config.thresholds then
		Engine.setThresholds(config.thresholds)
	end

	userRegistry.load()

	registerTaps(config.taps)
	registerChords(config.chords)
	registerSequences(config.sequences)
	registerDoubleTaps(config.doubleTaps)
	registerDisabled(config.disabled)

	Engine.start()
end

function M.start()
	setup()
end

function M.stop()
	Engine.stop()
end

return M

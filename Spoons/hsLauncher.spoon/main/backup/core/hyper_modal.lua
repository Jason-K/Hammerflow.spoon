--- @diagnostic disable: undefined-global

-- Hyper modal with leader sequences, modes, canvas status, passthrough, and physical-chord handling
local logger = require('hsLauncher.main.core.logger')
local cfg = require('hsLauncher.main.core.config')
local eventtap = require('hs.eventtap')
local timer = require('hs.timer')
local Indicator = require('hsLauncher.main.backup.core.indicator')
local HotkeyManifest = require('hsLauncher.main.core.hotkey_manifest')
local ExitKeys = require('hsLauncher.main.backup.core.exit_keys')
local application = require('hs.application')
local ax = require('hs.axuielement')
local canvas = require('hs.canvas')     -- For GUI
local geometry = require('hs.geometry') -- For GUI
local ModeSpec = require('hsLauncher.main.backup.core.mode_spec')
local Engine = require('hsLauncher.main.backup.core.input_engine')
local LeaderBuffer = require('hsLauncher.main.backup.core.leader_buffer')
local pasteboard = require('hs.pasteboard')

local M = {
	active = false,
	leaderArmed = false,
	modeActive = false,
	currentMode = nil,
	modes = {},
	sequences = {},
	bindings = {},
	buffer = {},
	held = {}, -- keys currently held in a mode
	participated = {},
	ignoreSoloKey = nil,
	ignoreSoloUntil = 0, -- keys that participated in a chord during their hold
	gui_canvas = nil,
}

local hyperKey = cfg.hyperKey or 'f15'
local leaderTimeout = cfg.leaderTimeout or 1.5
local tapThreshold = cfg.tapThreshold or 0.25
local consumeKeys = cfg.consumeKeys ~= false
local leaderBuffer
local engineWired = false
local leaderTimer
M._downAt = nil
M.ind = nil
local pendingDeactivateTimer
local hyperPendingDeactivate = false
local pendingLeaderEligible = false
local hyperComboTriggered = false
local hyperComboGrace = cfg.hyperComboGrace or 0.2
local hyperComboDeadline = 0

local leaderRegistry = nil
local leaderRootCache = nil
local syntheticSuppressUntil = 0

local function suppressSyntheticInput(duration)
	local now = hs.timer.secondsSinceEpoch()
	if not now then
		syntheticSuppressUntil = 0
		return
	end
	local untilTime = now + (duration or 0.12)
	if untilTime > syntheticSuppressUntil then
		syntheticSuppressUntil = untilTime
	end
end

local function syntheticSuppressed()
	if syntheticSuppressUntil == 0 then return false end
	local now = hs.timer.secondsSinceEpoch()
	if not now then
		syntheticSuppressUntil = 0
		return false
	end
	if now <= syntheticSuppressUntil then return true end
	syntheticSuppressUntil = 0
	return false
end

local function fetchLeaderOptions()
	if leaderRegistry == false then return nil end
	if not leaderRegistry then
		local ok, mod = pcall(require, 'hsLauncher.main.user.registry')
		if not ok then
			logger.error('hyper_modal: unable to load user registry -> ' .. tostring(mod))
			leaderRegistry = false
			return nil
		end
		leaderRegistry = mod
	end
	if type(leaderRegistry.leaderOptions) ~= 'function' then return nil end
	local ok, opts = pcall(leaderRegistry.leaderOptions)
	if not ok then
		logger.error('hyper_modal: leaderOptions failed -> ' .. tostring(opts))
		return nil
	end
	return opts
end

local function leaderRootModeName()
	if leaderRootCache then return leaderRootCache end
	local opts = fetchLeaderOptions() or {}
	local prefix = opts.prefix or 'leader'
	local rootName = opts.rootName or 'root'
	local modeName = opts.rootMode or (prefix .. '.' .. rootName)
	leaderRootCache = modeName
	return leaderRootCache
end

local function safeAttribute(element, attribute)
	if not element or not attribute then return nil end
	local ok, value = pcall(function ()
		return element:attributeValue(attribute)
	end)
	if not ok then return nil end
	return value
end

local function extractSelectedText()
	local ok, sys = pcall(ax.systemWideElement)
	if not ok or not sys then
		return nil
	end
	local focused = safeAttribute(sys, 'AXFocusedUIElement')
	if not focused then return nil end

	local selected = safeAttribute(focused, 'AXSelectedText')
	if type(selected) == 'string' and selected ~= '' then return selected end

	local attributed = safeAttribute(focused, 'AXSelectedTextAttributedString')
	if type(attributed) == 'table' then
		local text = attributed.string or attributed.text or attributed.value
		if type(text) == 'string' and text ~= '' then return text end
	elseif type(attributed) == 'string' and attributed ~= '' then
		return attributed
	end

	local range = safeAttribute(focused, 'AXSelectedTextRange')
	local value = safeAttribute(focused, 'AXValue')
	if type(value) == 'string' and type(range) == 'table' then
		local location = tonumber(range.location or range.locationValue or 0) or 0
		local length = tonumber(range.length or range.lengthValue or 0) or 0
		if length > 0 then
			local startIndex = math.max(1, math.floor(location) + 1)
			local endIndex = math.min(#value, startIndex + math.floor(length) - 1)
			if endIndex >= startIndex then
				return value:sub(startIndex, endIndex)
			end
		end
	end

	return nil
end

local function copySelectionToClipboard()
	local text = extractSelectedText()
	if type(text) == 'string' and text ~= '' then
		pasteboard.setContents(text)
		return true
	end
	logger.info('hyper_modal: accessibility selection unavailable; falling back to Cmd+C copy')
	suppressSyntheticInput(0.15)
	eventtap.keyStroke({ 'cmd' }, 'c', 0)
	hs.timer.usleep(35000)
	return true
end

local function enterLeaderRootFromTap()
	local modeName = leaderRootModeName()
	if not modeName then
		logger.warn('hyper_modal: unable to determine leader root mode from tap')
		return false
	end
	if not M.modes[modeName] then
		logger.warn('hyper_modal: leader root mode not registered (' .. tostring(modeName) .. ')')
		return false
	end
	if M.modeActive then M.exitMode() end
	copySelectionToClipboard()
	logger.info('Hyper tap: entering leader root -> ' .. tostring(modeName))
	M.enterMode(modeName)
	return true
end

local MOD_ORDER = { ctrl = 1, alt = 2, shift = 3, cmd = 4 }

local function canonicalKey(meta)
	if not meta then return nil end
	local name = meta.name
	if not name or name == '' then return nil end
	local mods = meta.mods or {}
	if #mods == 0 then return name end
	local relevant = {}
	for _, mod in ipairs(mods) do
		if MOD_ORDER[mod] then relevant[#relevant + 1] = mod end
	end
	if #relevant == 0 then return name end
	table.sort(relevant, function (a, b)
		return (MOD_ORDER[a] or 99) < (MOD_ORDER[b] or 99)
	end)
	relevant[#relevant + 1] = name
	return table.concat(relevant, '-')
end

local function cancelPendingDeactivate()
	if pendingDeactivateTimer then
		pendingDeactivateTimer:stop()
		pendingDeactivateTimer = nil
	end
	hyperPendingDeactivate = false
	pendingLeaderEligible = false
	hyperComboDeadline = 0
end

local function captureCaller(depth)
	local info = debug.getinfo((depth or 3), 'Sl')
	if not info then return 'hyper_modal' end
	local src = info.short_src or info.source or 'hyper_modal'
	local line = info.currentline or info.linedefined or 0
	return string.format('%s:%d', src, line)
end

local function describeFn(fn)
	if type(fn) ~= 'function' then return nil end
	local info = debug.getinfo(fn, 'Sn')
	if not info then return nil end
	local src = info.short_src or info.source or '?'
	local line = info.linedefined or 0
	if info.name and info.name ~= '' then
		return string.format('%s:%d (%s)', src, line, info.name)
	end
	return string.format('%s:%d', src, line)
end

local function copyArray(list)
	if type(list) ~= 'table' then return nil end
	local out = {}
	for index, value in ipairs(list) do out[index] = value end
	return out
end

local function copySectionGroups(list)
	if type(list) ~= 'table' then return nil end
	local groups = {}
	for index, group in ipairs(list) do
		if type(group) == 'table' then
			groups[index] = {
				label = group.label,
				sections = copyArray(group.sections) or {},
			}
		end
	end
	return groups
end

local function sanitizeLayout(layout)
	if type(layout) ~= 'table' then return nil end
	return {
		width = layout.width,
		defaultSection = layout.defaultSection,
		exitSection = layout.exitSection,
		chordSection = layout.chordSection,
		sectionOrder = layout.sectionOrder and { table.unpack(layout.sectionOrder) } or nil,
		sectionGroups = copySectionGroups(layout.sectionGroups or layout.groups),
		showGroupHeaders = layout.showGroupHeaders,
		groupGap = layout.groupGap,
		footerText = layout.footerText or layout.footer,
		footerAlignment = layout.footerAlignment,
		footerFontSize = layout.footerFontSize,
	}
end

local function recordModeInManifest(name, compiled, def, source)
	local entries = {}
	for _, meta in pairs(compiled.legend or {}) do
		entries[#entries + 1] = {
			key = meta.key,
			description = meta.description,
			section = meta.section,
			order = meta.order,
			passive = meta.passive,
			isExit = meta.isExit,
			isChord = meta.isChord,
			label = meta.label,
		}
	end

	HotkeyManifest.recordMode({
		trigger = name,
		description = def.description or (def.layout and def.layout.title) or string.format('Mode %s', name),
		action = 'hyper.mode',
		source = source,
		metadata = {
			entries = entries,
			layout = sanitizeLayout(compiled.layout),
			exitKeys = compiled.exitKeys,
		},
		tags = def.tags,
	})
end

local function buildBindingMetadata(spec)
	local metadata = {}
	if type(spec.metadata) == 'table' then
		for k, v in pairs(spec.metadata) do metadata[k] = v end
	end
	metadata.scope = metadata.scope or spec.displayScope or 'hyper'
	if spec.label and metadata.label == nil then metadata.label = spec.label end
	if spec.note and metadata.note == nil then metadata.note = spec.note end
	if spec.mode and metadata.mode == nil then metadata.mode = spec.mode end
	if spec.appId and metadata.appId == nil then metadata.appId = spec.appId end
	if spec.section and metadata.section == nil then metadata.section = spec.section end
	return next(metadata) and metadata or { scope = 'hyper' }
end

local function buildSequenceMetadata(spec, keys)
	local metadata = {
		keys = copyArray(keys),
		size = #keys,
	}
	if type(spec.metadata) == 'table' then
		for k, v in pairs(spec.metadata) do metadata[k] = v end
	end
	metadata.scope = metadata.scope or spec.displayScope or 'hyper'
	if spec.label and metadata.label == nil then metadata.label = spec.label end
	if spec.note and metadata.note == nil then metadata.note = spec.note end
	if spec.mode and metadata.mode == nil then metadata.mode = spec.mode end
	if spec.appId and metadata.appId == nil then metadata.appId = spec.appId end
	return metadata
end

local function safeCall(fn)
	local ok, err = pcall(fn)
	if not ok then
		logger.error('hyper_modal: handler execution failed -> ' .. tostring(err))
	end
end

local function shallowCopyTable(tbl)
	if not tbl then return nil end
	local out = {}
	for k, v in pairs(tbl) do out[k] = v end
	return out
end

local function ensureTable(value)
	if type(value) == 'table' then return value end
	if type(value) == 'string' then return { description = value } end
	return nil
end

local function resolveBindingCallback(binding)
	if type(binding) == 'function' then return binding end
	if type(binding) == 'table' then
		local kind = binding.kind or binding.__action
		if kind then
			local Actions = require('hsLauncher.main.core.actions')
			return Actions.resolve(binding)
		end
		if type(binding.callback) == 'function' then return binding.callback end
		if type(binding.action) == 'function' then return binding.action end
		if type(binding.fn) == 'function' then return binding.fn end
		if type(binding.press) == 'function' then return binding.press end
	end
	return nil
end

local function collectDisplayBindings(modeName, mode, provided)
	if provided and next(provided) ~= nil then
		local out = {}
		for key, value in pairs(provided) do
			if type(value) == 'table' then
				out[key] = shallowCopyTable(value)
				out[key].key = out[key].key or key
			elseif type(value) == 'string' then
				out[key] = { description = value, key = key }
			end
		end
		ExitKeys.ensure(out, {
			modeName = modeName,
			description = string.format('Exit %s mode', tostring(modeName)),
		})
		return out, nil
	end

	local result = {}
	if not mode then return result, nil end

	if type(mode.displayBindings) == 'table' then
		for key, entry in pairs(mode.displayBindings) do
			result[key] = shallowCopyTable(entry)
			result[key].key = result[key].key or key
		end
		local layout = nil
		if type(mode.layout) == 'table' then layout = shallowCopyTable(mode.layout) end
		return result, layout
	end

	if type(mode.legend) == 'table' then
		for key, entry in pairs(mode.legend) do
			local coerced = ensureTable(entry)
			if coerced then
				result[key] = shallowCopyTable(coerced)
				result[key].key = result[key].key or key
			end
		end
	end

	if type(mode.map) == 'table' then
		for key, entry in pairs(mode.map) do
			if type(entry) == 'table' then
				local target = result[key] or {}
				if entry.description and target.description == nil then target.description = entry.description end
				if entry.label then target.label = entry.label end
				if entry.order then target.order = entry.order end
				if entry.passive ~= nil then target.passive = entry.passive end
				target.key = target.key or key
				result[key] = target
			end
		end
	end

	local exitDesc = mode.exitDescription or string.format('Exit %s mode', tostring(modeName))
	local exitSection = 'Exit'
	if type(mode.layout) == 'table' and type(mode.layout.exitSection) == 'string' then
		exitSection = mode.layout.exitSection
	end
	ExitKeys.ensure(result, {
		modeName = modeName,
		description = exitDesc,
		exitSection = exitSection,
		keys = mode.exitKeys,
	})

	local layout = nil
	if type(mode.layout) == 'table' then layout = shallowCopyTable(mode.layout) end
	return result, layout
end

local function sortedBindingKeys(bindings)
	local keys = {}
	for key, info in pairs(bindings or {}) do
		if type(info) == 'table' then
			table.insert(keys, { key = key, order = info.order or math.huge })
		end
	end
	table.sort(keys, function (a, b)
		if a.order ~= b.order then return a.order < b.order end
		return a.key < b.key
	end)
	local ordered = {}
	for _, entry in ipairs(keys) do ordered[#ordered + 1] = entry.key end
	return ordered
end

-- Indicator helpers
local function ensureIndicator()
	if not M.ind then M.ind = Indicator.new({ position = 'top-center', width = 200, height = 34 }) end
end

local function statusText()
	local t = {}
	table.insert(t, M.active and '● Hy' or '○ Hy')
	if M.leaderArmed then table.insert(t, 'L') end
	if M.modeActive then table.insert(t, M.currentMode or '?') end
	return table.concat(t, ' · ')
end

local function refreshIndicator()
	ensureIndicator()
	if M.active or M.leaderArmed or M.modeActive then M.ind:show(statusText()) else M.ind:hide() end
end

local function updateStatusFlash()
	ensureIndicator(); M.ind:flash(statusText(), 0.5)
end

-- Leader sequence machinery
local function ensureLeaderBuffer()
	if leaderBuffer then return leaderBuffer end
	leaderBuffer = LeaderBuffer.new({
		timeout = leaderTimeout,
		onTimeout = function ()
			if leaderTimer then
				leaderTimer:stop(); leaderTimer = nil
			end
			M.leaderArmed = false
			M.buffer = {}
			updateStatusFlash()
			refreshIndicator()
			logger.info('Leader buffer timeout')
		end,
		onUpdate = function (keys, info)
			M.buffer = keys or {}
			if info and info.reason == 'push' then
				ensureIndicator()
				M.ind:flash('Leader: ' .. table.concat(M.buffer, ' '), 0.6)
			end
		end,
	})
	M.buffer = leaderBuffer:get()
	return leaderBuffer
end

local function resetLeaderBuffer(reason)
	if leaderBuffer then
		leaderBuffer:clear(reason)
	end
	if not leaderBuffer then
		M.buffer = {}
	end
end

local function pushLeaderKey(key)
	if not key or key == '' then return end
	ensureLeaderBuffer():push(key)
end

local function trySequences()
	if not leaderBuffer then return false end
	local matched = false
	leaderBuffer:evaluate(M.sequences, {
		onFull = function (seq)
			matched = true
			local keys = seq.keys or seq
			local lastKey = keys and keys[#keys]
			if lastKey then
				M.ignoreSoloKey = lastKey
				M.ignoreSoloUntil = (hs.timer.secondsSinceEpoch() + 0.6)
			end
			local ok, err = pcall(seq.enter)
			if not ok then logger.error('Sequence enter failed: ' .. tostring(err)) end
		end,
		onPrefix = function ()
			matched = true
		end,
	})
	if matched then
		refreshIndicator()
	end
	return matched
end

local function fireSingleInMode(name, meta)
	local mode = M.modes[M.currentMode]
	if not mode then return end
	local key = canonicalKey(meta) or name
	local binding = mode.map and (mode.map[key] or mode.map[name])
	local fn = resolveBindingCallback(binding)
	if fn then
		hyperComboTriggered = true
		logger.info('Mode key (solo): ' .. name)
		pcall(fn)
	end
end

-- Mode keyDown handler using physical key state
local function handleModeKeyDown(name, meta)
	if meta and meta.isRepeat then return true end

	local mode = M.modes[M.currentMode]
	if not mode then return false end

	local canonical = canonicalKey(meta) or name
	local firstPress = (not M.held[name])
	if firstPress then M.participated[name] = false end
	M.held[name] = true

	-- Try both orders for a chord using any currently-held partner
	for other, _ in pairs(M.held) do
		if other ~= name then
			local fn = nil
			if mode.chords then fn = mode.chords[name .. other] or mode.chords[other .. name] end
			if not fn and mode.chords2 then
				local a, b = name, other; if a > b then a, b = b, a end
				fn = mode.chords2[a .. b]
			end
			fn = resolveBindingCallback(fn)
			if fn then
				M.participated[name] = true; M.participated[other] = true
				hyperComboTriggered = true
				logger.info('Mode chord: ' .. name .. '+' .. other)
				pcall(fn)
				return true
			end
		end
	end

	-- No chord yet; wait for release to fire solo
	local binding = mode.map and (mode.map[canonical] or mode.map[name])
	if binding then return true end
	return true
end

-- Main keyDown router
local function handleKeyDown(name, meta)
	if not name or name == '' then return false end
	if syntheticSuppressed() then return false end
	if hyperPendingDeactivate then
		cancelPendingDeactivate()
	elseif hyperComboDeadline > 0 then
		local now = hs.timer.secondsSinceEpoch()
		if now and now <= hyperComboDeadline then
			hyperComboDeadline = 0
			if not M.active then
				M.active = true
				refreshIndicator()
			end
			if M.leaderArmed then
				M.leaderArmed = false
				resetLeaderBuffer('combo-resume')
				refreshIndicator()
			end
		end
	end
	if name == 'escape' and M.modeActive then
		M.exitMode(); return true
	end
	if M.modeActive then
		return handleModeKeyDown(name, meta)
	end
	if M.active or M.leaderArmed then
		local canonical = canonicalKey(meta) or name
		logger.info('Hyper keyDown: ' .. tostring(canonical))
		pushLeaderKey(canonical)
		local matched = trySequences(); if matched then return consumeKeys end
		if M.active then
			local fn = M.bindings[canonical] or M.bindings[name]
			if fn then
				hyperComboTriggered = true
				fn();
				return consumeKeys
			end
		end
		return false
	end
	return false
end

-- Hyper press/release
local function finalizePendingDeactivate(force)
	local leaderEligible = pendingLeaderEligible
	local hadCombo = hyperComboTriggered
	cancelPendingDeactivate()
	M._downAt = nil
	local wasActive = M.active
	if not wasActive and not force then
		hyperComboTriggered = false
		return
	end
	if wasActive then
		M.active = false
		logger.info('Hyper OFF')
	else
		M.active = false
		if force then logger.info('Hyper OFF') end
	end
	hyperComboTriggered = false
	if leaderEligible and not hadCombo then
		if leaderTimer then
			leaderTimer:stop(); leaderTimer = nil
		end
		resetLeaderBuffer('leader-tap')
		local entered = enterLeaderRootFromTap()
		if entered then
			M.leaderArmed = false
		else
			resetLeaderBuffer('leader-arm')
			ensureLeaderBuffer()
			M.leaderArmed = true
			leaderTimer = timer.doAfter(leaderTimeout, function ()
				M.leaderArmed = false
				resetLeaderBuffer('leader-expire')
				updateStatusFlash()
				refreshIndicator()
				logger.info('Leader window expired')
			end)
		end
	else
		resetLeaderBuffer('disarm')
		M.leaderArmed = false
		if leaderTimer then
			leaderTimer:stop(); leaderTimer = nil
		end
	end
	refreshIndicator()
end

local function setActive(state, opts)
	if state then
		if hyperPendingDeactivate then cancelPendingDeactivate() end
		if M.active then return end
		M.active = true
		hyperComboTriggered = false
		hyperComboDeadline = 0
		logger.info('Hyper ON')
		M._downAt = hs.timer.secondsSinceEpoch()
		if leaderTimer then
			leaderTimer:stop(); leaderTimer = nil
		end
		ensureLeaderBuffer()
		refreshIndicator()
		return
	end

	if opts and opts.force then
		pendingLeaderEligible = false
		finalizePendingDeactivate(true)
		return
	end

	if hyperPendingDeactivate then return end

	local held = 0
	if M._downAt then held = hs.timer.secondsSinceEpoch() - M._downAt end
	M._downAt = nil
	pendingLeaderEligible = (held > 0 and held <= tapThreshold)
	hyperPendingDeactivate = true
	if pendingDeactivateTimer then pendingDeactivateTimer:stop() end
	hyperComboDeadline = hs.timer.secondsSinceEpoch() + hyperComboGrace
	pendingDeactivateTimer = timer.doAfter(hyperComboGrace, function ()
		finalizePendingDeactivate(false)
	end)
end

function M.start()
	if M._started then return end
	M._started = true
	ensureIndicator(); refreshIndicator()
	ensureLeaderBuffer()
	Engine.start()

	if not engineWired then
		Engine.onKeyDown(nil, function (ev, meta)
			if not M._started then return false end
			local name = meta and meta.name or ''
			if name == hyperKey then
				if meta and meta.isRepeat then return true end
				if M.modeActive then M.exitMode() end
				setActive(true)
				return true
			end
			if syntheticSuppressed() then return false end
			return handleKeyDown(name, meta)
		end)

		Engine.onKeyUp(nil, function (ev, meta)
			if not M._started then return false end
			local name = meta and meta.name or ''
			if name == hyperKey then
				setActive(false)
				return true
			end
			if syntheticSuppressed() then return false end
			if M.modeActive and name ~= '' then
				local now = hs.timer.secondsSinceEpoch()
				local canonical = canonicalKey(meta) or name
				if M.ignoreSoloKey == canonical and now <= (M.ignoreSoloUntil or 0) then
					M.ignoreSoloKey = nil; M.ignoreSoloUntil = 0; M.held[name] = nil; M.participated[name] = nil
					return true
				end
				local part = M.participated[name]
				M.held[name] = nil; M.participated[name] = nil
				if not part then fireSingleInMode(name, meta) end
				return true
			end
			return false
		end)

		engineWired = true
	end
	logger.info('Hyper modal with leader/modes started (hyper=' .. tostring(hyperKey) .. ')')
end

function M.stop()
	if not M._started then return end
	M._started = false
	M.leaderArmed = false
	cancelPendingDeactivate()
	M.active = false
	hyperComboTriggered = false
	resetLeaderBuffer('stop')
	if leaderTimer then
		leaderTimer:stop(); leaderTimer = nil
	end
	M.held = {}; M.participated = {}
	if M.ind then
		M.ind:delete(); M.ind = nil
	end
	logger.info('Hyper modal stopped')
end

-- Public API
function M.bindSpec(spec)
	if type(spec) ~= 'table' then
		logger.error('hyper_modal.bindSpec: expected table spec')
		return
	end

	local key = spec.key
	if key == nil then
		logger.error('hyper_modal.bindSpec: missing key in spec')
		return
	end

	local fn = spec.fn or spec.callback or spec.handler
	if type(fn) ~= 'function' then
		logger.error('hyper_modal.bindSpec: missing callable for key ' .. tostring(key))
		return
	end

	local description = spec.description
	if description == nil or description == '' then
		description = string.format('Hyper binding %s', tostring(key))
	end

	local actionDesc = spec.actionDescription or spec.actionLabel or spec.action
	if actionDesc == nil then actionDesc = describeFn(fn) end

	HotkeyManifest.recordBinding({
		scope = spec.scope,
		triggerType = spec.triggerType,
		trigger = spec.trigger or key,
		description = description,
		action = actionDesc,
		source = spec.source or captureCaller(spec.sourceDepth or 3),
		metadata = buildBindingMetadata(spec),
		tags = spec.tags,
	})

	local logLabel
	if spec.logLabel then
		logLabel = spec.logLabel
	elseif description then
		logLabel = description .. ' [' .. tostring(key) .. ']'
	else
		logLabel = tostring(key)
	end

	M.bindings[key] = function ()
		if M.active then hyperComboTriggered = true end
		if spec.log ~= false then
			logger.info('Binding fired: ' .. logLabel)
		end
		safeCall(fn)
	end
end

function M.bind(key, fn)
	M.bindSpec({ key = key, fn = fn })
end

function M.bindPassThrough(key, bundleID)
	M.bindings[key] = function ()
		logger.info('PassThrough fired: ' .. key .. (bundleID and (' -> ' .. bundleID) or ''))
		if bundleID then
			local app = application.get(bundleID); if app then app:activate(true) end
		end
		eventtap.keyStroke({ 'ctrl', 'alt', 'cmd', 'shift' }, key, 0)
	end
	HotkeyManifest.recordBinding({
		trigger = key,
		action = bundleID and ('passThrough:' .. bundleID) or 'passThrough',
		source = captureCaller(3),
		metadata = { scope = 'hyper', passThrough = true, bundleID = bundleID },
	})
end

function M.addSequence(keys, enterFn)
	M.addSequenceSpec({ keys = keys, fn = enterFn })
end

function M.addSequenceSpec(spec)
	if type(spec) ~= 'table' then
		logger.error('hyper_modal.addSequenceSpec: expected table spec')
		return
	end

	local keys = spec.keys or spec.sequence
	if type(keys) ~= 'table' then
		logger.error('hyper_modal.addSequenceSpec: sequence spec missing keys')
		return
	end

	local fn = spec.fn or spec.callback or spec.handler or spec.action
	if type(fn) ~= 'function' then
		logger.error('hyper_modal.addSequenceSpec: sequence spec missing callable')
		return
	end

	local description = spec.description
	if description == nil or description == '' then
		description = 'Hyper sequence ' .. table.concat(keys, '+')
	end

	local actionDesc = spec.actionDescription or spec.actionLabel or spec.action
	if actionDesc == nil then actionDesc = describeFn(fn) end

	local metadata = buildSequenceMetadata(spec, keys)

	HotkeyManifest.recordSequence({
		scope = spec.scope,
		triggerType = spec.triggerType,
		trigger = spec.trigger or keys,
		description = description,
		action = actionDesc,
		source = spec.source or captureCaller(spec.sourceDepth or 3),
		metadata = metadata,
		tags = spec.tags,
	})

	local logLabel
	if spec.logLabel then
		logLabel = spec.logLabel
	elseif description then
		logLabel = description .. ' (' .. table.concat(keys, '+') .. ')'
	else
		logLabel = table.concat(keys, '+')
	end

	table.insert(M.sequences, {
		keys = copyArray(keys),
		enter = function ()
			if spec.log ~= false then
				logger.info('Sequence matched: ' .. logLabel)
			end
			safeCall(fn)
		end,
	})
end

function M.defineMode(name, def)
	local compiled = ModeSpec.compile(name, def or {})
	M.modes[name] = compiled
	recordModeInManifest(name, compiled, def or {}, captureCaller(3))
end

function M.enterMode(name, key_actions)
	local modal_gui = require('hsLauncher.main.backup.core.modal_gui') -- Lazy load
	local mode = M.modes[name]
	if not mode then
		logger.error('Unknown mode: ' .. tostring(name)); return
	end
	M.modeActive = true; M.currentMode = name
	logger.info('Entered mode: ' .. name)

	local displayBindings, layout = collectDisplayBindings(name, mode, key_actions)
	modal_gui.show(name, displayBindings, layout)
	ensureIndicator(); M.ind:show('Mode: ' .. name); refreshIndicator()
	if type(mode.onEnter) == 'function' then pcall(mode.onEnter) end
end

function M.exitMode()
	local modal_gui = require('hsLauncher.main.backup.core.modal_gui') -- Lazy load
	if not M.modeActive then return end
	local name = M.currentMode; local mode = M.modes[name]
	M.modeActive = false; M.currentMode = nil
	logger.info('Exited mode: ' .. tostring(name))
	modal_gui.hide(name)
	ensureIndicator(); M.ind:flash('Exit: ' .. tostring(name), 0.8); refreshIndicator()
	if mode and type(mode.onExit) == 'function' then pcall(mode.onExit) end
	M.held = {}; M.participated = {}
end

function M.isModeActive(name)
	return M.modeActive and M.currentMode == name
end

function M.describeMode(name)
	local mode = M.modes[name]
	if not mode then return nil end
	local bindings, layout = collectDisplayBindings(name, mode)
	local orderedKeys = sortedBindingKeys(bindings)
	local entries = {}
	for _, key in ipairs(orderedKeys) do
		local info = bindings[key]
		if info then
			entries[#entries + 1] = {
				key = key,
				displayKey = info.displayKey or info.keyLabel or info.label or info.key or key,
				description = info.description,
				section = info.section,
				order = info.order,
				passive = info.passive,
				isExit = info.isExit,
				isChord = info.isChord,
			}
		end
	end
	return {
		name = name,
		entries = entries,
		layout = layout and shallowCopyTable(layout) or nil,
	}
end

function M.listModes()
	local names = {}
	for name in pairs(M.modes) do table.insert(names, name) end
	table.sort(names)
	local out = {}
	for _, name in ipairs(names) do
		out[name] = M.describeMode(name)
	end
	return out
end

function M.logMode(name)
	local info = M.describeMode(name)
	if not info then
		logger.warn('hyper_modal: unknown mode ' .. tostring(name))
		return
	end
	logger.info(string.format('Mode %s (%d entries)', info.name, #info.entries))
	for _, entry in ipairs(info.entries) do
		local section = entry.section and (entry.section .. ' · ') or ''
		local label = entry.displayKey or entry.key
		local suffix = ''
		if entry.isChord then suffix = suffix .. ' [chord]' end
		if entry.isExit then suffix = suffix .. ' [exit]' end
		if entry.passive and not entry.isExit then suffix = suffix .. ' [passive]' end
		logger.info(string.format('  %s%s -> %s%s', section, label, entry.description or '', suffix))
	end
end

return M

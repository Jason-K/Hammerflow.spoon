local Logger = require('hsLauncher.main.core.logger')
local Actions = require('hsLauncher.main.core.actions')
local ActionFactory = require('hsLauncher.main.runtime.action_factory')
local ComboUtils = require('hsLauncher.main.modules.hotkeys.combo_utils')

local Resolver = {}

local function emitError(errors, record)
	errors[#errors + 1] = record
end

local function emitWarning(logger, message)
	if type(logger) == 'function' then
		logger(message)
		return
	end
	if type(logger) == 'table' and type(logger.warn) == 'function' then
		logger.warn(message)
		return
	end
	if Logger and type(Logger.warn) == 'function' then
		Logger.warn(message)
	end
end

local function resolveLogger(options)
	if options and options.logger then
		return options.logger
	end
	return Logger
end

local function deepCopy(value, visited)
	if type(value) ~= 'table' then return value end
	visited = visited or {}
	if visited[value] then return visited[value] end
	local copy = {}
	visited[value] = copy
	for k, v in pairs(value) do
		copy[k] = deepCopy(v, visited)
	end
	return copy
end

local function normalizeKeyEntry(raw)
	local normalized = {
		key = ComboUtils.normalizeKey(raw.key),
		mods = ComboUtils.normalizeMods(raw.mods or {}),
		taps = math.max(1, tonumber(raw.taps) or 1),
	}
	if type(raw.hold) == 'table' then
		normalized.hold = {
			required = raw.hold.holdNeeded == true,
			timeMs = type(raw.hold.holdTimeMs) == 'number' and raw.hold.holdTimeMs or nil,
		}
	end
	return normalized
end

local function canonicalPart(key)
	local base = ComboUtils.comboKey(key.mods or {}, key.key)
	local suffix = {}
	if key.taps and key.taps > 1 then
		suffix[#suffix + 1] = 'x' .. tostring(key.taps)
	end
	if key.hold and key.hold.required then
		local holdLabel = 'hold'
		if key.hold.timeMs then
			holdLabel = holdLabel .. '@' .. tostring(key.hold.timeMs)
		end
		suffix[#suffix + 1] = holdLabel
	end
	if #suffix > 0 then
		return base .. '(' .. table.concat(suffix, ',') .. ')'
	end
	return base
end

local function canonicalKey(triggerType, keys)
	local parts = {}
	for index, key in ipairs(keys) do
		parts[index] = canonicalPart(key)
	end
	if triggerType == 'chord' or triggerType == 'single' then
		table.sort(parts)
	end
	return triggerType .. ':' .. table.concat(parts, '>')
end

local function buildTrigger(actionId, trigger, logger)
	if type(trigger) ~= 'table' then
		return nil, { code = 'hotkey.trigger.invalid', message = string.format('action %s hotkey trigger must be table', tostring(actionId)) }
	end

	local keysRaw = trigger.keys
	if type(keysRaw) ~= 'table' or #keysRaw == 0 then
		return nil, { code = 'hotkey.trigger.keys.missing', message = string.format('action %s hotkey missing trigger keys', tostring(actionId)) }
	end

	local normalizedKeys = {}
	for index, raw in ipairs(keysRaw) do
		local normalized = normalizeKeyEntry(raw)
		if not normalized.key or normalized.key == '' then
			return nil, {
				code = 'hotkey.trigger.key.invalid',
				message = string.format('action %s hotkey key index %d invalid', tostring(actionId), index),
			}
		end
		normalizedKeys[index] = normalized
	end

	local triggerType
	if #normalizedKeys == 1 then
		triggerType = 'single'
	else
		triggerType = trigger.multikeyType or 'chord'
		if triggerType ~= 'chord' and triggerType ~= 'sequence' then
			emitWarning(logger, string.format('runtime.hotkey_resolver: action %s missing multikeyType; defaulting to chord', tostring(actionId)))
			triggerType = 'chord'
		end
	end

	local canonical = canonicalKey(triggerType, normalizedKeys)

	return {
		type = triggerType,
		keys = normalizedKeys,
		canonical = canonical,
		sequenceTimeoutMs = tonumber(trigger.sequenceTimeoutMs) or nil,
		original = deepCopy(trigger),
	}, nil
end

local function contextsFromHotkey(hotkey)
	local contexts = {}
	if type(hotkey.context) ~= 'table' or #hotkey.context == 0 then
		contexts[1] = { id = 'global', active = true }
		return contexts
	end
	for index, ctx in ipairs(hotkey.context) do
		local id = type(ctx.context) == 'string' and ctx.context ~= '' and ctx.context or 'global'
		local active = ctx.active
		if active == nil then active = true end
		contexts[index] = { id = id, active = active == true }
	end
	return contexts
end

local function describeAction(action)
	local menuDetails = type(action.menuDetails) == 'table' and action.menuDetails or {}
	return menuDetails.description or action.description or action.name or 'action'
end

---@param actions table
---@param options table|nil
---@return table result
function Resolver.resolve(actions, options)
	local logger = resolveLogger(options)
	local assignments = {}
	local suppressed = {}
	local disabled = {}
	local errors = {}
	local conflictBuckets = {}

	for _, action in ipairs(actions or {}) do
		if type(action) ~= 'table' then goto continue end

		local actionId = action.name
		if type(actionId) ~= 'string' or actionId == '' then goto continue end

		if action.enabled == false then
			disabled[#disabled + 1] = { actionId = actionId, reason = 'disabled' }
			goto continue
		end

		local hotkey = action.hotkey
		if type(hotkey) ~= 'table' or type(hotkey.trigger) ~= 'table' then goto continue end

		local trigger, triggerErr = buildTrigger(actionId, hotkey.trigger, logger)
		if not trigger then
			emitError(errors, triggerErr)
			goto continue
		end

		local actionSpec = ActionFactory.compile(action, { logger = logger })
		local handler = actionSpec and Actions.resolve(actionSpec)
		if not handler then
			emitError(errors, {
				code = 'hotkey.action.unresolvable',
				message = string.format('action %s hotkey could not resolve to callable', actionId),
			})
			goto continue
		end

		local contexts = contextsFromHotkey(hotkey)
		for _, context in ipairs(contexts) do
			if not context.active then
				suppressed[#suppressed + 1] = {
					actionId = actionId,
					context = context.id,
					trigger = trigger,
				}
				goto next_context
			end

			local assignment = {
				actionId = actionId,
				context = context.id,
				triggerType = trigger.type,
				trigger = trigger,
				handler = handler,
				actionSpec = actionSpec,
				guard = action.guard,
				tags = deepCopy(action.tags or {}),
				description = describeAction(action),
				menuDetails = deepCopy(action.menuDetails or {}),
				source = deepCopy(action.source or {}),
			}

			assignments[#assignments + 1] = assignment

			local contextBucket = conflictBuckets[assignment.context]
			if not contextBucket then
				contextBucket = {}
				conflictBuckets[assignment.context] = contextBucket
			end

			local bucketKey = assignment.trigger.canonical
			contextBucket[bucketKey] = contextBucket[bucketKey] or {}
			contextBucket[bucketKey][#contextBucket[bucketKey] + 1] = assignment

			::next_context::
		end

		::continue::
	end

	local conflicts = {}
	for contextId, bucket in pairs(conflictBuckets) do
		for canonical, entries in pairs(bucket) do
			if #entries > 1 then
				conflicts[#conflicts + 1] = {
					context = contextId,
					canonical = canonical,
					triggerType = entries[1].triggerType,
					assignments = entries,
				}
			end
		end
	end

	table.sort(conflicts, function (a, b)
		if a.context == b.context then
			return a.canonical < b.canonical
		end
		return a.context < b.context
	end)

	return {
		assignments = assignments,
		suppressed = suppressed,
		disabled = disabled,
		errors = errors,
		conflicts = conflicts,
	}
end

return Resolver

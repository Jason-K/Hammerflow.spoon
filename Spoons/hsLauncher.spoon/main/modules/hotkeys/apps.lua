--- @diagnostic disable: undefined-global

local Actions = require('hsLauncher.main.core.actions')

local M = {}

local function evaluateCondition(condition, context)
	if condition == nil then return true end
	if type(condition) == 'boolean' then return condition end
	if type(condition) == 'function' then
		local ok, result = pcall(condition, context)
		if not ok then return false end
		return result and result ~= false
	end
	return true
end

local wrapWithCondition

local function resolveAction(entry, userAction, context)
	local action = entry.action or entry.actionSpec or entry.handler
	if type(action) == 'string' and userAction then
		action = userAction(action)
	end
	if type(action) == 'function' then
		action = Actions.call(action)
	end
	if action == nil and entry.ref and userAction then
		action = userAction(entry.ref)
	end
	if action == nil and type(entry.userAction) == 'string' and userAction then
		action = userAction(entry.userAction)
	end
	if action and entry.when then
		action = wrapWithCondition(action, entry.when, context)
	end
	return action
end

wrapWithCondition = function (spec, condition, context)
	if condition == nil then return spec end
	local fn = Actions.resolve(spec)
	if not fn then return spec end
	return Actions.call(function ()
		if evaluateCondition(condition, context) then fn() end
	end)
end
local function realizeEntries(entries, context)
	if type(entries) == 'function' then
		local ok, result = pcall(entries, context)
		if ok then entries = result else entries = {} end
	end
	return entries or {}
end

local function buildEntries(entries, userAction, context)
	local mapped = {}
	for _, entry in ipairs(realizeEntries(entries, context)) do
		table.insert(mapped, {
			key = entry.key,
			description = entry.description,
			action = resolveAction(entry, userAction, context) or entry.action,
			exitAfter = entry.exitAfter,
			order = entry.order,
			section = entry.section,
			note = entry.note,
			badge = entry.badge,
			label = entry.label,
			passive = entry.passive,
			metadata = entry.metadata,
			wrap = entry.wrap,
			multiline = entry.multiline,
		})
	end
	return mapped
end

local function applyTriggers(hyper, modeName, triggers, opts, context)
	local bindSpec = hyper.bindSpec and function (spec)
		hyper.bindSpec(spec)
	end or function (spec)
		hyper.bind(spec.key, spec.fn)
	end

	local addSequenceSpec = hyper.addSequenceSpec and function (spec)
		hyper.addSequenceSpec(spec)
	end or function (spec)
		hyper.addSequence(spec.keys, spec.fn)
	end

	for _, trigger in ipairs(triggers or {}) do
		local triggerContext = context
		if trigger.context then
			triggerContext = setmetatable({}, { __index = context })
			for k, v in pairs(trigger.context) do triggerContext[k] = v end
		end
		local shouldEnter = function ()
			return evaluateCondition(trigger.when, triggerContext) and evaluateCondition(opts.when, triggerContext)
		end
		if trigger.kind == 'sequence' and trigger.keys then
			addSequenceSpec({
				keys = trigger.keys,
				fn = function ()
					if shouldEnter() then hyper.enterMode(modeName) end
				end,
				description = trigger.description or string.format('Enter %s mode', modeName),
				label = trigger.label,
				note = trigger.note,
				metadata = trigger.metadata,
				tags = trigger.tags,
				source = trigger.source,
			})
		elseif trigger.kind == 'bind' and trigger.key then
			bindSpec({
				key = trigger.key,
				fn = function ()
					if shouldEnter() then hyper.enterMode(modeName) end
				end,
				description = trigger.description or string.format('Enter %s mode', modeName),
				label = trigger.label,
				note = trigger.note,
				metadata = trigger.metadata,
				tags = trigger.tags,
				source = trigger.source,
			})
		end
	end
end

function M.add(hyper, opts)
	local modeName = opts.mode or opts.id
	if not modeName then return end

	local userAction = opts.userAction
	local context = {
		hyper = hyper,
		mode = modeName,
		opts = opts,
		userAction = userAction,
		Actions = Actions,
	}
	local entries = buildEntries(opts.entries, userAction, context)

	hyper.defineMode(modeName, {
		consume = opts.consume ~= false,
		onEnter = opts.onEnter,
		onExit = opts.onExit,
		layout = opts.layout,
		entries = entries,
		chords = opts.chords,
		chordEntries = opts.chordEntries,
		passthrough = opts.passthrough,
		exitKeys = opts.exitKeys,
		exitDescription = opts.exitDescription,
	})

	applyTriggers(hyper, modeName, opts.triggers, opts, context)
end

return M

local Actions = require('hsLauncher.main.core.actions')
local logger = require('hsLauncher.main.core.logger')
local AppHotkeys = require('hsLauncher.main.modules.hotkeys.apps')
local buildHandlers = require('hsLauncher.main.modules.hotkeys.handlers')
local buildPredicates = require('hsLauncher.main.modules.hotkeys.predicates')

local Loader = {}

local function shallowCopy(obj)
	if type(obj) ~= 'table' then return obj end
	local copy = {}
	for k, v in pairs(obj) do copy[k] = v end
	return copy
end

local function copyArray(list)
	if type(list) ~= 'table' then return {} end
	local out = {}
	for index, value in ipairs(list) do out[index] = value end
	return out
end

local function buildEnv(context)
	local envLogger = context.logger or logger
	return {
		context = context,
		logger = envLogger,
		handlers = buildHandlers(context),
		predicates = buildPredicates(context),
		userAction = context.userAction or function ()
			return Actions.noop()
		end,
	}
end

local function warn(env, message)
	if env.logger and env.logger.warn then
		env.logger.warn('[hotkeys.loader] ' .. message)
	end
end

local function buildActionSpec(spec, env)
	if spec == nil then return nil end
	local specType = type(spec)
	if specType == 'function' or specType == 'thread' then
		return Actions.call(spec)
	end
	if specType ~= 'table' then
		if specType == 'string' then
			return env.userAction(spec)
		end
		warn(env, 'Unsupported action spec type: ' .. specType)
		return Actions.noop()
	end

	local kind = spec.kind or spec.type
	if not kind then
		warn(env, 'Action spec missing kind; defaulting to noop')
		return Actions.noop()
	end

	if kind == 'window' then
		return Actions.window(spec.method)
	elseif kind == 'actions' then
		local fn = Actions[spec.method]
		if type(fn) ~= 'function' then
			warn(env, 'Unknown Actions method: ' .. tostring(spec.method))
			return Actions.noop()
		end
		if spec.args == nil then
			return fn()
		elseif type(spec.args) == 'table' then
			return fn(table.unpack(spec.args))
		else
			return fn(spec.args)
		end
	elseif kind == 'moduleFn' then
		return Actions.moduleFn(spec.module, spec.method, spec.args)
	elseif kind == 'keystroke' then
		return Actions.keystroke(spec.key, spec.mods)
	elseif kind == 'open' then
		return Actions.open(shallowCopy(spec.target))
	elseif kind == 'shell' then
		return Actions.shell(spec.cmd)
	elseif kind == 'applescript' then
		return Actions.applescript(spec.path)
	elseif kind == 'hsFunction' then
		return Actions.hsFunction(spec.name, spec.args)
	elseif kind == 'sequence' then
		local steps = {}
		for index, step in ipairs(spec.steps or {}) do
			steps[index] = buildActionSpec(step, env)
		end
		return Actions.sequence(steps)
	elseif kind == 'sequenceExec' then
		local steps = {}
		for index, step in ipairs(spec.specs or {}) do
			if type(step) == 'table' then
				steps[index] = Actions.exec(step)
			end
		end
		return Actions.sequence(steps)
	elseif kind == 'exec' then
		return Actions.exec(shallowCopy(spec.spec))
	elseif kind == 'userAction' then
		return env.userAction(spec.id)
	elseif kind == 'handler' then
		local handler = env.handlers[spec.name]
		if not handler then
			warn(env, 'Unknown handler: ' .. tostring(spec.name))
			return Actions.noop()
		end
		return handler(spec.args)
	elseif kind == 'noop' then
		return Actions.noop()
	end

	warn(env, 'Unhandled action kind: ' .. tostring(kind))
	return Actions.noop()
end

local function resolveActionFn(spec, env)
	if spec == nil then return nil end
	if type(spec) == 'function' then return spec end
	local actionSpec = buildActionSpec(spec, env)
	if not actionSpec then return nil end
	return Actions.resolve(actionSpec)
end

local function buildConditionFn(condition, env)
	if condition == nil then return nil end
	local condType = type(condition)
	if condType == 'boolean' then
		local value = condition
		return function () return value end
	elseif condType == 'function' then
		return function (ctx)
			local ok, result = pcall(condition, ctx)
			if not ok then
				warn(env, 'Condition function errored: ' .. tostring(result)); return false
			end
			return result and result ~= false
		end
	elseif condType == 'string' then
		local predicate = env.predicates[condition]
		if not predicate then
			warn(env, 'Unknown predicate: ' .. condition)
			return function () return false end
		end
		return function () return predicate() end
	elseif condType == 'table' then
		local kind = condition.kind or condition.type
		if kind == 'predicate' then
			local predicate = env.predicates[condition.name]
			if not predicate then
				warn(env, 'Unknown predicate: ' .. tostring(condition.name))
				return function () return false end
			end
			local args = condition.args
			return function ()
				return predicate(args)
			end
		elseif kind == 'not' then
			local inner = buildConditionFn(condition.value, env)
			return function (ctx)
				if not inner then return true end
				return not inner(ctx)
			end
		elseif kind == 'any' then
			local parts = {}
			for index, part in ipairs(condition.conditions or {}) do
				parts[index] = buildConditionFn(part, env)
			end
			return function (ctx)
				for _, fn in ipairs(parts) do
					if fn and fn(ctx) then return true end
				end
				return false
			end
		elseif kind == 'all' then
			local parts = {}
			for index, part in ipairs(condition.conditions or {}) do
				parts[index] = buildConditionFn(part, env)
			end
			return function (ctx)
				for _, fn in ipairs(parts) do
					if fn and not fn(ctx) then return false end
				end
				return true
			end
		end
	end
	warn(env, 'Unsupported condition type: ' .. condType)
	return function () return false end
end

local function wrapActionWithCondition(fn, conditionFn)
	if not conditionFn then return fn end
	return function ()
		if conditionFn() then fn() end
	end
end

local function buildModeChordMap(chordDefs, env)
	if type(chordDefs) ~= 'table' then return nil end
	local map = {}
	for _, chord in ipairs(chordDefs) do
		if chord and chord.keys then
			local fn = resolveActionFn(chord.action, env)
			if fn then
				local keys = chord.keys
				if #keys == 2 then
					local a, b = keys[1], keys[2]
					map[a .. b] = fn
					map[b .. a] = fn
				else
					map[table.concat(keys)] = fn
				end
			end
		end
	end
	return map
end

local function buildModeEntries(entries, env)
	local out = {}
	for _, entry in ipairs(entries or {}) do
		local copy = shallowCopy(entry)
		copy.action = buildActionSpec(entry.action, env)
		out[#out + 1] = copy
	end
	return out
end

local function applyHyperBindings(hyper, config, env)
	local bindWithMetadata = hyper.bindSpec and function (spec)
		hyper.bindSpec(spec)
	end or function (spec)
		hyper.bind(spec.key, spec.fn)
	end

	for index, binding in ipairs(config.hyperBindings or {}) do
		if binding.key then
			local fn = resolveActionFn(binding.action, env)
			if fn then
				local conditionFn = buildConditionFn(binding.when, env)
				bindWithMetadata({
					key = binding.key,
					fn = wrapActionWithCondition(fn, conditionFn),
					description = binding.description,
					label = binding.label,
					note = binding.note,
					metadata = binding.metadata,
					tags = binding.tags,
					source = binding.source or string.format('user.hotkeys.config:hyperBindings[%d]', index),
				})
			end
		end
	end
end

local function applyModes(hyper, config, env)
	for name, def in pairs(config.modes or {}) do
		local modeSpec = {
			consume = def.consume,
			layout = def.layout and shallowCopy(def.layout) or nil,
			entries = buildModeEntries(def.entries, env),
			chords = buildModeChordMap(def.chords, env),
			chordEntries = def.chordEntries and copyArray(def.chordEntries) or nil,
			passthrough = def.passthrough,
			exitKeys = def.exitKeys and copyArray(def.exitKeys) or nil,
			exitDescription = def.exitDescription,
		}

		local onEnter = resolveActionFn(def.onEnter, env)
		if onEnter then modeSpec.onEnter = onEnter end
		local onExit = resolveActionFn(def.onExit, env)
		if onExit then modeSpec.onExit = onExit end

		hyper.defineMode(name, modeSpec)
	end
end

local function applySequences(hyper, config, env)
	local addSequence = hyper.addSequenceSpec and function (spec)
		hyper.addSequenceSpec(spec)
	end or function (spec)
		hyper.addSequence(spec.keys, spec.fn)
	end

	for index, seq in ipairs(config.sequences or {}) do
		if seq.keys then
			local fn = resolveActionFn(seq.action, env)
			if fn then
				local conditionFn = buildConditionFn(seq.when, env)
				addSequence({
					keys = seq.keys,
					fn = wrapActionWithCondition(fn, conditionFn),
					description = seq.description,
					label = seq.label,
					note = seq.note,
					metadata = seq.metadata,
					tags = seq.tags,
					source = seq.source or string.format('user.hotkeys.config:sequences[%d]', index),
				})
			end
		end
	end
end

local function convertEntries(entries, env)
	local out = {}
	for _, entry in ipairs(entries or {}) do
		local copy = shallowCopy(entry)
		copy.action = buildActionSpec(entry.action, env)
		if entry.when then
			local conditionFn = buildConditionFn(entry.when, env)
			if conditionFn then
				copy.when = function ()
					return conditionFn()
				end
			end
		end
		out[#out + 1] = copy
	end
	return out
end

local function applyAppModes(hyper, config, env)
	for appIndex, appDef in ipairs(config.apps or {}) do
		local opts = shallowCopy(appDef)
		if opts.entries then
			opts.entries = convertEntries(opts.entries, env)
		end
		if opts.when then
			local conditionFn = buildConditionFn(opts.when, env)
			if conditionFn then
				opts.when = function ()
					return conditionFn()
				end
			else
				opts.when = nil
			end
		end
		if opts.triggers then
			local triggers = {}
			for triggerIndex, trigger in ipairs(opts.triggers) do
				local copy = shallowCopy(trigger)
				if trigger.when then
					local conditionFn = buildConditionFn(trigger.when, env)
					if conditionFn then
						copy.when = function ()
							return conditionFn()
						end
					end
				end
				copy.source = trigger.source or
				string.format('user.hotkeys.config:apps[%d].triggers[%d]', appIndex, triggerIndex)
				copy.metadata = trigger.metadata or {
					appId = opts.id,
					triggerKind = trigger.kind,
				}
				if not copy.description then
					local modeLabel = opts.mode or opts.id or 'app'
					copy.description = string.format('Enter %s mode', modeLabel)
				end
				triggers[#triggers + 1] = copy
			end
			opts.triggers = triggers
		end
		opts.userAction = env.userAction
		AppHotkeys.add(hyper, opts)
	end
end

function Loader.apply(context)
	local hyper = context.hyper
	if not hyper then
		local envLogger = context.logger or logger
		envLogger.error('hotkeys.loader: hyper reference missing')
		return
	end

	local ok, config = pcall(require, 'hsLauncher.main.user.hotkeys.config')
	if not ok then
		local envLogger = context.logger or logger
		envLogger.error('hotkeys.loader: unable to load config -> ' .. tostring(config))
		return
	end

	local env = buildEnv(context)

	applyHyperBindings(hyper, config, env)
	applyModes(hyper, config, env)
	applySequences(hyper, config, env)
	applyAppModes(hyper, config, env)
end

return Loader

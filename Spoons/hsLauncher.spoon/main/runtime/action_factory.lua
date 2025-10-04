local Actions = require('hsLauncher.main.core.actions')
local Logger = require('hsLauncher.main.core.logger')

local ActionFactory = {}

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

local function emitWarn(logger, message)
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

local function buildSteps(action, options)
	local steps = {}
	local logger = resolveLogger(options)
	for index, step in ipairs(action.actions or {}) do
		local stepType = type(step)
		if stepType == 'table' then
			steps[#steps + 1] = deepCopy(step)
		elseif stepType == 'function' then
			steps[#steps + 1] = Actions.call(step)
		elseif stepType == 'string' then
			emitWarn(logger, string.format('runtime.action_factory: action %s uses deprecated string step at index %d', tostring(action.name), index))
		else
			emitWarn(logger, string.format('runtime.action_factory: action %s has unsupported step type %s at index %d', tostring(action.name), stepType, index))
		end
	end
	return steps
end

---@param action table|nil
---@param options table|nil
---@return table|nil
function ActionFactory.compile(action, options)
	if type(action) ~= 'table' then return nil end
	local steps = buildSteps(action, options)
	if #steps == 0 then
		return Actions.noop()
	end
	if #steps == 1 then
		return steps[1]
	end
	return Actions.sequence(steps)
end

---@param action table|nil
---@param options table|nil
---@return function|nil
function ActionFactory.resolve(action, options)
	local spec = ActionFactory.compile(action, options)
	if not spec then return nil end
	return Actions.resolve(spec)
end

---@param spec table|nil
---@return function|nil
function ActionFactory.resolveSpec(spec)
	if not spec then return nil end
	return Actions.resolve(spec)
end

return ActionFactory

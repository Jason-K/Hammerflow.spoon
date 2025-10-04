local Logger = require('hsLauncher.main.core.logger')
local DefaultRegistrar = require('hsLauncher.main.runtime.hyper.registrar')

local Dispatcher = {}
Dispatcher.__index = Dispatcher

---@class HyperDispatcherSummaryContext
---@field id string
---@field assignments integer
---@field bindings integer

---@class HyperDispatcherOptions
---@field logger table|function|nil
---@field registrar table|nil
---@field registrarOptions table|nil

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

local function resolveLogger(options)
	if options and options.logger then
		return options.logger
	end
	return Logger
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

local function indexAssignments(assignments)
	local contexts = {}
	for _, assignment in ipairs(assignments or {}) do
		local contextId = assignment.context or 'global'
		local contextBucket = contexts[contextId]
		if not contextBucket then
			contextBucket = {
				assignments = {},
				slots = {},
			}
			contexts[contextId] = contextBucket
		end
		contextBucket.assignments[#contextBucket.assignments + 1] = assignment

		local canonical = assignment.trigger and assignment.trigger.canonical
		if canonical then
			local slot = contextBucket.slots[canonical]
			if not slot then
				slot = {}
				contextBucket.slots[canonical] = slot
			end
			slot[#slot + 1] = assignment
		end
	end
	return contexts
end

local function resolveRegistrar(options)
	if options and options.registrar then
		return options.registrar
	end
	return DefaultRegistrar.new(options and options.registrarOptions or nil)
end

---@param resolution table|nil
---@param options HyperDispatcherOptions|nil
---@return table
function Dispatcher.new(resolution, options)
	local opts = options or {}
	local assignments = deepCopy(resolution and resolution.assignments or {})
	local dispatcher = {
		assignments = assignments,
		contexts = indexAssignments(assignments),
		resolution = {
			suppressed = deepCopy(resolution and resolution.suppressed or {}),
			disabled = deepCopy(resolution and resolution.disabled or {}),
			errors = deepCopy(resolution and resolution.errors or {}),
			conflicts = deepCopy(resolution and resolution.conflicts or {}),
		},
		logger = resolveLogger(opts),
		registrar = resolveRegistrar(opts),
		active = {},
	}
	return setmetatable(dispatcher, Dispatcher)
end

local function ensureContextRecord(active, contextId)
	local record = active[contextId]
	if not record then
		record = { bindings = {}, assignments = {} }
		active[contextId] = record
	end
	return record
end

---@return table contexts
function Dispatcher:registerAll()
	local results = {}
	for contextId, bucket in pairs(self.contexts) do
		local ok, contextInfo = pcall(function ()
			return self.registrar:registerContext(contextId, bucket.assignments)
		end)
		if ok and contextInfo then
			results[contextId] = contextInfo
			local record = ensureContextRecord(self.active, contextId)
			record.bindings = deepCopy(contextInfo.bindings or {})
			record.assignments = deepCopy(contextInfo.assignments or bucket.assignments)
		else
			emitWarn(self.logger, string.format('runtime.hyper.dispatcher: failed to register context %s: %s', tostring(contextId), contextInfo or 'unknown error'))
		end
	end
	return results
end

---@param contextId string
---@return table|nil
function Dispatcher:getContext(contextId)
	if not contextId then return nil end
	return self.contexts[contextId]
end

---@return HyperDispatcherSummaryContext[]
function Dispatcher:summary()
	local summary = {}
	for contextId, record in pairs(self.active) do
		summary[#summary + 1] = {
			id = contextId,
			assignments = #(record.assignments or {}),
			bindings = #(record.bindings or {}),
		}
	end
	table.sort(summary, function (a, b)
		return (a.id or '') < (b.id or '')
	end)
	return summary
end

---@return integer released
function Dispatcher:teardown()
	local ok, released = pcall(function ()
		return self.registrar:teardownAll()
	end)
	if not ok then
		emitWarn(self.logger, 'runtime.hyper.dispatcher: registrar teardown failed: ' .. tostring(released))
		return 0
	end
	self.active = {}
	return released or 0
end

return Dispatcher

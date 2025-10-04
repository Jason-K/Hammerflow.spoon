local Logger = require('hsLauncher.main.core.logger')

local Registrar = {}
Registrar.__index = Registrar

---@class HyperRegistrarOptions
---@field logger table|function|nil
---@field hotkeyAdapter table|nil

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

local function createDefaultAdapter()
	local hs = rawget(_G, 'hs')
	local hotkey = hs and hs.hotkey
	if hotkey and type(hotkey.bind) == 'function' then
		local adapter = {}
		function adapter:register(contextId, assignment)
			local trigger = assignment.trigger or {}
			local primary = trigger.keys and trigger.keys[1] or {}
			local mods = primary.mods or {}
			local key = primary.key
			local handler = assignment.handler
			local binding = hotkey.bind(mods, key, handler)
			return binding
		end
		function adapter:unregister(binding)
			if binding and type(binding.delete) == 'function' then
				binding:delete()
			end
		end
		return adapter
	end

	local adapter = { calls = {}, released = {} }
	function adapter:register(contextId, assignment)
		local record = {
			context = contextId,
			canonical = assignment.trigger and assignment.trigger.canonical,
			actionId = assignment.actionId or assignment.name,
			description = assignment.description,
			assignment = assignment,
		}
		self.calls[#self.calls + 1] = record
		return {
			record = record,
		}
	end
	function adapter:unregister(binding)
		binding = binding or {}
		binding.record = binding.record or {}
		self.released[#self.released + 1] = binding.record
	end
	return adapter
end

---@param options HyperRegistrarOptions|nil
---@return table
function Registrar.new(options)
	local opts = options or {}
	local registrar = {
		logger = resolveLogger(opts),
		adapter = opts.hotkeyAdapter or createDefaultAdapter(),
		contexts = {},
		totalBindings = 0,
	}
	return setmetatable(registrar, Registrar)
end

local function ensureContext(registrar, contextId)
	local record = registrar.contexts[contextId]
	if not record then
		record = { bindings = {}, assignments = {} }
		registrar.contexts[contextId] = record
	end
	return record
end

---@param contextId string
---@param assignments table[]
---@return table
function Registrar:registerContext(contextId, assignments)
	local record = ensureContext(self, contextId)
	for _, assignment in ipairs(assignments or {}) do
		local adapter = self.adapter
		if not adapter or type(adapter.register) ~= 'function' then
			emitWarn(self.logger, 'runtime.hyper.registrar: missing hotkey adapter register() implementation')
			goto continue
		end
		local ok, binding = pcall(function ()
			return adapter:register(contextId, assignment)
		end)
		if ok and binding then
			record.bindings[#record.bindings + 1] = binding
			record.assignments[#record.assignments + 1] = assignment
			self.totalBindings = self.totalBindings + 1
		else
			emitWarn(self.logger, string.format('runtime.hyper.registrar: failed to register %s in context %s (%s)', tostring(assignment.actionId or assignment.name), tostring(contextId), binding or 'unknown error'))
		end
		::continue::
	end
	return {
		bindings = record.bindings,
		assignments = record.assignments,
	}
end

---@param contextId string
---@return integer
function Registrar:teardownContext(contextId)
	local record = self.contexts[contextId]
	if not record then return 0 end
	local count = 0
	for _, binding in ipairs(record.bindings) do
		if binding and self.adapter and type(self.adapter.unregister) == 'function' then
			local ok, err = pcall(function ()
				self.adapter:unregister(binding)
			end)
			if not ok then
				emitWarn(self.logger, 'runtime.hyper.registrar: failed to unregister binding: ' .. tostring(err))
			end
		end
		count = count + 1
	end
	self.contexts[contextId] = nil
	self.totalBindings = math.max(0, self.totalBindings - count)
	return count
end

---@return integer
function Registrar:teardownAll()
	local total = 0
	for contextId in pairs(self.contexts) do
		total = total + self:teardownContext(contextId)
	end
	return total
end

---@return table
function Registrar:summary()
	local summary = {}
	for contextId, record in pairs(self.contexts) do
		summary[#summary + 1] = {
			context = contextId,
			assignments = #(record.assignments or {}),
			bindings = #(record.bindings or {}),
		}
	end
	table.sort(summary, function (a, b)
		return (a.context or '') < (b.context or '')
	end)
	return summary
end

return Registrar

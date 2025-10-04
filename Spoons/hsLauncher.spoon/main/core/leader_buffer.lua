local timer = require('hs.timer')

local LeaderBuffer = {}
LeaderBuffer.__index = LeaderBuffer

local function shallowCopy(list)
	local out = {}
	for i, value in ipairs(list) do out[i] = value end
	return out
end

function LeaderBuffer.new(opts)
	opts = opts or {}
	local self = setmetatable({}, LeaderBuffer)
	self.timeout = opts.timeout or 1.5
	self.onTimeout = opts.onTimeout
	self.onUpdate = opts.onUpdate
	self._buffer = {}
	self._timer = nil
	return self
end

function LeaderBuffer:updateCallbacks(callbacks)
	if not callbacks then return end
	if callbacks.onTimeout ~= nil then self.onTimeout = callbacks.onTimeout end
	if callbacks.onUpdate ~= nil then self.onUpdate = callbacks.onUpdate end
end

function LeaderBuffer:setTimeout(seconds)
	if type(seconds) == 'number' and seconds > 0 then
		self.timeout = seconds
	end
end

function LeaderBuffer:get()
	return self._buffer
end

function LeaderBuffer:size()
	return #self._buffer
end

function LeaderBuffer:clear(reason)
	self._buffer = {}
	if self._timer then
		self._timer:stop()
		self._timer = nil
	end
	if self.onUpdate then
		local info = { reason = reason or 'clear' }
		self.onUpdate(shallowCopy(self._buffer), info)
	end
end

function LeaderBuffer:_armTimer()
	if self.timeout <= 0 then return end
	if self._timer then self._timer:stop() end
	self._timer = timer.doAfter(self.timeout, function ()
		self._timer = nil
		if self.onTimeout then self.onTimeout(self) end
		self:clear('timeout')
	end)
end

function LeaderBuffer:push(key)
	if key == nil then return self._buffer end
	table.insert(self._buffer, key)
	self:_armTimer()
	if self.onUpdate then
		local info = { reason = 'push', key = key }
		self.onUpdate(shallowCopy(self._buffer), info)
	end
	return self._buffer
end

function LeaderBuffer:match(sequence)
	if type(sequence) ~= 'table' then return 'none' end
	local len = #sequence
	for idx, key in ipairs(self._buffer) do
		if idx > len or key ~= sequence[idx] then return 'none' end
	end
	if #self._buffer == len then return 'full' end
	return 'prefix'
end

function LeaderBuffer:evaluate(sequences, opts)
	if type(sequences) ~= 'table' then return false end
	opts = opts or {}
	for _, seq in ipairs(sequences) do
		local keys = seq.keys or seq
		local state = self:match(keys)
		if state == 'full' then
			self:clear('match')
			if opts.onFull then opts.onFull(seq) end
			return true, seq
		elseif state == 'prefix' then
			if opts.onPrefix then opts.onPrefix(seq) end
			return true, nil
		end
	end
	return false
end

return LeaderBuffer

local logger = require('hsLauncher.main.core.logger')

local Diagnostics = {}

local function callLogger(primary, fallback, line)
	local handler = primary or fallback or function() end
	handler(line)
end

local function stringifyContext(context)
	if type(context) ~= 'table' then return nil end
	local entries = {}
	for key, value in pairs(context) do
		entries[#entries + 1] = string.format('%s=%s', tostring(key), tostring(value))
	end
	table.sort(entries)
	if #entries == 0 then return nil end
	return table.concat(entries, ' ')
end

local function logEntries(level, prefix, entries)
	if type(entries) ~= 'table' then return end
	for _, entry in ipairs(entries) do
		local message = entry.message or 'diagnostic emitted without message'
		if entry.code then
			message = string.format('%s [%s]', message, entry.code)
		end
		local context = stringifyContext(entry.context)
		if context then
			message = string.format('%s (%s)', message, context)
		end
		local line = string.format('%s %s', prefix, message)
		if level == 'error' then
			callLogger(logger.error, logger.info, line)
		elseif level == 'warn' then
			callLogger(logger.warn, logger.info, line)
		else
			callLogger(logger.info, nil, line)
		end
	end
end

local function logConflicts(prefix, conflicts)
	if type(conflicts) ~= 'table' then return end
	for _, conflict in ipairs(conflicts) do
		local parts = {}
		if conflict.menu then parts[#parts + 1] = 'menu=' .. tostring(conflict.menu) end
		if conflict.item then parts[#parts + 1] = 'item=' .. tostring(conflict.item) end
		if conflict.assigned then parts[#parts + 1] = 'assigned=' .. tostring(conflict.assigned) end
		if conflict.requested then parts[#parts + 1] = 'requested=' .. tostring(conflict.requested) end
		if conflict.reason then parts[#parts + 1] = 'reason=' .. tostring(conflict.reason) end
		local context = table.concat(parts, ' ')
		local message = conflict.message or 'menu conflict detected'
		local line = string.format('%s %s', prefix, message)
		if context ~= '' then
			line = string.format('%s (%s)', line, context)
		end
		callLogger(logger.warn, logger.info, line)
	end
end

function Diagnostics.report(source, diagnostics, opts)
	if not diagnostics then return end
	local tag = source or 'diagnostics'
	local prefix = opts and opts.prefix or string.format('[%s]', tag)
	logEntries('error', prefix, diagnostics.errors)
	logEntries('warn', prefix, diagnostics.warnings)
	logConflicts(prefix, diagnostics.conflicts)
end

return Diagnostics

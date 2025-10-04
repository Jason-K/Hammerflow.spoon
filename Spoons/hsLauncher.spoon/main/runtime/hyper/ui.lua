local UI = {}
UI.__index = UI

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

local function buildEntries(assignments)
	local entries = {}
	for _, assignment in ipairs(assignments or {}) do
		entries[#entries + 1] = {
			context = assignment.context or 'global',
			canonical = assignment.trigger and assignment.trigger.canonical or '',
			description = assignment.description or assignment.actionId or assignment.name or 'action',
			tags = deepCopy(assignment.tags or {}),
			actionId = assignment.actionId or assignment.name,
			source = deepCopy(assignment.source or {}),
		}
	end
	table.sort(entries, function (a, b)
		if a.context == b.context then
			return (a.canonical or '') < (b.canonical or '')
		end
		return (a.context or '') < (b.context or '')
	end)
	return entries
end

---@param assignments table[]
---@return table
function UI.build(assignments)
	local view = {
		entries = buildEntries(assignments),
	}
	return setmetatable(view, UI)
end

function UI:toPlainText()
	local lines = {}
	for _, entry in ipairs(self.entries or {}) do
		lines[#lines + 1] = string.format('[%s] %s — %s', entry.context or 'global', entry.canonical or '', entry.description or '')
	end
	return table.concat(lines, '\n')
end

function UI:groupedByContext()
	local grouped = {}
	for _, entry in ipairs(self.entries or {}) do
		local bucket = grouped[entry.context]
		if not bucket then
			bucket = {}
			grouped[entry.context] = bucket
		end
		bucket[#bucket + 1] = entry
	end
	return grouped
end

return UI

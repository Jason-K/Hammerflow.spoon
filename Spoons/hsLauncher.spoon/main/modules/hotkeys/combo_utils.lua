local M = {}

local MOD_ORDER = { cmd = 1, opt = 2, alt = 2, option = 2, ctrl = 3, control = 3, shift = 4 }
local MOD_CANON = {
	cmd = 'cmd',
	alt = 'opt',
	option = 'opt',
	opt = 'opt',
	ctrl = 'ctrl',
	control = 'ctrl',
	shift = 'shift',
}

function M.normalizeMods(mods)
	local collected = {}
	for _, m in ipairs(mods or {}) do
		local canon = MOD_CANON[m] or m
		if canon == 'option' then canon = 'opt' end
		table.insert(collected, canon)
	end
	table.sort(collected, function (a, b)
		return (MOD_ORDER[a] or 99) < (MOD_ORDER[b] or 99)
	end)
	local result, seen = {}, {}
	for _, m in ipairs(collected) do
		if m ~= '' and not seen[m] then
			table.insert(result, m)
			seen[m] = true
		end
	end
	return result
end

function M.normalizeKey(key)
	if not key then return '' end
	local map = { [','] = 'comma', [' '] = 'space' }
	local lowered = string.lower(key)
	return map[lowered] or lowered
end

function M.comboKey(mods, key)
	local prefix = table.concat(M.normalizeMods(mods), '+')
	if prefix ~= '' then
		return prefix .. '+' .. M.normalizeKey(key)
	end
	return M.normalizeKey(key)
end

function M.modsToString(mods)
	return table.concat(M.normalizeMods(mods), '+')
end

return M

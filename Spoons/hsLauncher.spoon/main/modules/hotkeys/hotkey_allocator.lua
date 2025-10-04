-- hsLauncher/main/modules/hotkeys/hotkey_allocator.lua
local M = {}
local Registry = require('hsLauncher.main.modules.hotkeys.hotkey_registry')
local Inspector = require('hsLauncher.main.core.app_menu_inspector')

local function chassisForApp(app, cfg)
	if not app or not cfg then return (cfg and cfg.chassisOrder) or nil end
	--- @diagnostic disable-next-line: undefined-field
	local bid = app:bundleID()
	if cfg.perAppChassis and bid and cfg.perAppChassis[bid] and #cfg.perAppChassis[bid] > 0 then
		return cfg.perAppChassis[bid]
	end
	--- @diagnostic disable-next-line: undefined-field
	local name = app:name()
	if cfg.perAppChassisByName and name and cfg.perAppChassisByName[name] and #cfg.perAppChassisByName[name] > 0 then
		return cfg.perAppChassisByName[name]
	end
	return cfg.chassisOrder
end

local function normalizeList(used)
	local set = {}
	for _, u in ipairs(used or {}) do
		local cmbo = Registry.comboKey(u.mods, u.key)
		set[cmbo] = true
	end
	return set
end

function M.allocate(app, chassisOrder, candidateKeys, cfg)
	--- @diagnostic disable-next-line: undefined-field
	local bundleID = app and app:bundleID() or nil
	local usedSet = normalizeList(Inspector.getUsedCombos(app))

	local order = chassisForApp(app, cfg or { chassisOrder = chassisOrder })
	for _, ch in ipairs(order or {}) do
		local mods = {}
		for m in string.gmatch(ch, "[^+]+") do table.insert(mods, m) end
		for _, key in ipairs(candidateKeys or {}) do
			local cmbo = Registry.comboKey(mods, key)
			local free = Registry.isFree(bundleID, mods, key)
			if free and not usedSet[cmbo] then
				return { mods = mods, key = key }
			end
		end
	end
	return nil
end

return M

-- hsLauncher/main/modules/hotkeys/assign_hotkey.lua
local M = {}
local log = require('hsLauncher.main.core.logger')
local Registry = require('hsLauncher.main.modules.hotkeys.hotkey_registry')
local Alloc = require('hsLauncher.main.modules.hotkeys.hotkey_allocator')
local NSE = require('hsLauncher.main.modules.hotkeys.nsuser_equivalents')
local Combos = require('hsLauncher.main.modules.hotkeys.combo_utils')
local chooser = require('hs.chooser')

local function modsToString(mods)
	return Combos.modsToString(mods)
end

function M.simulate()
	local app = hs.application.frontmostApplication()
	if not app then
		hs.alert.show('No frontmost app'); return
	end
	local cfg = require('hsLauncher.main.core.config')
	Registry.init({ chassisOrder = cfg.chassisOrder, reservedGlobals = cfg.reservedGlobals })
	local alphabet = {}
	for c = string.byte('a'), string.byte('z') do table.insert(alphabet, string.char(c)) end
	for d = string.byte('0'), string.byte('9') do table.insert(alphabet, string.char(d)) end

	local alloc = Alloc.allocate(app, cfg.chassisOrder, alphabet)
	if not alloc then
		hs.alert.show('No free combo found'); return
	end
	--- @diagnostic disable-next-line: undefined-field
	local msg = string.format('Proposed: %s + %s for %s', modsToString(alloc.mods), alloc.key, app:name())
	log.info('Assign simulate: ' .. msg)
	hs.alert.show(msg)
end

-- ACTION: interactive assign for the frontmost app
function M.assign()
	local app = hs.application.frontmostApplication()
	if not app then
		hs.alert.show('No frontmost app'); return
	end
	local cfg = require('hsLauncher.main.core.config')
	Registry.init({ chassisOrder = cfg.chassisOrder, reservedGlobals = cfg.reservedGlobals })
	-- Build candidate menu items list
	--- @diagnostic disable-next-line: undefined-field
	local items = app:getMenuItems() or {}
	local flat = {}
	local function walk(path, list)
		for _, it in ipairs(list or {}) do
			local title = it.AXTitle or it.title
			if title and title ~= '' and (not it.AXChildren and not it.children) then
				table.insert(flat, { text = title, path = path, title = title })
			end
			local np = path
			if title and title ~= '' then np = (path ~= '' and (path .. ' > ' .. title) or title) end
			if it.AXChildren then walk(np, it.AXChildren) end
			if it.children then walk(np, it.children) end
		end
	end
	walk('', items)
	table.sort(flat, function (a, b) return a.text < b.text end)

	local c = chooser.new(function (choice)
		if not choice then return end
		local alphabet = {}
		for c = string.byte('a'), string.byte('z') do table.insert(alphabet, string.char(c)) end
		for d = string.byte('0'), string.byte('9') do table.insert(alphabet, string.char(d)) end
		local alloc = Alloc.allocate(app, cfg.chassisOrder, alphabet)
		if not alloc then
			hs.alert.show('No free combo found'); return
		end
		--- @diagnostic disable-next-line: undefined-field
		local ok, err = NSE.apply(app:bundleID(), choice.title, alloc.mods, alloc.key)
		if ok then
			--- @diagnostic disable-next-line: undefined-field
			Registry.registerApp(app:bundleID(), alloc.mods, alloc.key, choice.title)
			hs.alert.show(string.format('Assigned %s to %s', Registry.comboKey(alloc.mods, alloc.key), choice.title))
		else
			hs.alert.show('Assign failed: ' .. tostring(err))
		end
	end)
	c:choices(flat)
	c:searchSubText(true)
	c:show()
end

return M

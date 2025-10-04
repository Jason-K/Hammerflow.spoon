-- hsLauncher/main/modules/hotkeys/assign_global.lua
-- Assign a conflict-free global hotkey to the frontmost app with countdown and metadata prompts.

local M = {}
local Registry = require('hsLauncher.main.modules.hotkeys.hotkey_registry')
local Alloc = require('hsLauncher.main.modules.hotkeys.hotkey_allocator')
local chooser = require('hs.chooser')
local okDialog, dialog = pcall(require, 'hs.dialog')

-- Reliable modifier emission
local function pressCombo(mods, key)
	local order = { ctrl = 1, alt = 2, shift = 3, cmd = 4 }
	local norm = {}
	for _, m in ipairs(mods or {}) do
		local k = m
		if k == 'opt' or k == 'option' then k = 'alt' end
		table.insert(norm, k)
	end
	table.sort(norm, function (a, b) return (order[a] or 9) < (order[b] or 9) end)
	local ev = require('hs.eventtap').event
	local function modDown(m) ev.newKeyEvent(m, true):post() end
	local function modUp(m) ev.newKeyEvent(m, false):post() end
	for _, m in ipairs(norm) do
		modDown(m); hs.timer.usleep(15000)
	end
	ev.newKeyEvent(norm, key, true):post(); hs.timer.usleep(20000)
	ev.newKeyEvent(norm, key, false):post(); hs.timer.usleep(15000)
	for i = #norm, 1, -1 do
		modUp(norm[i]); hs.timer.usleep(12000)
	end
end

local function parseCombo(combo)
	local parts = {}
	for p in string.gmatch(combo or '', "[^+]+") do table.insert(parts, p) end
	local key = parts[#parts]
	if key == 'comma' then key = ',' elseif key == 'space' then key = ' ' end
	local mods = {}
	for i = 1, (#parts - 1) do
		local m = parts[i]
		if m == 'alt' then m = 'opt' end
		table.insert(mods, m)
	end
	return mods, key
end

local function trim(value)
	if value == nil then return '' end
	return (value:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function normalizeScriptType(value)
	local lowered = string.lower(trim(value or ''))
	if lowered == 'applescript' or lowered == 'apple' or lowered == 'osascript' then return 'applescript' end
	if lowered == 'hs' or lowered == 'hammerspoon' then return 'hs' end
	return 'shell'
end

local function parseArgs(text)
	local args = {}
	for token in string.gmatch(text or '', '([^,]+)') do
		local cleaned = trim(token)
		if cleaned ~= '' then table.insert(args, cleaned) end
	end
	if #args == 0 then return nil end
	return args
end

local function formatScriptSummary(info)
	local script = info and info.script
	if type(script) ~= 'table' or not script.command then return nil end
	local label = script.type or 'shell'
	return string.format('%s → %s', label, script.command)
end

local function promptDefaultAndDescription(bundle, combo, record)
	if not okDialog or not dialog or not dialog.blockAlert then return end
	local existingDesc = record and record.description or ''
	local choice = dialog.blockAlert('Set as default?', combo, 'Yes', 'No', nil, 'informational')
	if choice == 'Yes' then
		Registry.setGlobalDefault(bundle, combo)
	end
	local btn, desc = dialog.textPrompt('Description', 'Enter description (optional):', existingDesc, 'OK', 'Skip')
	if btn == 'OK' then
		local cleaned = trim(desc)
		if cleaned ~= '' then
			Registry.setGlobalDescription(bundle, combo, cleaned)
		end
	end
end

local function promptScriptMetadata(mods, key, record)
	if not okDialog or not dialog or not dialog.blockAlert then return end
	local existing = record and record.script or nil
	local defaultBtn = existing and 'Update' or 'Add'
	local altBtn = existing and 'Keep' or 'Skip'
	local otherBtn = existing and 'Remove' or nil
	local message
	if existing then
		message = 'Update or remove stored external script metadata for this combo?'
	else
		message = 'Attach metadata for an external script triggered by this combo?'
	end
	local response = dialog.blockAlert('External Script Metadata', message, defaultBtn, altBtn, otherBtn, 'informational')
	if response == defaultBtn then
		local btnType, scriptType = dialog.textPrompt('Script Type', 'Enter script type (shell, applescript, hs):',
			existing and existing.type or 'shell', 'OK', 'Cancel')
		if btnType ~= 'OK' then return end
		scriptType = normalizeScriptType(scriptType)
		local promptLabel
		if scriptType == 'applescript' then
			promptLabel = 'AppleScript path'
		elseif scriptType == 'hs' then
			promptLabel = 'Hammerspoon function (module.fn or fn)'
		else
			promptLabel = 'Shell command'
		end
		local btnCmd, command = dialog.textPrompt('Script Target', 'Enter ' .. promptLabel .. ':',
			existing and existing.command or '', 'OK', 'Cancel')
		if btnCmd ~= 'OK' then return end
		command = trim(command)
		if command == '' then return end
		local defaultArgs = ''
		if existing and type(existing.args) == 'table' then
			defaultArgs = table.concat(existing.args, ', ')
		end
		local btnArgs, rawArgs = dialog.textPrompt('Script Parameters (optional)',
			'Comma-separated parameters. Leave blank for none.', defaultArgs, 'OK', 'Skip')
		local args
		if btnArgs == 'OK' then
			args = parseArgs(rawArgs)
		elseif btnArgs == 'Skip' and existing then
			args = existing.args
		end
		local scriptInfo = { type = scriptType, command = command, args = args }
		Registry.setGlobalScript(mods, key, scriptInfo)
	elseif otherBtn and response == otherBtn then
		Registry.setGlobalScript(mods, key, nil)
	end
end

local function handleMetadata(bundle, mods, key, combo)
	if not okDialog or not dialog then return end
	local record = Registry.getGlobal(mods, key)
	promptDefaultAndDescription(bundle, combo, record)
	local refreshed = Registry.getGlobal(mods, key) or record
	promptScriptMetadata(mods, key, refreshed)
end

local function allocateAndAssign(app, cfg, clearFirst)
	--- @diagnostic disable-next-line: undefined-field
	local bundle = app:bundleID() or app:name()
	--- @diagnostic disable-next-line: undefined-field
	local name = app:name()
	if clearFirst then Registry.clearGlobalsForBundle(bundle) end
	local alphabet = {}
	for c = string.byte('a'), string.byte('z') do table.insert(alphabet, string.char(c)) end
	for d = string.byte('0'), string.byte('9') do table.insert(alphabet, string.char(d)) end
	local alloc = Alloc.allocate(app, cfg.chassisOrder, alphabet, cfg)
	if not alloc then
		hs.alert.show('No free global combo'); return
	end
	local combo = Registry.comboKey(alloc.mods, alloc.key)
	hs.alert.show(string.format('Assigning global %s to %s. Focus the field, countdown...', combo, name), 2)
	hs.timer.doAfter(1.0, function () hs.alert.show('3') end)
	hs.timer.doAfter(2.0, function () hs.alert.show('2') end)
	hs.timer.doAfter(3.0, function () hs.alert.show('1') end)
	hs.timer.doAfter(3.2, function ()
		pressCombo(alloc.mods, alloc.key)
		Registry.registerGlobal(alloc.mods, alloc.key, { bundle = bundle, at = os.date('!%Y-%m-%dT%H:%M:%SZ') })
		handleMetadata(bundle, alloc.mods, alloc.key, combo)
		hs.alert.show('Assigned ' .. combo)
	end)
end

local function resendExisting(bundle, appName, list)
	local choices = {}
	local byCombo = {}
	for _, e in ipairs(list or {}) do
		local desc = (e.info and e.info.description) or ''
		local script = formatScriptSummary(e.info)
		local summary
		if desc ~= '' and script then
			summary = desc .. ' • ' .. script
		else
			summary = script or desc
		end
		table.insert(choices, { text = e.combo, subText = summary, combo = e.combo })
		byCombo[e.combo] = e.info or {}
	end
	if #choices == 0 then
		hs.alert.show('No existing combos'); return
	end
	local ch = chooser.new(function (choice)
		if not choice then return end
		local mods, key = parseCombo(choice.combo)
		hs.alert.show('Reapplying ' .. choice.combo .. ' in 2s...')
		hs.timer.doAfter(2.0, function ()
			pressCombo(mods, key)
			Registry.registerGlobal(mods, key, { bundle = bundle, at = os.date('!%Y-%m-%dT%H:%M:%SZ') })
			handleMetadata(bundle, mods, key, choice.combo)
		end)
	end)
	ch:choices(choices):show()
end

function M.assignForFrontmost()
	local app = hs.application.frontmostApplication()
	if not app then
		hs.alert.show('No frontmost app'); return
	end
	local cfg = require('hsLauncher.main.core.config')
	Registry.init({ chassisOrder = cfg.chassisOrder, reservedGlobals = cfg.reservedGlobals })

	--- @diagnostic disable-next-line: undefined-field
	local bundle = app:bundleID() or app:name()
	local existing = Registry.findGlobalsByBundle(bundle)
	local modifiers = hs.eventtap.checkKeyboardModifiers() or {}
	--- @diagnostic disable-next-line: undefined-field
	local shiftHeld = modifiers.shift

	if (existing and #existing > 0) and (not shiftHeld) then
		local actions = {
			{ text = 'Resend existing',  subText = 'Reapply an existing combo',  action = 'resend' },
			{ text = 'Overwrite existing', subText = 'Replace all with a new combo', action = 'overwrite' },
			{ text = 'Add additional',   subText = 'Add another combo',          action = 'add' },
		}
		local actChooser = chooser.new(function (choice)
			if not choice then return end
			if choice.action == 'resend' then
				resendExisting(bundle, nil, existing)
			elseif choice.action == 'overwrite' then
				allocateAndAssign(app, cfg, true)
			elseif choice.action == 'add' then
				allocateAndAssign(app, cfg, false)
			end
		end)
		actChooser:choices(actions):show()
		return
	end

	-- Shift held or no existing: allocate new
	allocateAndAssign(app, cfg, false)
end

return M

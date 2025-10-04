---@diagnostic disable: undefined-global

local Actions = require('hsLauncher.main.core.actions')
local ModuleActions = require('hsLauncher.main.core.module_actions')
local eventtap = require('hs.eventtap')
local fs = require('hsLauncher.main.core.fs')

local M = {
	id = 'shortcuts',
	section = 'Shortcuts',
}

local function expand(script)
	if script == nil then return script end
	return fs.expandUser(script)
end

local function applescript(path)
	local resolved = expand(path)
	if not resolved then return path end
	return resolved
end

local function noActiveModifiers()
	local mods = eventtap.checkKeyboardModifiers()
	if not mods then return true end
	return not (mods.cmd or mods.alt or mods.ctrl or mods.shift)
end

local shortcutDefs = {
	{
		id = 'virtual_office',
		key = '8',
		order = 10,
		description = '8x8 Virtual Office',
		action = ModuleActions.open('8x8 Virtual Office', { bundle_id = 'com.electron.8x8---virtual-office' }),
	},
	{
		id = 'raycast_ai_chat',
		key = 'a',
		order = 20,
		description = 'Raycast AI Chat',
		action = ModuleActions.open('Raycast AI Chat', { url = 'raycast://extensions/raycast/raycast-ai/ai-chat' }),
	},
	{
		id = 'cleanshot_capture_text',
		key = 'c',
		order = 30,
		description = 'CleanShot Capture Text',
		action = ModuleActions.url('CleanShot Capture Text', 'cleanshot://capture-text?linebreaks=false'),
	},
	{
		id = 'toggle_finder',
		key = 'f',
		order = 40,
		description = 'Toggle Finder',
		action = ModuleActions.fromSpec('Toggle Finder', Actions.keystroke('f17', 'hyper')),
	},
	{
		id = 'indent_line',
		key = 'i',
		order = 50,
		description = 'Indent Line',
		action = ModuleActions.fromSpec('Indent Line', Actions.sequence({
			Actions.keystroke('left', { 'cmd' }),
			Actions.hsFunction('sleep', { 0.05 }),
			Actions.keystroke('[', { 'cmd' }),
			Actions.hsFunction('sleep', { 0.05 }),
			Actions.keystroke('right', { 'cmd' }),
		})),
	},
	{
		id = 'qspace_pro',
		key = 'q',
		order = 60,
		description = 'QSpace Pro',
		action = ModuleActions.open('QSpace Pro', { bundle_id = 'com.qspace.qspacepro' }),
	},
	{
		id = 'reveal_latest_download',
		key = 'r',
		order = 70,
		description = 'Reveal Latest Download',
		action = ModuleActions.fromSpec('Reveal Latest Download', { kind = 'handler', name = 'revealLatestDownload' }, { exitAfter = true }),
	},
	{
		id = 'open_raycast_ai',
		key = 's',
		order = 80,
		description = 'Open Raycast AI',
		action = ModuleActions.fromSpec('Open Raycast AI', Actions.keystroke('s', 'hyper')),
	},
	{
		id = 'iterm_here',
		key = 't',
		order = 90,
		description = 'iTerm Here',
		action = ModuleActions.fromSpec('iTerm Here', Actions.applescript(applescript('~/Scripts/Application_Specific/iterm2/iterm2_openHere.applescript'))),
	},
	{
		id = 'toggle_maccy',
		key = 'v',
		order = 100,
		description = 'Toggle Maccy',
		action = ModuleActions.fromSpec('Toggle Maccy', Actions.keystroke('`', { 'ctrl' })),
	},
	{
		id = 'cleanshot_pin',
		key = 'p',
		order = 110,
		description = 'CleanShot Pin',
		action = ModuleActions.url('CleanShot Pin', 'cleanshot://capture-area?action=pin'),
	}
}

local shortcutsMode = {
	consume = true,
	layout = {
		width = 420,
		defaultSection = 'Shortcuts',
		exitSection = 'Exit',
		sectionOrder = { 'Shortcuts', 'Exit' },
	},
	entries = {},
	onExit = { kind = 'handler', name = 'log', args = { level = 'info', message = 'Shortcuts modal exited' } },
}

for _, shortcut in ipairs(shortcutDefs) do
	if shortcut.action.exitAfter == nil then shortcut.action.exitAfter = true end
	shortcut.exitAfter = shortcut.action.exitAfter
	shortcutsMode.entries[#shortcutsMode.entries + 1] = {
		key = shortcut.key,
		description = shortcut.description,
		order = shortcut.order,
		exitAfter = shortcut.exitAfter ~= false,
		action = { kind = 'userAction', id = 'shortcuts.' .. shortcut.id },
	}
end

local function rootShortcutEntries()
	local entries = {}
	entries[#entries + 1] = {
		ref = 'shortcuts.enter_mode',
		key = 's',
		label = 'Shortcuts Mode',
		description = 'Enter shortcuts modal',
		order = 5,
		exitAfter = false,
		section = 'Shortcuts',
		metadata = { module = 'shortcuts', rootShortcut = true, enterMode = true },
	}
	for _, shortcut in ipairs(shortcutDefs) do
		entries[#entries + 1] = {
			ref = 'shortcuts.' .. shortcut.id,
			key = shortcut.rootKey or shortcut.key,
			label = shortcut.label or shortcut.description,
			description = shortcut.description,
			order = shortcut.order,
			exitAfter = shortcut.exitAfter ~= false,
			section = 'Shortcuts',
			metadata = { module = 'shortcuts', rootShortcut = true },
		}
	end
	return entries
end

M.actions = {
	enter_mode = {
		label = 'Shortcuts Mode',
		description = 'Enter shortcuts modal',
		actionSpec = Actions.enterMode('shortcuts'),
		defaultKey = 's',
		exitAfter = false,
	},
}

for _, shortcut in ipairs(shortcutDefs) do
	M.actions[shortcut.id] = shortcut.action
end

M.leader = {
	section = 'Shortcuts',
	rootEntries = rootShortcutEntries,
}

function M.hotkeys()
	return {
		modes = {
			shortcuts = shortcutsMode,
		},
		sequences = {
			{
				keys = { 's' },
				description = 'Enter shortcuts mode',
				when = noActiveModifiers,
				action = { kind = 'handler', name = 'enterMode', args = { mode = 'shortcuts' } },
				metadata = { module = 'shortcuts' },
			},
		},
	}
end

return M

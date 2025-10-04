--- @diagnostic disable: undefined-global

local Actions = require('hsLauncher.main.core.actions')

local M = {
	id = 'hotkey_management',
	section = 'Hotkey Management',
}

local hotkeysMode = {
	consume = true,
	onEnter = { kind = 'handler', name = 'log', args = { level = 'info', message = 'Entered hotkeys mode' } },
	onExit = { kind = 'handler', name = 'log', args = { level = 'info', message = 'Exited hotkeys mode' } },
	layout = {
		width = 380,
		defaultSection = 'Management',
		exitSection = 'Exit',
		sectionOrder = { 'Management', 'Exit' },
	},
	entries = {
		{ key = 'h', description = 'Assign hotkey to action',                 section = 'Management', order = 10, action = { kind = 'actions', method = 'assignHotkey' } },
		{ key = 'g', description = 'Assign global hotkey to frontmost app',   section = 'Management', order = 20, action = { kind = 'actions', method = 'assignGlobal' } },
		{ key = 'r', description = 'Remove global hotkey from frontmost app', section = 'Management', order = 30, action = { kind = 'actions', method = 'removeGlobal' } },
		{ key = 'l', description = 'List assigned hotkeys for frontmost app', section = 'Management', order = 40, action = { kind = 'actions', method = 'listGlobals' } },
	},
}

M.actions = {
	enter_mode = {
		label = 'Hotkey Mode',
		description = 'Enter hotkey management modal',
		actionSpec = Actions.enterMode('hotkeys'),
		defaultKey = 'h',
		exitAfter = false,
	},
	assign_action_hotkey = {
		label = 'Assign Hotkey',
		description = 'Assign hotkey to selected action',
		action = { kind = 'handler', name = 'assignHotkey' },
	},
	assign_global_hotkey = {
		label = 'Assign Global Hotkey',
		description = 'Assign global hotkey to frontmost app',
		action = { kind = 'handler', name = 'assignGlobal' },
	},
	remove_global_hotkey = {
		label = 'Remove Global Hotkey',
		description = 'Remove global hotkey from frontmost app',
		action = { kind = 'handler', name = 'removeGlobal' },
	},
	list_global_hotkeys = {
		label = 'List Global Hotkeys',
		description = 'Show current global hotkeys for frontmost app',
		action = { kind = 'handler', name = 'listGlobals' },
	},
}

local function rootHotkeyEntries()
	return {
		{
			ref = 'hotkey_management.enter_mode',
			key = 'h',
			label = 'Hotkey Mode',
			description = 'Enter hotkey management modal',
			order = 10,
			exitAfter = false,
			section = 'Hotkey Management',
			metadata = { module = 'hotkey_management', rootShortcut = true, enterMode = true },
		},
		{
			ref = 'hotkey_management.assign_action_hotkey',
			key = 'a',
			label = 'Assign action hotkey',
			description = 'Assign hotkey to selected action',
			order = 20,
			section = 'Hotkey Management',
			metadata = { module = 'hotkey_management', rootShortcut = true },
		},
		{
			ref = 'hotkey_management.assign_global_hotkey',
			key = 'g',
			label = 'Assign global hotkey',
			description = 'Assign global hotkey to frontmost app',
			order = 30,
			section = 'Hotkey Management',
			metadata = { module = 'hotkey_management', rootShortcut = true },
		},
		{
			ref = 'hotkey_management.remove_global_hotkey',
			key = 'r',
			label = 'Remove global hotkey',
			description = 'Remove global hotkey from frontmost app',
			order = 40,
			section = 'Hotkey Management',
			metadata = { module = 'hotkey_management', rootShortcut = true },
		},
		{
			ref = 'hotkey_management.list_global_hotkeys',
			key = 'l',
			label = 'List global hotkeys',
			description = 'Show current global hotkeys for frontmost app',
			order = 50,
			section = 'Hotkey Management',
			metadata = { module = 'hotkey_management', rootShortcut = true },
		},
	}
end

M.leader = {
	section = 'Hotkey Management',
	rootEntries = rootHotkeyEntries,
}

function M.hotkeys()
	return {
		modes = {
			hotkeys = hotkeysMode,
		},
		sequences = {
			{
				keys = { 'h', 'a' },
				description = 'Assign hotkey to selected action',
				action = { kind = 'handler', name = 'assignHotkey' },
				metadata = { module = 'hotkey_management' },
			},
			{
				keys = { 'h', 'g' },
				description = 'Assign global hotkey to frontmost app',
				action = { kind = 'handler', name = 'assignGlobal' },
				metadata = { module = 'hotkey_management' },
			},
		},
	}
end

return M

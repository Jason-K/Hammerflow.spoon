--- @diagnostic disable: undefined-global

local Actions = require('hsLauncher.main.core.actions')

local M = {
	id = 'window_management',
	section = 'Window Management',
}

local windowMode = {
	consume = true,
	onEnter = { kind = 'handler', name = 'showDisplayNumbers' },
	onExit = { kind = 'handler', name = 'hideDisplayNumbers' },
	layout = {
		width = 440,
		defaultSection = 'Layout',
		exitSection = 'Exit',
		chordSection = 'Chords',
		sectionOrder = { 'Layout', 'Move', 'Utilities', 'Focus', 'Chords', 'Exit' },
	},
	entries = {
		{ key = 'a',      description = 'Left half',            section = 'Layout',                 order = 10,        action = { kind = 'window', method = 'left' } },
		{ key = 'd',      description = 'Right half',           section = 'Layout',                 order = 20,        action = { kind = 'window', method = 'right' } },
		{ key = 'w',      description = 'Top half',             section = 'Layout',                 order = 30,        action = { kind = 'window', method = 'top' } },
		{ key = 's',      description = 'Bottom half',          section = 'Layout',                 order = 40,        action = { kind = 'window', method = 'bottom' } },
		{ key = 'q',      description = 'Move to screen left',  section = 'Move',                   order = 50,        action = { kind = 'handler', name = 'moveScreen', args = { direction = 'west' } } },
		{ key = 'e',      description = 'Move to screen right', section = 'Move',                   order = 60,        action = { kind = 'handler', name = 'moveScreen', args = { direction = 'east' } } },
		{ key = 'g',      description = 'Show window hints',    section = 'Utilities',              order = 70,        note = 'Hold to reveal window hints',                                             action = { kind = 'window', method = 'hints' } },
		{ key = 'm',      description = 'Maximize window',      section = 'Utilities',              order = 80,        action = { kind = 'window', method = 'maximize' } },
		{ key = 'c',      description = 'Center window',        section = 'Utilities',              order = 90,        action = { kind = 'window', method = 'center' } },
		{ key = 'u',      description = 'Undo last move',       section = 'Utilities',              order = 100,       action = { kind = 'window', method = 'undo' } },
		{ key = 'ctrl-h', label = 'Ctrl+H',                     description = 'Focus window left',  section = 'Focus', order = 110,                                                                      action = { kind = 'window', method = 'focusLeft' } },
		{ key = 'ctrl-j', label = 'Ctrl+J',                     description = 'Focus window down',  section = 'Focus', order = 120,                                                                      action = { kind = 'window', method = 'focusDown' } },
		{ key = 'ctrl-k', label = 'Ctrl+K',                     description = 'Focus window up',    section = 'Focus', order = 130,                                                                      action = { kind = 'window', method = 'focusUp' } },
		{ key = 'ctrl-l', label = 'Ctrl+L',                     description = 'Focus window right', section = 'Focus', order = 140,                                                                      action = { kind = 'window', method = 'focusRight' } },
	},
	chords = {
		{ keys = { 'w', 'd' }, action = { kind = 'window', method = 'tr' } },
		{ keys = { 'w', 'a' }, action = { kind = 'window', method = 'tl' } },
		{ keys = { 's', 'd' }, action = { kind = 'window', method = 'br' } },
		{ keys = { 's', 'a' }, action = { kind = 'window', method = 'bl' } },
	},
	chordEntries = {
		{ combo = 'W + D', description = 'Top-right corner',    order = 210, section = 'Chords' },
		{ combo = 'W + A', description = 'Top-left corner',     order = 220, section = 'Chords' },
		{ combo = 'S + D', description = 'Bottom-right corner', order = 230, section = 'Chords' },
		{ combo = 'S + A', description = 'Bottom-left corner',  order = 240, section = 'Chords' },
	},
}

M.actions = {
	enter_mode = {
		label = 'Window Mode',
		description = 'Enter window management modal',
		actionSpec = Actions.enterMode('window'),
		defaultKey = 'w',
		exitAfter = false,
	},
}

local function rootWindowEntries()
	return {
		{
			ref = 'window_management.enter_mode',
			key = 'w',
			label = 'Window Mode',
			description = 'Resize, move, and focus windows',
			order = 10,
			exitAfter = false,
			section = 'Modules',
			metadata = { module = 'window_management', rootShortcut = true },
		},
	}
end

M.leader = {
	section = 'Window Management',
	rootEntries = rootWindowEntries,
}

function M.hotkeys()
	return {
		modes = {
			window = windowMode,
		},
		sequences = {
			{
				keys = { 'w' },
				description = 'Enter window mode',
				action = { kind = 'handler', name = 'enterMode', args = { mode = 'window' } },
				metadata = { module = 'window_management' },
			},
		},
	}
end

return M

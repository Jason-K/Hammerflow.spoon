---@diagnostic disable: undefined-global

local Actions = require('hsLauncher.main.core.actions')
local logger = require('hsLauncher.main.core.logger')
local userRegistry = require('hsLauncher.main.user.registry')

local function buildQuickSearchSpec()
	userRegistry.load()
	local actionSpec = userRegistry.resolveAction('quicksearch.open_or_search_selection')
	if not actionSpec then
		logger.warn('hotkeys_global: quick search user action not found; disabling Hyper+S sequence')
		return Actions.noop(), 'Quick search action missing'
	end
	local steps = {
		Actions.keystroke('c', { 'cmd' }),
		Actions.hsFunction('sleep', { 0.3 }),
		actionSpec,
	}
	return Actions.sequence(steps), nil
end

local quickSearchAction, quickSearchNote = buildQuickSearchSpec()

return {
	id = 'global',
	hyperBindings = {
		{ key = 'q', description = 'Send window to display west', action = { kind = 'window', method = 'moveWest' } },
		{ key = 'e', description = 'Send window to display east', action = { kind = 'window', method = 'moveEast' } },
		{ key = 'a', description = 'Focus window to the left',    action = { kind = 'window', method = 'focusLeft' } },
		{ key = 'd', description = 'Focus window to the right',   action = { kind = 'window', method = 'focusRight' } },
	},

	modes = {},

	sequences = {},

	globalShortcuts = {
		thresholds = { tap_ms = 230, hold_ms = 300, double_ms = 320 },
		taps = {
			{ key = 'capslock', alone = true, handler = 'hyperDefault', description = 'Caps tap → default leader fallback' },
			{ key = 'padclear', alone = true, action = Actions.open({ app_name = 'PiPad' }), description = 'Launch PiPad dashboard' },
			{ key = 'home', alone = true, action = Actions.keystroke('left', { 'cmd' }), description = 'Jump to start of line' },
			{ key = 'home', mods = { 'shift' }, alone = true, action = Actions.keystroke('left', { 'cmd', 'shift' }), description = 'Select to start of line' },
			{ key = 'end', alone = true, action = Actions.keystroke('right', { 'cmd' }), description = 'Jump to end of line' },
			{ key = 'end', mods = { 'shift' }, alone = true, action = Actions.keystroke('right', { 'cmd', 'shift' }), description = 'Select to end of line' },
		},
		chords = {
			{
				mods = { 'alt' },
				key = 'm',
				description = 'Alt+M emits Hyper F20 keystroke',
				action = Actions.keystroke('f20', 'hyper'),
			},
			{
				mods = 'hyper',
				key = 's',
				description = 'Hyper+S opens clipboard quick search',
				action = quickSearchAction,
				note = quickSearchNote,
			},
			{
				mods = 'hyper',
				key = '=',
				description = 'Hyper+= formats selected text via hs CLI',
				action = Actions.shell([["/opt/homebrew/bin/hs" -c 'formatSelected()']]),
			},
			{
				mods = { 'alt', 'ctrl' },
				key = 'escape',
				description = 'Alt+Ctrl+Esc opens Activity Monitor',
				action = Actions.open({ path = '/System/Applications/Utilities/Activity Monitor.app' }),
			},
		},
		sequences = {
			{
				keys = {
					{ mods = { 'cmd' }, key = 'q' },
					{ mods = { 'cmd' }, key = 'q' },
				},
				timeout = 600,
				action = Actions.hsFunction('quitActiveApp'),
				description = 'Double Cmd+Q to quit frontmost app',
			},
			{
				keys = {
					{ mods = { 'cmd' }, key = 'm' },
					{ mods = { 'cmd' }, key = 'm' },
				},
				timeout = 600,
				action = Actions.keystroke('f20', { 'cmd', 'alt', 'ctrl' }),
				description = 'Double Cmd+M to emit 1Piece hotkey to uniminimize window',
			},
		},
		doubleTaps = {
			{
				key = 'escape',
				mods = { 'alt', 'ctrl' },
				alone = true,
				action = Actions.keystroke('escape', { 'cmd', 'alt' }),
				description = 'Double tap Alt+Ctrl+Esc to open Quit menu via Cmd+Alt+Esc',
			},
		},
		disabled = {
			{ mods = { 'cmd' },        key = 'h', description = 'Block Cmd+H (hide)' },
			{ mods = { 'cmd', 'alt' }, key = 'h', description = 'Block Cmd+Alt+H (hide others)' },
			{ mods = { 'cmd', 'alt' }, key = 'm', description = 'Block Cmd+Alt+M (minimize all)' },
			{ mods = { 'cmd' },        key = 'q', description = 'Block Cmd+Q (single press)' },
		},
	},
}

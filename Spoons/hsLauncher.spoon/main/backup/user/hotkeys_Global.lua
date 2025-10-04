---@diagnostic disable: undefined-global

local Actions = require('hsLauncher.main.core.actions')
local logger = require('hsLauncher.main.core.logger')
local userRegistry = require('hsLauncher.main.user.registry')

local function buildQuickSearchSpec()
	userRegistry.load()
	local actionSpec = userRegistry.resolveAction('quicksearch.open_or_search_selection')
	if not actionSpec then
		logger.warn('hotkeys_Global: quick search user action not found; disabling Hyper+S sequence')
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

local windowModule = require('hsLauncher.main.user.modules.module_WindowManagement')
local hotkeyModule = require('hsLauncher.main.user.modules.module_HotkeyManagement')
local shortcutsModule = require('hsLauncher.main.user.modules.module_shortcuts')

local moduleProviders = { windowModule, hotkeyModule, shortcutsModule }

local config = {
	id = 'Global',
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

	apps = {
		{
			id = 'apps.template',
			layout = {
				width = 380,
				defaultSection = 'Template',
				exitSection = 'Exit',
				sectionOrder = { 'Template', 'Utilities', 'Exit' },
			},
			when = { kind = 'predicate', name = 'frontmostBundle', args = { 'com.apple.Safari' } },
			entries = {
				{
					key = 't',
					description = 'Template Action',
					exitAfter = true,
					order = 10,
					action = { kind = 'userAction', id = 'utilities.screenshot_ocr' },
				},
				{
					key = 'o',
					description = 'Open downloads folder',
					section = 'Utilities',
					order = 20,
					note = 'Wrap actions with predicates to conditionally fire',
					action = { kind = 'handler', name = 'openDownloadsFolder' },
					when = { kind = 'predicate', name = 'frontmostNotName', args = { 'Finder' } },
				},
			},
			triggers = {
				{ kind = 'sequence', keys = { 'a', 't' }, description = 'Sequence to enter Safari template mode' },
				{ kind = 'bind',     key = 't',           description = 'Direct bind to enter Safari template mode' },
			},
		},
	},
}

local function mergeHotkeySpec(target, provider)
	if not provider then return end
	local specFn = provider.hotkeys
	if type(specFn) ~= 'function' then return end
	local spec = specFn()
	if type(spec) ~= 'table' then return end

	if spec.hyperBindings then
		for _, binding in ipairs(spec.hyperBindings) do
			target.hyperBindings[#target.hyperBindings + 1] = binding
		end
	end

	if spec.modes then
		for name, modeDef in pairs(spec.modes) do
			target.modes[name] = modeDef
		end
	end

	if spec.sequences then
		for _, seq in ipairs(spec.sequences) do
			target.sequences[#target.sequences + 1] = seq
		end
	end

	if spec.apps then
		for _, app in ipairs(spec.apps) do
			target.apps[#target.apps + 1] = app
		end
	end

	if spec.globalShortcuts then
		local gs = target.globalShortcuts
		local addon = spec.globalShortcuts
		if addon.thresholds then gs.thresholds = addon.thresholds end
		if addon.taps then
			for _, tap in ipairs(addon.taps) do gs.taps[#gs.taps + 1] = tap end
		end
		if addon.chords then
			for _, chord in ipairs(addon.chords) do gs.chords[#gs.chords + 1] = chord end
		end
		if addon.sequences then
			for _, sequence in ipairs(addon.sequences) do gs.sequences[#gs.sequences + 1] = sequence end
		end
		if addon.doubleTaps then
			for _, doubleTap in ipairs(addon.doubleTaps) do gs.doubleTaps[#gs.doubleTaps + 1] = doubleTap end
		end
		if addon.disabled then
			for _, disabled in ipairs(addon.disabled) do gs.disabled[#gs.disabled + 1] = disabled end
		end
	end
end

for _, provider in ipairs(moduleProviders) do
	mergeHotkeySpec(config, provider)
end

return config

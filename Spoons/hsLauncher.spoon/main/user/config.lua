-- User-specific configuration for hsLauncher modular actions
-- Customize this file to enable or disable modules or adjust leader settings.

return {
	featureFlags = {
		menuBuilder = false,
		declarativeRuntime = true,
	},
	menus = {
		'applications',
		'filesystem',
		'hotkey_management',
		'quicksearch',
		'shortcuts',
		'text_tools',
		'utilities',
		'window_management',
	},
	leader = {
		prefix = 'leader',
		rootName = 'root',
		rootSequence = { 'space' },
		groupSequences = false,
		rootLayout = {
			defaultSection = 'Shortcuts',
			sectionOrder = { 'Shortcuts', 'Modules' },
			footerText = 'Selection copied · choose shortcut or module',
		},
	},
	hotkeys = {
		contexts = {
			'global',
			'hotkey_management',
			'shortcuts',
			'text_tools',
			'window_management',
		},
	},
}

return {
	{
		name = 'external.global.clipboardFormatter',
		actions = {
			'hs.pasteboard.writeObjects(FormatClip())',
		},
		menuDetails = {
			description = 'Format clipboard via external tool',
			defaultShortcut = 'c',
			inMenu = { 'externalHotkeysGlobal' },
		},
		tags = { 'hotkeys.external', 'hotkeys.external.global' },
	},
	{
		name = 'external.app.finder.openDownloads',
		actions = {
			[[kmtrigger://macro=Finder%20-%20Go%20to%20Downloads]],
		},
		menuDetails = {
			description = 'Finder Downloads Shortcut',
			defaultShortcut = 'd',
			inMenu = { 'externalHotkeysApps' },
			perMenu = {
				externalHotkeysApps = {
					description = 'Finder: Open Downloads',
					defaultShortcut = 'd',
				},
			},
		},
		tags = {
			'hotkeys.external',
			'hotkeys.external.app',
			'hotkeys.external.app.com.apple.finder',
		},
	},
}

return {
	{
		title = 'globalRoot',
		description = 'Launcher Root',
		memberRoot = true,
		policy = {
			includeSubMenus = true,
		},
	},
	{
		title = 'leaderModules',
		description = 'Modules',
		memberRoot = true,
		defaultShortcut = 'm',
		subMenus = { 'leaderWindow', 'leaderHotkeys', 'leaderShortcuts' },
		policy = {
			autoPopulateFromActions = false,
			includeSubMenus = true,
		},
	},
	{
		title = 'leaderWindow',
		description = 'Window Management',
		defaultShortcut = 'w',
		policy = {
			autoPopulateFromActions = false,
		},
	},
	{
		title = 'leaderHotkeys',
		description = 'Hotkey Management',
		defaultShortcut = 'h',
		policy = {
			autoPopulateFromActions = false,
		},
	},
	{
		title = 'leaderShortcuts',
		description = 'Shortcuts',
		defaultShortcut = 's',
		policy = {
			autoPopulateFromActions = false,
		},
	},
	{
		title = 'filesystem',
		description = 'Files & Folders',
		memberRoot = true,
		defaultShortcut = 'f',
		subMenus = { 'filesystemDirectories', 'filesystemFiles', 'filesystemWorkspaces' },
		policy = {
			autoPopulateFromActions = false,
			includeSubMenus = true,
		},
	},
	{
		title = 'filesystemDirectories',
		description = 'Directories',
		defaultShortcut = 'd',
		policy = {
			autoPopulateFromActions = true,
			includeTags = { 'filesystem.directory' },
		},
		sort = {
			by = 'custom',
		},
	},
	{
		title = 'filesystemFiles',
		description = 'Files',
		defaultShortcut = 'F',
		policy = {
			autoPopulateFromActions = true,
			includeTags = { 'filesystem.file' },
		},
		sort = {
			by = 'custom',
		},
	},
	{
		title = 'filesystemWorkspaces',
		description = 'Workspaces',
		defaultShortcut = 'W',
		policy = {
			autoPopulateFromActions = true,
			includeTags = { 'filesystem.workspace' },
		},
		sort = {
			by = 'custom',
		},
	},
	{
		title = 'applications',
		description = 'Applications',
		memberRoot = true,
		defaultShortcut = 'a',
		subMenus = { 'applicationsBrowsers' },
		policy = {
			autoPopulateFromActions = true,
			includeTags = { 'applications' },
			excludeTags = { 'browser' },
			includeSubMenus = true,
		},
		sort = {
			by = 'custom',
		},
	},
	{
		title = 'applicationsBrowsers',
		description = 'Browsers',
		defaultShortcut = 'B',
		policy = {
			autoPopulateFromActions = true,
			includeTags = { 'browser' },
		},
		sort = {
			by = 'custom',
		},
	},
	{
		title = 'externalHotkeys',
		description = 'External Hotkeys',
		memberRoot = true,
		defaultShortcut = 'x',
		subMenus = { 'externalHotkeysGlobal', 'externalHotkeysApps' },
		policy = {
			autoPopulateFromActions = false,
			includeSubMenus = true,
		},
	},
	{
		title = 'externalHotkeysGlobal',
		description = 'Global External Hotkeys',
		defaultShortcut = 'g',
		policy = {
			autoPopulateFromActions = true,
			includeTags = { 'hotkeys.external.global' },
		},
		sort = {
			by = 'alpha',
		},
	},
	{
		title = 'externalHotkeysApps',
		description = 'Application External Hotkeys',
		defaultShortcut = 'p',
		policy = {
			autoPopulateFromActions = true,
			includeTags = { 'hotkeys.external.app' },
		},
		sort = {
			by = 'alpha',
		},
	},
}

--- @diagnostic disable: undefined-global

local ModuleActions = require('hsLauncher.main.core.module_actions')

local M = {
	id = 'filesystem',
	section = 'Files & Folders',
}

M.actions = {

	-- Folders
	folders_applications = ModuleActions.openWithApplication('Applications', 'Qspace Pro', '/Applications'),
	folders_cases = ModuleActions.openWithApplication('Cases', 'Qspace Pro',
													  [[~/Library/CloudStorage/OneDrive-BoxerandGerson,LLP/Documents/Cases]]),
	folders_downloads = ModuleActions.openWithApplication('Downloads', 'Qspace Pro', '~/Downloads'),
	folders_finder = ModuleActions.openWithApplication('Finder', 'Qspace Pro'),
	folders_gits = ModuleActions.openWithApplication('Gits', 'Qspace Pro', '~/Gits'),
	folders_hammerspoon = ModuleActions.openWithApplication('Hammerspoon', 'Qspace Pro', '~/.hammerspoon'),
	folders_home = ModuleActions.openWithApplication('Home', 'Qspace Pro', '~'),
	folders_library = ModuleActions.openWithApplication('Library', 'Qspace Pro',
														[[~/Library/CloudStorage/OneDrive-Personal/1 - Work/---- - workers' compensation resources]]),
	folders_programs = ModuleActions.openWithApplication('Programs', 'Qspace Pro', '~/Documents/programming'),
	folders_scripts = ModuleActions.openWithApplication('Scripts', 'Qspace Pro', '~/Scripts'),
	folders_workspaces = ModuleActions.openWithApplication('Workspaces', 'Qspace Pro', '~/Scripts/Workspaces'),
	folders_devonthink = ModuleActions.openApp('DEVONthink', '/Applications/DEVONthink.app'),
	folders_scripts_workspace = ModuleActions.openPath('Scripts workspace', '~/Scripts/Workspaces/Scripts.code-workspace'),

	-- Files
	files_ama_guides = ModuleActions.openWithBundle('AMA Guides',
													[[~/Library/CloudStorage/OneDrive-Personal/1 - Work/---- - workers' compensation resources/SOURCES - AMAG - AMA - Guides for the Evaluation of Permanent Impairment/2001, AMA Guides, Fifth Edition/AMA Guides to the Evaluation of Permanent Impairment - 5th Ed., 2001.pdf]],
													'net.sourceforge.skim-app.skim'),
	files_claude_mcps = ModuleActions.openWithBundle('Claude MCPs',
													 '~/Library/Application Support/Claude/claude_desktop_config.json',
													 'com.microsoft.vscodeinsiders'),
	files_karabiner_rules = ModuleActions.openWithBundle('Karabiner rules', '~/.config/karabiner/karabiner.json',
														 'com.microsoft.vscodeinsiders'),
	files_leaderkey_shortcuts = ModuleActions.openWithBundle('Leaderkey shortcuts',
															 '~/Library/Application Support/Leader Key/config.json',
															 'com.microsoft.vscodeinsiders'),
	files_pdrs = ModuleActions.openWithBundle('PDRS',
											  [[~/Library/CloudStorage/OneDrive-Personal/1 - Work/---- - workers' compensation resources/SOURCES - PDRS - Permanent Disability Rating Schedules/New Schedule - 2005 Schedule for Rating Permanent Disabilities PDRS - DOI on or after 2005.pdf]],
											  'net.sourceforge.skim-app.skim'),
	files_sort_leaderkey = ModuleActions.python('Sort leaderkey shortcuts',
												'~/Scripts/Application_Specific/Leaderkey/jjk_SortLeaderkey/jjk_sort_leaderkey_config.py'),
	files_zshrc = ModuleActions.openWithBundle('.zshrc', '~/.zshrc', 'com.microsoft.vscodeinsiders'),

	-- Workspaces
	workspaces_karabiner = ModuleActions.openPath('Karabiner', '~/Scripts/Workspaces/karabiner.ts.code-workspace'),
	workspaces_scripts = ModuleActions.openPath('Scripts', '~/Scripts/Workspaces/Scripts.code-workspace'),
	workspaces_ocr = ModuleActions.url('OCR', 'cleanshot://capture-text?linebreaks=false'),
	workspaces_privileges = ModuleActions.shell('Privileges',
												'/Applications/Privileges.app/Contents/MacOS/PrivilegesCLI -a'),
	workspaces_recent_download = ModuleActions.url('Recent download',
												   'kmtrigger://macro=Open%20most%20recently%20downloaded%20file'),
	workspaces_eval_clipboard = ModuleActions.shell('Evaluate clipboard', [[/opt/homebrew/bin/hs -c "FormatClip()"]]),
}

M.leader = {
	section = 'Files & Folders',
	root = {
		key = 'f',
		label = 'Files & Folders',
		description = 'Open folders, files, and workspaces',
		order = 60,
	},
	groups = {
		{
			key = 'd',
			label = 'Directories',
			entries = {
				{ ref = 'filesystem.folders_applications',      key = 'a' },
				{ ref = 'filesystem.folders_cases',             key = 'c' },
				{ ref = 'filesystem.folders_downloads',         key = 'd' },
				{ ref = 'filesystem.folders_finder',            key = 'f' },
				{ ref = 'filesystem.folders_gits',              key = 'g' },
				{ ref = 'filesystem.folders_hammerspoon',       key = 'h' },
				{ ref = 'filesystem.folders_home',              key = 'j' },
				{ ref = 'filesystem.folders_library',           key = 'l' },
				{ ref = 'filesystem.folders_programs',          key = 'p' },
				{ ref = 'filesystem.folders_scripts',           key = 's' },
				{ ref = 'filesystem.folders_workspaces',        key = 'w' },
				{ ref = 'filesystem.folders_devonthink',        key = 'D' },
				{ ref = 'filesystem.folders_scripts_workspace', key = 'S' },
			},
		},
		{
			key = 'F',
			label = 'Files',
			entries = {
				{ ref = 'filesystem.files_ama_guides',          key = 'a' },
				{ ref = 'filesystem.files_claude_mcps',         key = 'c' },
				{ ref = 'filesystem.files_karabiner_rules',     key = 'k' },
				{ ref = 'filesystem.files_leaderkey_shortcuts', key = 'l' },
				{ ref = 'filesystem.files_pdrs',                key = 'p' },
				{ ref = 'filesystem.files_sort_leaderkey',      key = 's' },
				{ ref = 'filesystem.files_zshrc',               key = '.' },
			},
		},
		{
			key = 'W',
			label = 'Workspaces',
			entries = {
				{ ref = 'filesystem.workspaces_karabiner',       key = 'k' },
				{ ref = 'filesystem.workspaces_scripts',         key = 's' },
				{ ref = 'filesystem.workspaces_ocr',             key = 'o' },
				{ ref = 'filesystem.workspaces_privileges',      key = 'p' },
				{ ref = 'filesystem.workspaces_recent_download', key = 'r' },
				{ ref = 'filesystem.workspaces_eval_clipboard',  key = '=' },
			},
		},
	},
}

return M

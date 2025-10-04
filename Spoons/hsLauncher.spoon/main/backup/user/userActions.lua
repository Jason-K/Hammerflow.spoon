---@diagnostic disable: undefined-global

local ModuleActions = require('hsLauncher.main.core.module_actions')
local Actions = require('hsLauncher.main.core.actions')
local fs = require('hsLauncher.main.core.fs')
local hsfs = require('hs.fs')
local pasteboard = require('hs.pasteboard')
local application = require('hs.application')
local urlevent = require('hs.urlevent')
local eventtap = require('hs.eventtap')

local execute = hs.execute

local UserActions = {}
local contexts = {}
local actionsById = {}

local function shallowCopyMap(map)
	if type(map) ~= 'table' then return {} end
	local copy = {}
	for key, value in pairs(map) do copy[key] = value end
	return copy
end

local function deepCopy(value, seen)
	if type(value) ~= 'table' then return value end
	seen = seen or {}
	if seen[value] then return seen[value] end
	local copy = {}
	seen[value] = copy
	for k, v in pairs(value) do
		copy[k] = deepCopy(v, seen)
	end
	return copy
end

local function registerContext(ctx)
	assert(type(ctx) == 'table', 'UserActions: context spec must be a table')
	assert(ctx.id and ctx.id ~= '', 'UserActions: context spec must include id')
	ctx.section = ctx.section or ctx.id
	ctx.actions = ctx.actions or {}
	contexts[ctx.id] = ctx
	for actionId, spec in pairs(ctx.actions) do
		actionsById[string.format('%s.%s', ctx.id, actionId)] = spec
	end
end

local function buildApplicationsContext()
	local ctx = {
		id = 'applications',
		section = 'Applications',
	}

	local function buildAction(def)
		local opts = {
			description = def.description,
			note = def.note,
			badge = def.badge,
			metadata = def.metadata,
			defaultKey = def.defaultKey,
			tags = def.tags,
		}
		if def.exitAfter ~= nil then opts.exitAfter = def.exitAfter end

		if def.actionSpec or def.action then
			return ModuleActions.fromSpec(def.label, def.actionSpec or def.action, opts)
		elseif def.command then
			return ModuleActions.shell(def.label, def.command, opts)
		elseif def.url then
			return ModuleActions.url(def.label, def.url, opts)
		elseif def.handler then
			return ModuleActions.call(def.label, def.handler, opts)
		elseif def.exec then
			return ModuleActions.exec(def.label, def.exec, opts)
		else
			local target = {
				path = def.path,
				bundleId = def.bundleId,
				appName = def.appName or def.launchName or def.label,
			}
			return ModuleActions.openApp(def.label, target, opts)
		end
	end

	local appDefinitions = {
		{
			id = 'brave',
			label = 'Brave Browser',
			path = '/Applications/Brave Browser.app',
			appName = 'Brave Browser',
			leader = {
				main = { key = 'b', order = 20 },
				browsers = { key = 'b', order = 10 },
			},
		},
		{
			id = 'dia',
			label = 'Dia',
			path = '/Applications/Dia.app',
			leader = {
				main = { key = 'd', order = 30 },
				browsers = { key = 'd', order = 20 },
			},
		},
		{
			id = 'edge',
			label = 'Edge',
			path = '/Applications/Microsoft Edge.app',
			appName = 'Microsoft Edge',
			leader = {
				main = { key = 'e', order = 40, label = 'Edge' },
				browsers = { key = 'e', order = 30, label = 'Edge' },
			},
		},
		{
			id = 'orion',
			label = 'Orion',
			path = '/Applications/Orion.app',
			appName = 'Orion',
			leader = {
				main = { key = 'o', order = 50 },
				browsers = { key = 'o', order = 40 },
			},
		},
		{
			id = 'sigma',
			label = 'SigmaOS',
			path = '/Applications/SigmaOS.app',
			appName = 'SigmaOS',
			leader = {
				main = { key = 's', order = 60 },
				browsers = { key = 's', order = 50 },
			},
		},
		{
			id = 'tor',
			label = 'Tor Browser',
			path = '/Applications/Tor Browser.app',
			appName = 'Tor Browser',
			leader = {
				main = { key = 't', order = 70 },
				browsers = { key = 't', order = 60 },
			},
		},
		{
			id = 'zen',
			label = 'Zen',
			path = '/Applications/Zen.app',
			appName = 'Zen',
			leader = {
				main = { key = 'z', order = 80 },
				browsers = { key = 'z', order = 70 },
			},
		},
		{
			id = 'acrobat',
			label = 'Acrobat',
			path = '/Applications/Adobe Acrobat DC/Adobe Acrobat.app',
			appName = 'Adobe Acrobat',
			leader = {
				main = { key = 'a', order = 90, label = 'Acrobat' },
			},
		},
		{
			id = 'code',
			label = 'Code',
			path = '/Applications/Visual Studio Code - Insiders.app',
			appName = 'Visual Studio Code - Insiders',
			leader = {
				main = { key = 'c', order = 100, label = 'Code' },
			},
		},
		{
			id = 'qspace',
			label = 'Finder',
			path = '/Applications/QSpace Pro.app',
			appName = 'QSpace Pro',
			leader = {
				main = { key = 'f', order = 110, label = 'Finder' },
			},
		},
		{
			id = 'github',
			label = 'GitHub Desktop',
			path = '/Applications/GitHub Desktop.app',
			appName = 'GitHub Desktop',
			leader = {
				main = { key = 'g', order = 120, label = 'GitHub Desktop' },
			},
		},
		{
			id = 'iterm',
			label = 'iTerm',
			path = '~/Applications/iTerm.app',
			appName = 'iTerm',
			leader = {
				main = { key = 'i', order = 130 },
			},
		},
		{
			id = 'outlook',
			label = 'Outlook',
			path = '/Applications/Microsoft Outlook.app',
			appName = 'Microsoft Outlook',
			leader = {
				main = { key = 'o', order = 140, label = 'Outlook' },
			},
		},
		{
			id = 'proton',
			label = 'Proton Mail',
			path = '/Applications/Proton Mail.app',
			appName = 'Proton Mail',
			leader = {
				main = { key = 'p', order = 150 },
			},
		},
		{
			id = 'goodtask',
			label = 'Reminders',
			path = '~/Applications/Setapp/GoodTask.app',
			appName = 'GoodTask',
			leader = {
				main = { key = 'r', order = 160, label = 'Reminders' },
			},
		},
		{
			id = 'messages',
			label = 'SMS',
			path = '/System/Applications/Messages.app',
			appName = 'Messages',
			leader = {
				main = { key = 's', order = 170, label = 'SMS' },
			},
		},
		{
			id = 'teams',
			label = 'Teams',
			path = '/Applications/Microsoft Teams.app',
			appName = 'Microsoft Teams',
			leader = {
				main = { key = 't', order = 180, label = 'Teams' },
			},
		},
		{
			id = 'word',
			label = 'Word',
			path = '/Applications/Microsoft Word.app',
			appName = 'Microsoft Word',
			leader = {
				main = { key = 'w', order = 190, label = 'Word' },
			},
		},
		{
			id = 'excel',
			label = 'Excel',
			path = '/Applications/Microsoft Excel.app',
			appName = 'Microsoft Excel',
			leader = {
				main = { key = 'x', order = 200, label = 'Excel' },
			},
		},
		{
			id = 'onepassword',
			label = '1Password',
			path = '/Applications/1Password.app',
			appName = '1Password',
			leader = {
				main = { key = '1', order = 210, label = '1Password' },
			},
		},
		{
			id = 'eightx8',
			label = '8x8',
			path = '/Applications/8x8 Work.app',
			appName = '8x8 Work',
			leader = {
				main = { key = '8', order = 220, label = '8x8' },
			},
		},
	}

	ctx.actions = ModuleActions.buildMap(appDefinitions, buildAction)

	local leaderBuckets = {
		main = {},
		browsers = {},
	}

	local function makeLeaderEntry(def, info, defaultOrder)
		return {
			ref = 'applications.' .. def.id,
			key = info.key,
			label = info.label or def.label,
			order = info.order or defaultOrder,
		}
	end

	for index, def in ipairs(appDefinitions) do
		local defLeader = def.leader
		local leaderMain = defLeader and defLeader.main or nil
		if leaderMain ~= nil then
			local entry = makeLeaderEntry(def, leaderMain, 1000 + index)
			table.insert(leaderBuckets.main, entry)
		end
		local leaderBrowsers = defLeader and defLeader.browsers or nil
		if leaderBrowsers ~= nil then
			local entry = makeLeaderEntry(def, leaderBrowsers, 1000 + index)
			table.insert(leaderBuckets.browsers, entry)
		end
	end

	local function sortByOrder(list)
		table.sort(list, function (a, b)
			local ao = a.order or 0
			local bo = b.order or 0
			if ao == bo then return (a.label or '') < (b.label or '') end
			return ao < bo
		end)
		for _, entry in ipairs(list) do entry.order = nil end
		return list
	end

	local browsersEntries = sortByOrder(leaderBuckets.browsers)
	local mainEntries = sortByOrder(leaderBuckets.main)

	local groupedEntries = {}
	if #browsersEntries > 0 then
		groupedEntries[#groupedEntries + 1] = {
			kind = 'group',
			key = 'B',
			label = 'Browsers',
			entries = browsersEntries,
		}
	end
	for _, entry in ipairs(mainEntries) do
		groupedEntries[#groupedEntries + 1] = entry
	end

	ctx.leader = {
		section = 'Applications',
		root = {
			key = 'a',
			label = 'Applications',
			description = 'Launch frequently used applications',
			order = 40,
		},
		groups = {
			{
				key = 'a',
				label = 'Applications',
				entries = groupedEntries,
			},
		},
	}

	return ctx
end

local function buildFilesystemContext()
	local ctx = {
		id = 'filesystem',
		section = 'Files & Folders',
	}

	local pathCases = [[~/Library/CloudStorage/OneDrive-BoxerandGerson,LLP/Documents/Cases]]
	local pathLibrary = [[~/Library/CloudStorage/OneDrive-Personal/1 - Work/---- - workers' compensation resources]]
	local pathAmaGuides = [[~/Library/CloudStorage/OneDrive-Personal/1 - Work/---- - workers' compensation resources/SOURCES - AMAG - AMA - Guides for the Evaluation of Permanent Impairment/2001, AMA Guides, Fifth Edition/AMA Guides to the Evaluation of Permanent Impairment - 5th Ed., 2001.pdf]]
	local pathPdrs = [[~/Library/CloudStorage/OneDrive-Personal/1 - Work/---- - workers' compensation resources/SOURCES - PDRS - Permanent Disability Rating Schedules/New Schedule - 2005 Schedule for Rating Permanent Disabilities PDRS - DOI on or after 2005.pdf]]
	local pathClaude = '~/Library/Application Support/Claude/claude_desktop_config.json'
	local pathLeaderKey = '~/Library/Application Support/Leader Key/config.json'
	local pathKarabinerRules = '~/.config/karabiner/karabiner.json'
	local pathSortLeaderKey = '~/Scripts/Application_Specific/Leaderkey/jjk_SortLeaderkey/jjk_sort_leaderkey_config.py'

	ctx.actions = {
		folders_applications = ModuleActions.openWithApplication('Applications', 'Qspace Pro', '/Applications'),
		folders_cases = ModuleActions.openWithApplication('Cases', 'Qspace Pro', pathCases),
		folders_downloads = ModuleActions.openWithApplication('Downloads', 'Qspace Pro', '~/Downloads'),
		folders_finder = ModuleActions.openWithApplication('Finder', 'Qspace Pro'),
		folders_gits = ModuleActions.openWithApplication('Gits', 'Qspace Pro', '~/Gits'),
		folders_hammerspoon = ModuleActions.openWithApplication('Hammerspoon', 'Qspace Pro', '~/.hammerspoon'),
		folders_home = ModuleActions.openWithApplication('Home', 'Qspace Pro', '~'),
		folders_library = ModuleActions.openWithApplication('Library', 'Qspace Pro', pathLibrary),
		folders_programs = ModuleActions.openWithApplication('Programs', 'Qspace Pro', '~/Documents/programming'),
		folders_scripts = ModuleActions.openWithApplication('Scripts', 'Qspace Pro', '~/Scripts'),
		folders_workspaces = ModuleActions.openWithApplication('Workspaces', 'Qspace Pro', '~/Scripts/Workspaces'),
		folders_devonthink = ModuleActions.openApp('DEVONthink', '/Applications/DEVONthink.app'),
		folders_scripts_workspace = ModuleActions.openPath('Scripts workspace', '~/Scripts/Workspaces/Scripts.code-workspace'),

		files_ama_guides = ModuleActions.openWithBundle('AMA Guides', pathAmaGuides, 'net.sourceforge.skim-app.skim'),
		files_claude_mcps = ModuleActions.openWithBundle('Claude MCPs', pathClaude, 'com.microsoft.vscodeinsiders'),
		files_karabiner_rules = ModuleActions.openWithBundle('Karabiner rules', pathKarabinerRules, 'com.microsoft.vscodeinsiders'),
		files_leaderkey_shortcuts = ModuleActions.openWithBundle('Leaderkey shortcuts', pathLeaderKey, 'com.microsoft.vscodeinsiders'),
		files_pdrs = ModuleActions.openWithBundle('PDRS', pathPdrs, 'net.sourceforge.skim-app.skim'),
		files_sort_leaderkey = ModuleActions.python('Sort leaderkey shortcuts', pathSortLeaderKey, {
			args = '--source clipboard --dest paste',
		}),
		files_zshrc = ModuleActions.openWithBundle('.zshrc', '~/.zshrc', 'com.microsoft.vscodeinsiders'),

		workspaces_karabiner = ModuleActions.openPath('Karabiner', '~/Scripts/Workspaces/karabiner.ts.code-workspace'),
		workspaces_scripts = ModuleActions.openPath('Scripts', '~/Scripts/Workspaces/Scripts.code-workspace'),
		workspaces_ocr = ModuleActions.url('OCR', 'cleanshot://capture-text?linebreaks=false'),
		workspaces_privileges = ModuleActions.shell('Privileges', '/Applications/Privileges.app/Contents/MacOS/PrivilegesCLI -a'),
		workspaces_recent_download = ModuleActions.url('Recent download', 'kmtrigger://macro=Open%20most%20recently%20downloaded%20file'),
		workspaces_eval_clipboard = ModuleActions.shell('Evaluate clipboard', [[/opt/homebrew/bin/hs -c "FormatClip()"]]),
	}

	ctx.leader = {
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
					{ ref = 'filesystem.folders_applications', key = 'a' },
					{ ref = 'filesystem.folders_cases', key = 'c' },
					{ ref = 'filesystem.folders_downloads', key = 'd' },
					{ ref = 'filesystem.folders_finder', key = 'f' },
					{ ref = 'filesystem.folders_gits', key = 'g' },
					{ ref = 'filesystem.folders_hammerspoon', key = 'h' },
					{ ref = 'filesystem.folders_home', key = 'j' },
					{ ref = 'filesystem.folders_library', key = 'l' },
					{ ref = 'filesystem.folders_programs', key = 'p' },
					{ ref = 'filesystem.folders_scripts', key = 's' },
					{ ref = 'filesystem.folders_workspaces', key = 'w' },
					{ ref = 'filesystem.folders_devonthink', key = 'D' },
					{ ref = 'filesystem.folders_scripts_workspace', key = 'S' },
				},
			},
			{
				key = 'F',
				label = 'Files',
				entries = {
					{ ref = 'filesystem.files_ama_guides', key = 'a' },
					{ ref = 'filesystem.files_claude_mcps', key = 'c' },
					{ ref = 'filesystem.files_karabiner_rules', key = 'k' },
					{ ref = 'filesystem.files_leaderkey_shortcuts', key = 'l' },
					{ ref = 'filesystem.files_pdrs', key = 'p' },
					{ ref = 'filesystem.files_sort_leaderkey', key = 's' },
					{ ref = 'filesystem.files_zshrc', key = '.' },
				},
			},
			{
				key = 'W',
				label = 'Workspaces',
				entries = {
					{ ref = 'filesystem.workspaces_karabiner', key = 'k' },
					{ ref = 'filesystem.workspaces_scripts', key = 's' },
					{ ref = 'filesystem.workspaces_ocr', key = 'o' },
					{ ref = 'filesystem.workspaces_privileges', key = 'p' },
					{ ref = 'filesystem.workspaces_recent_download', key = 'r' },
					{ ref = 'filesystem.workspaces_eval_clipboard', key = '=' },
				},
			},
		},
	}

	return ctx
end

local function buildHotkeyManagementContext()
	local ctx = {
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
			{ key = 'h', description = 'Assign hotkey to action', section = 'Management', order = 10, action = { kind = 'actions', method = 'assignHotkey' } },
			{ key = 'g', description = 'Assign global hotkey to frontmost app', section = 'Management', order = 20, action = { kind = 'actions', method = 'assignGlobal' } },
			{ key = 'r', description = 'Remove global hotkey from frontmost app', section = 'Management', order = 30, action = { kind = 'actions', method = 'removeGlobal' } },
			{ key = 'l', description = 'List assigned hotkeys for frontmost app', section = 'Management', order = 40, action = { kind = 'actions', method = 'listGlobals' } },
		},
	}

	ctx.actions = {
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

	local function rootEntries()
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

	ctx.leader = {
		section = 'Hotkey Management',
		rootEntries = rootEntries,
	}

	ctx.hotkeys = {
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

	return ctx
end

local function buildQuicksearchContext()
	local ctx = {
		id = 'quicksearch',
		section = 'Utilities',
	}

	local HISTORY_FILE = os.getenv('HOME') .. '/Scripts/Metascripts/jjk_QuickSearch/logs/.window_history'
	local FALLBACK_BROWSER = 'Dia'

	local BROWSER_NAMES = {
		'Safari',
		'Google Chrome',
		'Brave Browser',
		'Microsoft Edge',
		'Arc',
		'Orion',
		'Firefox',
		'SigmaOS',
		'Dia',
	}

	local browserSet = {}
	for _, name in ipairs(BROWSER_NAMES) do browserSet[name] = true end

	local nameToBundle = {
		['Safari'] = 'com.apple.Safari',
		['Google Chrome'] = 'com.google.Chrome',
		['Brave Browser'] = 'com.brave.Browser',
		['Microsoft Edge'] = 'com.microsoft.Edge',
		['Arc'] = 'company.thebrowser.Browser',
		['Orion'] = 'com.kagi.kagimacOS',
		['Firefox'] = 'org.mozilla.firefox',
		['SigmaOS'] = 'com.sigmaos.mac',
	}

	local bundleToName = {}
	for name, bundleId in pairs(nameToBundle) do bundleToName[bundleId] = name end

	local function trimWhitespace(str)
		if str == nil then return '' end
		return (str:match('^%s*(.-)%s*$') or '')
	end

	local function urlDecode(str)
		return (str:gsub('%%(%x%x)', function (hex)
			local value = tonumber(hex, 16)
			if not value then return '' end
			return string.char(value)
		end))
	end

	local function urlEncode(str)
		if str == nil then return '' end
		return (str:gsub('([^%w%-%_%.~])', function (c)
			return string.format('%%%02X', string.byte(c))
		end))
	end

	local function fromFileUrl(url)
		local body = url:gsub('^file://', '')
		body = body:gsub('^localhost', '')
		if body ~= '' and body:sub(1, 1) ~= '/' then
			body = '/' .. body
		end
		return urlDecode(body)
	end

	local function resolveFilePath(text)
		local path
		if text:sub(1, 7) == 'file://' then
			path = fromFileUrl(text)
		elseif text:sub(1, 1) == '/' or text:sub(1, 2) == '~/' then
			path = text
		else
			return nil
		end

		local absolute = hsfs.pathToAbsolute(path)
		if not absolute then return nil end
		if hsfs.attributes(absolute) then
			return absolute
		end
		return nil
	end

	local function openFile(path)
		if not path then return end
		execute(string.format([[open -R %q]], path))
		execute(string.format([[open -a %q %q]], 'QSpace Pro', path))
	end

	local function normalizeAppName(appName, bundleId)
		if bundleId and bundleToName[bundleId] then
			return bundleToName[bundleId]
		end
		if appName == 'com.brave.Browser' then
			return 'Brave Browser'
		end
		return appName
	end

	local function readLastBrowser()
		local file = io.open(HISTORY_FILE, 'r')
		if not file then return nil end
		for line in file:lines() do
			local lineText = tostring(line or '')
			local parts = {}
			for part in lineText:gmatch('([^|]+)') do parts[#parts + 1] = part end
			local normalized = trimWhitespace(parts[1])
			local flag = trimWhitespace(parts[3] or '')
			if normalized ~= '' and flag == 'true' then
				file:close()
				return normalized
			end
		end
		file:close()
		return nil
	end

	local function dispatchURL(appName, url, activate)
		if not appName or appName == '' or not url or url == '' then return end
		local app = application.get(appName)
		local bundleId = app and app:bundleID() or nameToBundle[appName]
		local handled = bundleId and urlevent.openURLWithBundle(url, bundleId, not activate)
		if handled then return end
		local parts = { 'open' }
		if activate == false then table.insert(parts, '-g') end
		table.insert(parts, '-a')
		table.insert(parts, string.format('%q', appName))
		table.insert(parts, string.format('%q', url))
		execute(table.concat(parts, ' '))
	end

	local function browserIsRunning(appName)
		return application.get(appName) ~= nil
	end

	local function openHttp(url)
		local frontApp = application.frontmostApplication()
		local normalized
		if frontApp then
			normalized = normalizeAppName(frontApp:name(), frontApp:bundleID())
		end
		if normalized and browserSet[normalized] then
			dispatchURL(normalized, url, true)
			return
		end

		local lastBrowser = readLastBrowser()
		if lastBrowser and browserSet[lastBrowser] and browserIsRunning(lastBrowser) then
			dispatchURL(lastBrowser, url, false)
			return
		end

		dispatchURL(FALLBACK_BROWSER, url, true)
	end

	local function handleClipboard()
		local raw = pasteboard.getContents()
		local text = trimWhitespace(raw)
		if text == '' then return end

		local filePath = resolveFilePath(text)
		if filePath then
			openFile(filePath)
			return
		end

		if text:find('://', 1, true) then
			if text:match('^https?://') then
				openHttp(text)
			else
				execute(string.format([[open %q]], text))
			end
			return
		end

		local searchUrl = 'https://kagi.com/search?q=' .. urlEncode(text)
		openHttp(searchUrl)
	end

	ctx.actions = {
		open_or_search_selection = ModuleActions.call('Open/Search Clipboard', handleClipboard, {
			description = 'Open clipboard path/URL or search query in preferred browser',
			exitAfter = true,
		}),
	}

	ctx.leader = {
		section = 'Utilities',
		root = {
			key = 'q',
			label = 'Quick Search',
			description = 'Search the web or open clipboard targets',
			order = 80,
		},
		groups = {
			{
				key = 'q',
				label = 'Quick Search',
				entries = {
					{ ref = 'quicksearch.open_or_search_selection', key = 'o', label = '(O)pen/Search Clipboard' },
				},
			},
		},
	}

	return ctx
end

local function buildShortcutsContext()
	local ctx = {
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
		},
	}

	ctx.actions = {
		enter_mode = {
			label = 'Shortcuts Mode',
			description = 'Enter shortcuts modal',
			actionSpec = Actions.enterMode('shortcuts'),
			defaultKey = 's',
			exitAfter = false,
		},
	}

	for _, shortcut in ipairs(shortcutDefs) do
		ctx.actions[shortcut.id] = shortcut.action
	end

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

	local function rootEntries()
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

	ctx.leader = {
		section = 'Shortcuts',
		rootEntries = rootEntries,
	}

	ctx.hotkeys = {
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

	return ctx
end

local function buildTextToolsContext()
	local ctx = {
		id = 'text_tools',
		section = 'Text Tools',
	}

	local textAction = ModuleActions.textProcessorFactory('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py')

	local actionSpecs = {
		td_to_aww = textAction('AWW from TTD', 'td_to_aww'),
		aww_to_td = textAction('TTD from AWW', 'aww_to_td'),

		lowercase = textAction('lower', 'lowercase'),
		sentence_case = textAction('Sentence', 'sentence_case'),
		title_case = textAction('Title', 'title_case'),
		uppercase = textAction('UPPER', 'uppercase'),

		date_alpha = textAction('Alpha - MMMM D, YYYY', 'date_alpha'),
		date_diff = textAction('Date diff', 'date_diff'),
		date_file = textAction('File - YYYY.MM.DD', 'date_file'),
		date_iso = textAction('ISO - YYYY-MM-DD', 'date_iso'),
		date_long = textAction('Long - MM/DD/YYYY', 'date_long'),
		date_medium = textAction('Medium - M/D/YYYY', 'date_medium'),
		date_pad = textAction('Padded medium - MM/DD/YYYY', 'date_pad'),
		date_relative = textAction('Relative date', 'format_relative_date'),

		markdown_heading_1 = textAction('Heading 1', 'markdown_heading', '--level 1'),
		markdown_heading_2 = textAction('Heading 2', 'markdown_heading', '--level 2'),
		markdown_heading_3 = textAction('Heading 3', 'markdown_heading', '--level 3'),
		markdown_ordered = textAction('Ordered list', 'markdown_ordered_list'),
		markdown_unordered = textAction('Unordered list', 'markdown_unordered_list'),
		markdown_bold = textAction('Bold', 'markdown_bold'),
		markdown_italic = textAction('Italics', 'markdown_italic'),
		markdown_link = textAction('Link', 'markdown_link'),
		markdown_remove = textAction('Remove markdown', 'remove_markdown'),
		markdown_strike = textAction('Strikethrough', 'markdown_strikethrough'),
		markdown_underline = textAction('Underline', 'markdown_underline'),
		markdown_rule = textAction('Horizontal rule', 'markdown_horizontal_rule'),

		wrap_brackets = textAction('Wrap []', 'wrap_brackets'),
		wrap_curly = textAction('Wrap {}', 'wrap_curly_braces'),
		wrap_quotes = textAction('Wrap ""', 'wrap_quotes'),
		wrap_single_quotes = textAction("Wrap ''", 'wrap_single_quotes'),
		wrap_parentheses = textAction('Wrap ()', 'wrap_parentheses'),
	}

	local categories = {
		{
			id = 'benefit_rates',
			label = 'Benefit Rates',
			description = 'Benefit rate converters',
			key = 'b',
			order = 60,
			mode = 'text_tools.benefit_rates',
			entries = {
				{ action = 'td_to_aww', key = 'a', label = 'AWW from TTD', order = 10 },
				{ action = 'aww_to_td', key = 't', label = 'TTD from AWW', order = 20 },
			},
		},
		{
			id = 'case_changers',
			label = 'Case Changers',
			description = 'Change letter casing',
			key = 'c',
			order = 70,
			mode = 'text_tools.case_changers',
			entries = {
				{ action = 'lowercase', key = 'l', order = 10, label = 'lowercase' },
				{ action = 'sentence_case', key = 's', order = 20, label = 'Sentence case' },
				{ action = 'title_case', key = 't', order = 30, label = 'Title case' },
				{ action = 'uppercase', key = 'u', order = 40, label = 'UPPERCASE' },
			},
		},
		{
			id = 'date_scripts',
			label = 'Date Scripts',
			description = 'Generate date strings',
			key = 'd',
			order = 80,
			mode = 'text_tools.date_scripts',
			entries = {
				{ action = 'date_alpha', key = 'a', order = 10, label = 'Alpha - MMMM D, YYYY' },
				{ action = 'date_diff', key = 'd', order = 20, label = 'Date diff' },
				{ action = 'date_file', key = 'f', order = 30, label = 'File - YYYY.MM.DD' },
				{ action = 'date_iso', key = 'i', order = 40, label = 'ISO - YYYY-MM-DD' },
				{ action = 'date_long', key = 'l', order = 50, label = 'Long - MM/DD/YYYY' },
				{ action = 'date_medium', key = 'm', order = 60, label = 'Medium - M/D/YYYY' },
				{ action = 'date_pad', key = 'p', order = 70, label = 'Padded medium - MM/DD/YYYY' },
				{ action = 'date_relative', key = 'r', order = 80, label = 'Relative date' },
			},
		},
		{
			id = 'markdown',
			label = 'Markdown',
			description = 'Markdown helpers',
			key = 'm',
			order = 90,
			mode = 'text_tools.markdown',
			entries = {
				{ action = 'markdown_heading_1', key = '1', order = 10, section = 'Headings', label = 'Heading 1' },
				{ action = 'markdown_heading_2', key = '2', order = 20, section = 'Headings', label = 'Heading 2' },
				{ action = 'markdown_heading_3', key = '3', order = 30, section = 'Headings', label = 'Heading 3' },
				{ action = 'markdown_ordered', key = 'o', order = 40, section = 'Lists', label = 'Ordered list' },
				{ action = 'markdown_unordered', key = 'u', order = 50, section = 'Lists', label = 'Unordered list' },
				{ action = 'markdown_bold', key = 'b', order = 60, section = 'Formatting', label = 'Bold' },
				{ action = 'markdown_italic', key = 'i', order = 70, section = 'Formatting', label = 'Italics' },
				{ action = 'markdown_link', key = 'l', order = 80, section = 'Formatting', label = 'Link' },
				{ action = 'markdown_remove', key = 'r', order = 90, section = 'Formatting', label = 'Remove markdown' },
				{ action = 'markdown_strike', key = 's', order = 100, section = 'Formatting', label = 'Strikethrough' },
				{ action = 'markdown_underline', key = 'u', order = 110, section = 'Formatting', label = 'Underline' },
				{ action = 'markdown_rule', key = 'h', order = 120, section = 'Formatting', label = 'Horizontal rule' },
			},
		},
		{
			id = 'wrappers',
			label = 'Wrappers',
			description = 'Wrap text with punctuation',
			key = 'w',
			order = 100,
			mode = 'text_tools.wrappers',
			entries = {
				{ action = 'wrap_brackets', key = 'b', order = 10, label = 'Wrap with []' },
				{ action = 'wrap_brackets', key = '[', order = 11, label = 'Wrap with []' },
				{ action = 'wrap_curly', key = 'c', order = 20, label = 'Wrap with {}' },
				{ action = 'wrap_curly', key = '{', order = 21, label = 'Wrap with {}' },
				{ action = 'wrap_quotes', key = 'q', order = 30, label = 'Wrap with ""' },
				{ action = 'wrap_single_quotes', key = "'", order = 40, label = "Wrap with ''" },
				{ action = 'wrap_parentheses', key = '9', order = 50, label = 'Wrap with ()' },
			},
		},
	}

	local function buildCategoryMode(category)
		local layout = {
			width = 420,
			defaultSection = category.defaultSection or category.label,
			exitSection = 'Exit',
			sectionOrder = category.sectionOrder or { category.label, 'Exit' },
		}
		local mode = {
			consume = true,
			layout = layout,
			entries = {},
		}
		for _, entry in ipairs(category.entries) do
			local spec = actionSpecs[entry.action]
			if spec then
				mode.entries[#mode.entries + 1] = {
					key = entry.key,
					description = entry.description or spec.description or spec.label,
					label = entry.label or spec.label,
					section = entry.section or category.label,
					order = entry.order,
					exitAfter = spec.exitAfter ~= false,
					action = { kind = 'userAction', id = 'text_tools.' .. entry.action },
				}
			end
		end
		return mode
	end

	local categoryModes = {}
	for _, category in ipairs(categories) do
		categoryModes[category.mode] = buildCategoryMode(category)
	end

	local textToolsMode = {
		consume = true,
		layout = {
			width = 360,
			defaultSection = 'Categories',
			exitSection = 'Exit',
			sectionOrder = { 'Categories', 'Exit' },
		},
		entries = {},
	}

	for _, category in ipairs(categories) do
		textToolsMode.entries[#textToolsMode.entries + 1] = {
			key = category.key,
			description = category.description or ('Enter ' .. category.label),
			label = category.label,
			section = 'Categories',
			order = category.order,
			exitAfter = false,
			action = { kind = 'userAction', id = 'text_tools.enter_' .. category.id },
		}
	end

	local function rootEntries()
		local entries = {
			{
				ref = 'text_tools.enter_mode',
				key = 't',
				label = 'Text Tools',
				description = 'Format and transform text snippets',
				order = 50,
				exitAfter = false,
				section = 'Text Tools',
				metadata = { module = 'text_tools', enterMode = true },
			},
		}
		for _, category in ipairs(categories) do
			entries[#entries + 1] = {
				ref = 'text_tools.enter_' .. category.id,
				key = category.key,
				label = category.label,
				description = category.description or ('Enter ' .. category.label),
				order = category.order,
				exitAfter = false,
				section = 'Text Tools',
				metadata = { module = 'text_tools', category = category.id },
			}
		end
		return entries
	end

	ctx.actions = {
		enter_mode = {
			label = 'Text Tools',
			description = 'Enter text tools modal',
			actionSpec = Actions.enterMode('text_tools'),
			defaultKey = 't',
			exitAfter = false,
		},
	}

	for _, category in ipairs(categories) do
		ctx.actions['enter_' .. category.id] = {
			label = category.label,
			description = category.description or ('Enter ' .. category.label),
			actionSpec = Actions.enterMode(category.mode),
			exitAfter = false,
		}
	end

	for id, spec in pairs(actionSpecs) do
		ctx.actions[id] = spec
	end

	ctx.leader = {
		section = 'Text Tools',
		rootEntries = rootEntries,
	}

	local modes = {
		text_tools = textToolsMode,
	}
	for modeName, mode in pairs(categoryModes) do
		modes[modeName] = mode
	end

	local sequences = {
		{
			keys = { 't' },
			description = 'Enter text tools modal',
			action = { kind = 'handler', name = 'enterMode', args = { mode = 'text_tools' } },
			metadata = { module = 'text_tools' },
		},
	}
	for _, category in ipairs(categories) do
		sequences[#sequences + 1] = {
			keys = { 't', category.key },
			description = 'Enter ' .. category.label .. ' text tools',
			action = { kind = 'handler', name = 'enterMode', args = { mode = category.mode } },
			metadata = { module = 'text_tools', category = category.id },
		}
	end

	ctx.hotkeys = {
		modes = modes,
		sequences = sequences,
	}

	return ctx
end

local function buildUtilitiesContext()
	local ctx = {
		id = 'utilities',
		section = 'Utilities',
	}

	ctx.actions = {
		screenshot_annotate = ModuleActions.url('Annotate', 'cleanshot://capture-area?action=annotate'),
		screenshot_ocr = ModuleActions.url('O(C)R', 'cleanshot://capture-text?linebreaks=false'),
		screenshot_pin = ModuleActions.url('Pin', 'cleanshot://capture-area?action=pin'),
		screenshot_save = ModuleActions.url('Save', 'cleanshot://capture-area?action=save'),
		screenshot_copy = ModuleActions.url('Copy to clipboard', 'cleanshot://capture-area'),
		rectangle_reflow_pin = ModuleActions.shell(
			'Reflow (P)inned app',
			'open -g "rectangle-pro://execute-action?name=reflow-pin"'
		),
		rectangle_toggle_pin = ModuleActions.shell(
			'Toggle (P)in mode',
			'open -g "rectangle-pro://execute-action?name=pin"'
		),
		scripts_merus_scan = ModuleActions.python(
			'Name scan in Merus',
			'~/Scripts/Application_Specific/Meruscase/jjk_Rename_MerusScans.py',
			{ args = '--source clipboard --dest paste' }
		),
		scripts_raycast = ModuleActions.url(
			'Raycast text extension',
			'raycast://extensions/koinzhang/text-shortcuts/shortcut-library'
		),
	}

	ctx.leader = {
		section = 'Utilities',
		root = {
			key = 'u',
			label = 'Utilities',
			description = 'Capture screenshots and toggle helpers',
			order = 70,
		},
		groups = {
			{
				key = 'S',
				label = 'Screenshots',
				entries = {
					{ ref = 'utilities.screenshot_annotate', key = 'a' },
					{ ref = 'utilities.screenshot_ocr', key = 'c', label = 'O(C)R' },
					{ ref = 'utilities.screenshot_pin', key = 'p' },
					{ ref = 'utilities.screenshot_save', key = 's' },
					{ ref = 'utilities.screenshot_copy', key = 'C' },
				},
			},
			{
				key = 'R',
				label = 'Rectangle',
				entries = {
					{ ref = 'utilities.rectangle_reflow_pin', key = 'r', label = 'r' },
					{ ref = 'utilities.rectangle_toggle_pin', key = 't', label = 't' },
				},
			},
			{
				key = 'M',
				label = 'Misc. Scripts',
				entries = {
					{ ref = 'utilities.scripts_merus_scan', key = 'n' },
					{ ref = 'utilities.scripts_raycast', key = 'r' },
				},
			},
		},
	}

	return ctx
end

local function buildWindowManagementContext()
	local ctx = {
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
			{ key = 'a', description = 'Left half', section = 'Layout', order = 10, action = { kind = 'window', method = 'left' } },
			{ key = 'd', description = 'Right half', section = 'Layout', order = 20, action = { kind = 'window', method = 'right' } },
			{ key = 'w', description = 'Top half', section = 'Layout', order = 30, action = { kind = 'window', method = 'top' } },
			{ key = 's', description = 'Bottom half', section = 'Layout', order = 40, action = { kind = 'window', method = 'bottom' } },
			{ key = 'q', description = 'Move to screen left', section = 'Move', order = 50, action = { kind = 'handler', name = 'moveScreen', args = { direction = 'west' } } },
			{ key = 'e', description = 'Move to screen right', section = 'Move', order = 60, action = { kind = 'handler', name = 'moveScreen', args = { direction = 'east' } } },
			{ key = 'g', description = 'Show window hints', section = 'Utilities', order = 70, note = 'Hold to reveal window hints', action = { kind = 'window', method = 'hints' } },
			{ key = 'm', description = 'Maximize window', section = 'Utilities', order = 80, action = { kind = 'window', method = 'maximize' } },
			{ key = 'c', description = 'Center window', section = 'Utilities', order = 90, action = { kind = 'window', method = 'center' } },
			{ key = 'u', description = 'Undo last move', section = 'Utilities', order = 100, action = { kind = 'window', method = 'undo' } },
			{ key = 'ctrl-h', label = 'Ctrl+H', description = 'Focus window left', section = 'Focus', order = 110, action = { kind = 'window', method = 'focusLeft' } },
			{ key = 'ctrl-j', label = 'Ctrl+J', description = 'Focus window down', section = 'Focus', order = 120, action = { kind = 'window', method = 'focusDown' } },
			{ key = 'ctrl-k', label = 'Ctrl+K', description = 'Focus window up', section = 'Focus', order = 130, action = { kind = 'window', method = 'focusUp' } },
			{ key = 'ctrl-l', label = 'Ctrl+L', description = 'Focus window right', section = 'Focus', order = 140, action = { kind = 'window', method = 'focusRight' } },
		},
		chords = {
			{ keys = { 'w', 'd' }, action = { kind = 'window', method = 'tr' } },
			{ keys = { 'w', 'a' }, action = { kind = 'window', method = 'tl' } },
			{ keys = { 's', 'd' }, action = { kind = 'window', method = 'br' } },
			{ keys = { 's', 'a' }, action = { kind = 'window', method = 'bl' } },
		},
		chordEntries = {
			{ combo = 'W + D', description = 'Top-right corner', order = 210, section = 'Chords' },
			{ combo = 'W + A', description = 'Top-left corner', order = 220, section = 'Chords' },
			{ combo = 'S + D', description = 'Bottom-right corner', order = 230, section = 'Chords' },
			{ combo = 'S + A', description = 'Bottom-left corner', order = 240, section = 'Chords' },
		},
	}

	ctx.actions = {
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
				metadata = { module = 'window_management', rootShortcut = true, enterMode = true },
			},
		}
	end

	ctx.leader = {
		section = 'Window Management',
		rootEntries = rootWindowEntries,
	}

	ctx.hotkeys = {
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

	return ctx
end

registerContext(buildApplicationsContext())
registerContext(buildFilesystemContext())
registerContext(buildHotkeyManagementContext())
registerContext(buildQuicksearchContext())
registerContext(buildShortcutsContext())
registerContext(buildTextToolsContext())
registerContext(buildUtilitiesContext())
registerContext(buildWindowManagementContext())

function UserActions.menu(name)
	local ctx = contexts[name]
	assert(ctx, string.format('UserActions: unknown menu context %s', tostring(name)))
	return {
		id = ctx.id,
		section = ctx.section,
		actions = shallowCopyMap(ctx.actions),
		leader = ctx.leader and deepCopy(ctx.leader) or nil,
		alias = ctx.alias,
		contrib = ctx.contrib and deepCopy(ctx.contrib) or nil,
	}
end

function UserActions.hotkeys(name)
	local ctx = contexts[name]
	if not ctx or not ctx.hotkeys then return nil end
	return deepCopy(ctx.hotkeys)
end

function UserActions.resolve(id)
	return actionsById[id]
end

function UserActions.actions()
	return actionsById
end

function UserActions.contextNames()
	local names = {}
	for id, _ in pairs(contexts) do names[#names + 1] = id end
	table.sort(names)
	return names
end

return UserActions

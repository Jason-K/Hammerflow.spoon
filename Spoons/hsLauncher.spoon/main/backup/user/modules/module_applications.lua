--- @diagnostic disable: undefined-global

local ModuleActions = require('hsLauncher.main.core.module_actions')
local M = {
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
		section = def.section,
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

M.actions = ModuleActions.buildMap(appDefinitions, buildAction)

local leaderBuckets = {
	main = {},
	browsers = {},
}

local function makeLeaderEntry(def, info, defaultOrder)
	local entry = {
		ref = 'applications.' .. def.id,
		key = info.key,
		label = info.label or def.label,
		order = info.order or defaultOrder,
	}
	return entry
end

for index, def in ipairs(appDefinitions) do
	if def.leader then
		if def.leader.main then
			local entry = makeLeaderEntry(def, def.leader.main, 1000 + index)
			table.insert(leaderBuckets.main, entry)
		end
		if def.leader.browsers then
			local entry = makeLeaderEntry(def, def.leader.browsers, 1000 + index)
			table.insert(leaderBuckets.browsers, entry)
		end
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

M.leader = {
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


return M

--- @diagnostic disable: undefined-global

local ModuleActions = require('hsLauncher.main.core.module_actions')
local fs = require('hs.fs')
local pasteboard = require('hs.pasteboard')
local application = require('hs.application')
local urlevent = require('hs.urlevent')

local execute = hs.execute

local M = {
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
	-- Dia does not advertise a stable bundle identifier across builds, fall back to name-based open.
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

	local absolute = fs.pathToAbsolute(path)
	if not absolute then return nil end
	if fs.attributes(absolute) then
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

M.actions = {
	open_or_search_selection = ModuleActions.call('Open/Search Clipboard', handleClipboard, {
		description = 'Open clipboard path/URL or search query in preferred browser',
		exitAfter = true,
	}),
}

M.leader = {
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

return M

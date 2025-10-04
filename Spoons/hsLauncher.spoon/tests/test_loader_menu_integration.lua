local scriptPath = debug.getinfo(1, 'S').source:sub(2)
if scriptPath:sub(1, 1) ~= '/' then
	local cwd = assert(io.popen('pwd'):read('*l'), 'Unable to determine working directory')
	scriptPath = cwd .. '/' .. scriptPath
end
local testDir = scriptPath:match('(.*/)')
assert(testDir, 'Unable to determine test directory from ' .. tostring(scriptPath))
local projectRoot = testDir:gsub('/tests/?$', '/')
local parentRoot = projectRoot:gsub('/[^/]+/?$', '/')

local pathParts = {
	projectRoot .. '?.lua',
	projectRoot .. '?/init.lua',
	projectRoot .. 'main/?.lua',
	projectRoot .. 'main/?/init.lua',
	parentRoot .. '?.lua',
	parentRoot .. '?/init.lua',
	parentRoot .. 'main/?.lua',
	parentRoot .. 'main/?/init.lua',
	package.path,
}
package.path = table.concat(pathParts, ';')

local LOADER_GUARD = '__hslauncher_loader_integration'

local function registerHsLauncherLoader(root)
	if package[LOADER_GUARD] then return end
	table.insert(package.searchers, 2, function (moduleName)
		local relative = moduleName:match('^hsLauncher%.(.+)$')
		if not relative then return nil end
		local base = root .. relative:gsub('%.', '/')
		local attempts = {}
		local function try(path)
			local chunk, err = loadfile(path)
			if chunk then return chunk end
			attempts[#attempts + 1] = err or ('no file ' .. path)
			return nil
		end
		local chunk = try(base .. '.lua') or try(base .. '/init.lua')
		if chunk then return chunk end
		return nil, table.concat(attempts, '\n')
	end)
	package[LOADER_GUARD] = true
end

registerHsLauncherLoader(projectRoot)

local ConfigLoader = require('hsLauncher.main.core.config_loader')
local MenuBuilder = require('hsLauncher.main.core.menu_builder')

local ACTIONS_MODULE = 'hsLauncher.main.user.actions'
local EXTERNAL_MODULE = 'hsLauncher.main.user.external_hotkeys'
local MENUS_MODULE = 'hsLauncher.main.user.menus'

local function resetModules()
	package.loaded[ACTIONS_MODULE] = nil
	package.loaded[EXTERNAL_MODULE] = nil
	package.loaded[MENUS_MODULE] = nil
	package.preload[ACTIONS_MODULE] = nil
	package.preload[EXTERNAL_MODULE] = nil
	package.preload[MENUS_MODULE] = nil
end

local function assertTrue(condition, message)
	if not condition then error(message or 'Assertion failed') end
end

local function expect(value, message)
	assertTrue(value ~= nil, message)
	return value
end

local function findItem(items, id)
	for _, item in ipairs(items or {}) do
		if item.id == id then return item end
	end
	return nil
end

local function hasMenuItem(items, id)
	for _, item in ipairs(items or {}) do
		if item.type == 'menu' and item.id == id then return true end
	end
	return false
end

local actions = {
	{
		name = 'primary.launcher.overview',
		actions = { 'showLauncherOverview()' },
		menuDetails = {
			description = 'Launcher Overview',
			inMenu = { 'globalRoot' },
			defaultShortcut = 'l',
		},
		tags = { 'launcher' },
	},
}

local externalActions = {
	{
		name = 'external.global.clipboardFormatter',
		actions = { 'formatClipboardExternally()' },
		menuDetails = {
			description = 'Format Clipboard',
			inMenu = { 'externalHotkeysGlobal' },
			defaultShortcut = 'c',
		},
		tags = { 'hotkeys.external', 'hotkeys.external.global' },
	},
	{
		name = 'external.app.finder.openDownloads',
		actions = { 'finderOpenDownloads()' },
		menuDetails = {
			description = 'Finder Downloads',
			inMenu = { 'externalHotkeysApps' },
			defaultShortcut = 'd',
		},
		tags = {
			'hotkeys.external',
			'hotkeys.external.app',
			'hotkeys.external.app.com.apple.finder',
		},
	},
}

local menus = {
	{
		title = 'globalRoot',
		description = 'Launcher Root',
		memberRoot = true,
		policy = { includeSubMenus = true },
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
		policy = {
			autoPopulateFromActions = true,
			includeTags = { 'hotkeys.external.global' },
		},
	},
	{
		title = 'externalHotkeysApps',
		description = 'Application External Hotkeys',
		policy = {
			autoPopulateFromActions = true,
			includeTags = { 'hotkeys.external.app' },
		},
	},
}

resetModules()
package.preload[ACTIONS_MODULE] = function () return actions end
package.preload[EXTERNAL_MODULE] = function () return externalActions end
package.preload[MENUS_MODULE] = function () return menus end

local loadResult = ConfigLoader.load()
resetModules()

assertTrue(loadResult.ok, 'Loader should succeed for integration config')
assertTrue(#loadResult.actions == 3, 'Merged actions should include primary and external entries')

local menuResult = MenuBuilder.build({ actions = loadResult.actions, menus = loadResult.menus })
assertTrue(menuResult.ok, 'Menu builder should succeed with loader output')

local rootMenu = menuResult.root
assertTrue(rootMenu ~= nil, 'Root menu should be present')
assertTrue(hasMenuItem(rootMenu.items, 'externalHotkeys'), 'Root should surface external hotkeys menu')

local globalMenu = expect(menuResult.menus.externalHotkeysGlobal, 'Global external menu should exist')
assertTrue(findItem(globalMenu.items, 'external.global.clipboardFormatter') ~= nil, 'Global external action should be present')

local appsMenu = expect(menuResult.menus.externalHotkeysApps, 'App external menu should exist')
assertTrue(findItem(appsMenu.items, 'external.app.finder.openDownloads') ~= nil, 'App external action should be present')

print('[PASS] loader to menu integration covers external hotkeys pipeline')

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

local LOADER_GUARD = '__hslauncher_loader_menu_builder'

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

package.preload['hsLauncher.main.core.menu_builder'] = function ()
	local chunk, err = loadfile(projectRoot .. 'main/core/menu_builder.lua')
	assert(chunk, err)
	return chunk()
end

local MenuBuilder = require('hsLauncher.main.core.menu_builder')

local function assertTrue(condition, message)
	if not condition then error(message or 'Assertion failed') end
end

local function assertEquals(actual, expected, message)
	if actual ~= expected then
		error(string.format('%s\nexpected: %s\nactual: %s', message or 'Assertion failed', tostring(expected), tostring(actual)))
	end
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
		name = 'globalAction',
		actions = { 'doGlobal()' },
		menuDetails = {
			description = 'Global Action',
			inMenu = { 'globalRoot' },
			defaultShortcut = 'g',
		},
		tags = { 'global' },
	},
	{
		name = 'openScripts',
		actions = { 'openScripts()' },
		menuDetails = {
			description = 'Open Scripts folder',
			inMenu = { 'files', 'globalRoot' },
			defaultShortcut = 's',
			perMenu = {
				files = {
					description = 'Open Scripts Dir',
					defaultShortcut = 's',
				},
				globalRoot = {
					description = 'Open Scripts (Root)',
					defaultShortcut = 'S',
				},
			},
		},
		tags = { 'filesystem', 'favorite' },
	},
	{
		name = 'downloads',
		actions = { 'openDownloads()' },
		menuDetails = {
			description = 'Open Downloads',
			inMenu = { 'files' },
			defaultShortcut = 'd',
		},
		tags = { 'filesystem' },
	},
	{
		name = 'utilityTag',
		actions = { 'utilityTag()' },
		menuDetails = {
			description = 'Tag Utility',
			defaultShortcut = 'u',
		},
		tags = { 'utility', 'filesystem' },
	},
	{
		name = 'utilityChildAction',
		actions = { 'runUtilityChild()' },
		menuDetails = {
			description = 'Utility Child Action',
			inMenu = { 'utilityChild' },
			defaultShortcut = 'c',
		},
		tags = { 'utility' },
	},
	{
		name = 'appBrowser',
		actions = { 'launchBrowser()' },
		menuDetails = {
			description = 'Launch Browser',
			inMenu = { 'apps' },
			defaultShortcut = 'b',
		},
		tags = { 'app' },
	},
	{
		name = 'appBackup',
		actions = { 'launchBackup()' },
		menuDetails = {
			description = 'Backup App',
			inMenu = { 'apps' },
			defaultShortcut = 'b',
			fallbackShortcut = 'k',
		},
		tags = { 'app' },
	},
	{
		name = 'appBuilder',
		actions = { 'launchBuilder()' },
		menuDetails = {
			description = 'Builder App',
			inMenu = { 'apps' },
			defaultShortcut = 'b',
			fallbackShortcut = 'k',
		},
		tags = { 'app' },
	},
}

local menus = {
	{
		title = 'globalRoot',
		description = 'Root Menu',
		memberRoot = true,
		policy = { includeSubMenus = true },
		excludeMenu = { 'hiddenMenu' },
	},
	{
		title = 'files',
		description = 'Files',
		memberRoot = true,
		defaultShortcut = 'f',
		policy = {
			includeTags = { 'filesystem' },
			excludeTags = { 'utility' },
		},
		sort = { by = 'alpha' },
	},
	{
		title = 'apps',
		description = 'Applications',
		memberRoot = true,
		defaultShortcut = 'a',
		sort = { by = 'shortcut' },
	},
	{
		title = 'tools',
		description = 'Tools',
		memberRoot = true,
		defaultShortcut = 't',
		subMenus = { 'utilities' },
		policy = {
			autoPopulateFromActions = false,
			includeSubMenus = true,
		},
	},
	{
		title = 'utilities',
		description = 'Utilities',
		subMenus = { 'utilityChild' },
		policy = {
			includeTags = { 'utility' },
		},
	},
	{
		title = 'utilityChild',
		description = 'Utility Child',
		policy = {
			autoPopulateFromActions = false,
		},
	},
	{
		title = 'isolated',
		description = 'Isolated',
		memberRoot = true,
		defaultShortcut = 'i',
		subMenus = { 'utilityChild' },
		policy = {
			includeSubMenus = false,
			includeTags = { 'utility' },
		},
	},
	{
		title = 'hiddenMenu',
		description = 'Hidden',
		memberRoot = true,
		defaultShortcut = 'h',
	},
}

local result = MenuBuilder.build({ actions = actions, menus = menus })

assertTrue(result.ok, 'menu builder should succeed')

local root = result.root
assertTrue(root ~= nil, 'root menu should be present')
assertEquals(root.id, 'globalRoot', 'root id should be globalRoot')

local rootGlobal = expect(findItem(root.items, 'globalAction'), 'root should include global action')
assertEquals(rootGlobal.shortcut, 'g', 'global action shortcut should use default')
assertEquals(rootGlobal.shortcutSource, 'default', 'global action shortcut source should be default')

local rootScripts = expect(findItem(root.items, 'openScripts'), 'root should include scripts action')
assertEquals(rootScripts.label, 'Open Scripts (Root)', 'per-menu description should override root label')
assertEquals(rootScripts.shortcut, 'S', 'root override shortcut should apply')

assertTrue(hasMenuItem(root.items, 'files'), 'root should expose files menu')
assertTrue(hasMenuItem(root.items, 'apps'), 'root should expose apps menu')
assertTrue(hasMenuItem(root.items, 'tools'), 'root should expose tools menu')
assertTrue(hasMenuItem(root.items, 'isolated'), 'root should expose isolated menu')
assertTrue(not hasMenuItem(root.items, 'hiddenMenu'), 'root should exclude hidden menu')

local toolsMenu = expect(result.menus.tools, 'tools menu should exist')
assertTrue(hasMenuItem(toolsMenu.items, 'utilities'), 'tools should include utilities submenu')
assertTrue(findItem(toolsMenu.items, 'utilityTag') == nil, 'tools should not auto-populate actions when disabled')

local filesMenu = expect(result.menus.files, 'files menu should exist')
local downloadsItem = expect(findItem(filesMenu.items, 'downloads'), 'files menu should include downloads action')
assertEquals(downloadsItem.label, 'Open Downloads', 'downloads label should match description')
local scriptsItem = expect(findItem(filesMenu.items, 'openScripts'), 'files menu should include scripts action')
assertEquals(scriptsItem.label, 'Open Scripts Dir', 'per-menu override should update label')
assertEquals(scriptsItem.shortcut, 's', 'files menu should use default shortcut')
assertEquals(filesMenu.items[1].id, 'downloads', 'files menu should sort alphabetically')
assertEquals(filesMenu.items[2].id, 'openScripts', 'files menu alphabetical ordering should include scripts second')
assertTrue(findItem(filesMenu.items, 'utilityTag') == nil, 'utility-tagged action should be excluded')

local utilitiesMenu = expect(result.menus.utilities, 'utilities menu should exist')
local utilityTagItem = expect(findItem(utilitiesMenu.items, 'utilityTag'), 'utilities should include tag-sourced action')
assertEquals(utilityTagItem.shortcut, 'u', 'utilities menu should assign tagged shortcut')
assertTrue(hasMenuItem(utilitiesMenu.items, 'utilityChild'), 'utilities should expose nested utilityChild menu')

local utilityChildMenu = expect(result.menus.utilityChild, 'utilityChild menu should exist')
local nestedAction = expect(findItem(utilityChildMenu.items, 'utilityChildAction'), 'utilityChild should include explicit nested action')
assertEquals(nestedAction.shortcut, 'c', 'utility child action should keep explicit shortcut')

local isolatedMenu = expect(result.menus.isolated, 'isolated menu should exist')
assertTrue(findItem(isolatedMenu.items, 'utilityTag') ~= nil, 'isolated should auto-populate tagged utility action')
assertTrue(not hasMenuItem(isolatedMenu.items, 'utilityChild'), 'isolated should omit utilityChild submenu when includeSubMenus is false')

local appsMenu = expect(result.menus.apps, 'apps menu should exist')
local browserItem = expect(findItem(appsMenu.items, 'appBrowser'), 'apps menu should include browser action')
local backupItem = expect(findItem(appsMenu.items, 'appBackup'), 'apps menu should include backup action')
local builderItem = expect(findItem(appsMenu.items, 'appBuilder'), 'apps menu should include builder action')
assertEquals(browserItem.shortcut, 'b', 'browser should keep default shortcut')
assertEquals(browserItem.shortcutSource, 'default', 'browser shortcut should come from default')
assertEquals(backupItem.shortcut, 'k', 'backup should fall back to its alternate shortcut')
assertEquals(backupItem.shortcutSource, 'fallback', 'backup shortcut source should note fallback')
assertEquals(builderItem.shortcutSource, 'auto', 'builder should receive auto-assigned shortcut')
assertEquals(builderItem.shortcut, '1', 'builder should use first auto shortcut')
assertEquals(appsMenu.items[1].id, 'appBuilder', 'apps menu should sort by shortcut ascending')
assertEquals(appsMenu.items[2].id, 'appBrowser', 'apps sorting should place default shortcut second')
assertEquals(appsMenu.items[3].id, 'appBackup', 'apps sorting should reflect fallback assignment last')

local conflictFound = false
for _, conflict in ipairs(result.diagnostics.conflicts) do
	if conflict.menu == 'apps' and conflict.item == 'appBuilder' then
		conflictFound = true
		assertEquals(conflict.assigned, '1', 'conflict report should capture assigned auto shortcut')
	end
end
assertTrue(conflictFound, 'auto-assigned shortcut should be reported as conflict')

print('[PASS] menu builder assembles menus, applies policies, and resolves conflicts')

local dupResult = MenuBuilder.build({
	actions = actions,
	menus = {
		{
			title = 'globalRoot',
			description = 'Root',
			memberRoot = true,
			policy = { includeSubMenus = true },
		},
		{
			title = 'loopMenu',
			description = 'Loop',
			subMenus = { 'loopMenu', 'apps', 'apps' },
		},
		{
			title = 'apps',
			description = 'Applications',
		},
	},
})
assertTrue(dupResult.ok == false, 'self-referential submenu should produce error state')

local selfReferenceDetected = false
local duplicateDetected = false
for _, err in ipairs(dupResult.diagnostics.errors or {}) do
	if err.code == 'menu.subMenus.self' then
		selfReferenceDetected = true
	end
end
for _, warn in ipairs(dupResult.diagnostics.warnings or {}) do
	if warn.code == 'menu.subMenus.duplicate' then
		duplicateDetected = true
	end
end

assertTrue(selfReferenceDetected, 'self-referential submenu diagnostic should be emitted')
assertTrue(duplicateDetected, 'duplicate submenu diagnostic should be emitted')

print('[PASS] menu builder reports submenu diagnostics')

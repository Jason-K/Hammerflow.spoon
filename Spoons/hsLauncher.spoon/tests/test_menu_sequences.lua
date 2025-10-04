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

local LOADER_GUARD = '__hslauncher_loader_menu_sequences'

local function registerHsLauncherLoader(root)
    if package[LOADER_GUARD] then return end
    table.insert(package.searchers, 2, function(moduleName)
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
local MenuSequences = require('hsLauncher.main.runtime.menu.sequences')

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

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or 'Assertion failed') .. string.format('\nexpected: %s\nactual: %s', tostring(expected), tostring(actual)))
    end
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
    },
    {
        name = 'primary.launcher.favorites',
        actions = { 'showFavorites()' },
        menuDetails = {
            description = 'Favorites',
            inMenu = { 'globalRoot' },
            defaultShortcut = 'f',
        },
    },
    {
        name = 'utility.cleanup.cache',
        actions = { 'cleanupCaches()' },
        menuDetails = {
            description = 'Clean Caches',
            inMenu = { 'utilities' },
            defaultShortcut = 'c',
            perMenu = {
                utilities = {
                    description = 'Clean Up Caches',
                    defaultShortcut = 'c',
                },
            },
        },
    },
}

local menus = {
    {
        title = 'globalRoot',
        description = 'Launcher Root',
        memberRoot = true,
        policy = { includeSubMenus = true },
        subMenus = { 'utilities' },
    },
    {
        title = 'utilities',
        description = 'Utilities',
        memberRoot = false,
        defaultShortcut = 'u',
    },
}

resetModules()
package.preload[ACTIONS_MODULE] = function() return actions end
package.preload[EXTERNAL_MODULE] = function() return {} end
package.preload[MENUS_MODULE] = function() return menus end

local loadResult = ConfigLoader.load()
resetModules()

assertTrue(loadResult.ok, 'Loader should succeed for menu sequence test')

local menuResult = MenuBuilder.build({ actions = loadResult.actions, menus = loadResult.menus })
assertTrue(menuResult.ok, 'Menu builder should succeed for menu sequence test')

local sequences = MenuSequences.new(menuResult)

local rootEntries = sequences:forMenu('globalRoot')
assertEquals(#rootEntries, 3, 'Root menu should expose two actions and one submenu')

local overview = sequences:find({ 'l' })
assertTrue(overview ~= nil, 'Overview sequence should exist')
assertEquals(overview.actionId, 'primary.launcher.overview', 'Overview action id should match')
assertTrue(type(overview.handler) == 'function', 'Overview handler should resolve to function')

local favorites = sequences:find('f')
assertTrue(favorites ~= nil, 'Favorites sequence should exist')
assertEquals(favorites.type, 'action', 'Favorites should be an action sequence')

local utilities = sequences:find({ 'u' })
assertTrue(utilities ~= nil, 'Utilities submenu sequence should exist')
assertEquals(utilities.type, 'menu', 'Utilities entry should be a menu sequence')
assertEquals(utilities.targetMenuId, 'utilities', 'Menu sequence should point to utilities menu')

local nested = sequences:find({ 'u', 'c' })
assertTrue(nested ~= nil, 'Nested action sequence should be generated')
assertEquals(nested.actionId, 'utility.cleanup.cache', 'Nested action id should match nested menu action')
assertEquals(nested.keys[1], 'u', 'Nested sequence should include parent shortcut first')
assertEquals(nested.keys[2], 'c', 'Nested sequence should include action shortcut second')
assertTrue(type(nested.handler) == 'function', 'Nested handler should resolve to function')

print('[PASS] menu sequences generate flatten paths for menus and actions')

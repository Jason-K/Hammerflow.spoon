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

local LOADER_GUARD = '__hslauncher_loader_menu_ui'

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
local MenuUI = require('hsLauncher.main.runtime.menu.ui')

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
    },
}

resetModules()
package.preload[ACTIONS_MODULE] = function() return actions end
package.preload[EXTERNAL_MODULE] = function() return {} end
package.preload[MENUS_MODULE] = function() return menus end

local loadResult = ConfigLoader.load()
resetModules()

assertTrue(loadResult.ok, 'Loader should succeed for menu UI test')

local menuResult = MenuBuilder.build({ actions = loadResult.actions, menus = loadResult.menus })
assertTrue(menuResult.ok, 'Menu builder should succeed for menu UI test')

local ui = MenuUI.new(menuResult)
local root = ui:root()
assertTrue(root ~= nil, 'Root menu should be available')
assertEquals(root.id, 'globalRoot', 'Root id should be globalRoot')

local text = ui:toPlainText('globalRoot')
assertTrue(text:match('Launcher Overview') ~= nil, 'Plain text should include launcher overview action')

local rows = ui:chooserRows('globalRoot')
assertEquals(#rows, 3, 'Chooser rows should include actions and submenu')
assertEquals(rows[1].menuId, 'globalRoot', 'First row should reference menu id')

local invokedSelect = false

local function fakeChooserFactory(providedRows, menu, handler)
    assertEquals(menu.id, 'globalRoot', 'Factory should receive root menu')
    assertEquals(#providedRows, #rows, 'Factory should receive rows from UI')
    handler(providedRows[1].entry, menu, { id = providedRows[1].id, entry = providedRows[1].entry })
    return { rows = providedRows }
end

ui:show('globalRoot', {
    chooserFactory = fakeChooserFactory,
    onSelect = function(entry, menu)
        invokedSelect = true
        assertEquals(entry.id, rows[1].id, 'Selected entry should match first row')
        assertEquals(menu.id, 'globalRoot', 'Selected menu should be root')
    end,
})

assertTrue(invokedSelect, 'onSelect should be invoked by show')

print('[PASS] menu UI exports chooser rows and invokes selection handler')

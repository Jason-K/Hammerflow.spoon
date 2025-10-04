local scriptPath = debug.getinfo(1, "S").source:sub(2)
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

local LOADER_GUARD = '__hslauncher_loader_config'

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

local function normalizeProvider(provider)
	if type(provider) == 'function' then return provider end
	local value = provider
	return function ()
		return value
	end
end

local function withModules(config, fn)
	resetModules()
	config = config or {}
	package.preload[ACTIONS_MODULE] = normalizeProvider(config.actions or {})
	package.preload[EXTERNAL_MODULE] = normalizeProvider(config.external or {})
	package.preload[MENUS_MODULE] = normalizeProvider(config.menus or {})
	local ok, err = pcall(fn)
	resetModules()
	if not ok then error(err) end
end

local function assertEquals(actual, expected, message)
	if actual ~= expected then
		error((message or 'assertEquals failed') .. string.format('\nexpected: %s\nactual: %s', tostring(expected), tostring(actual)))
	end
end

local function assertTrue(value, message)
	if not value then
		error(message or 'assertTrue failed')
	end
end

local function assertContainsError(result, code)
	for _, err in ipairs(result.diagnostics.errors) do
		if err.code == code then return true end
	end
	error('Expected error code ' .. tostring(code) .. ' but none found')
end

local tests = {}

local function addTest(name, fn)
	tests[#tests + 1] = { name = name, fn = fn }
end

addTest('load succeeds with minimal valid config', function ()
	local actions = {
		{
			name = 'openScripts',
			actions = { 'hsLauncher.main.core.actions.open("~/Scripts/")' },
			menuDetails = {
				description = 'Open Scripts folder',
				inMenu = { 'globalRoot' },
			},
			tags = { 'filesystem' },
		},
	}
	local menus = {
		{
			title = 'globalRoot',
			description = 'Root Menu',
			memberRoot = true,
		},
	}
	withModules({ actions = actions, menus = menus }, function ()
		local result = ConfigLoader.load()
		assertTrue(result.ok, 'Expected loader ok')
		assertEquals(#result.actions, 1, 'Expected one action')
		assertEquals(#result.menus, 1, 'Expected one menu')
		assertEquals(#result.diagnostics.errors, 0, 'Expected no errors')
		assertEquals(#result.diagnostics.warnings, 0, 'Expected no warnings')
	end)
end)

addTest('duplicate action names reported', function ()
	local actions = {
		{ name = 'dup', actions = { 'step()' } },
		{ name = 'dup', actions = { 'step()' } },
	}
	withModules({ actions = actions }, function ()
		local result = ConfigLoader.load()
		assertTrue(not result.ok, 'Expected loader failure')
		assertContainsError(result, 'action.name.duplicate')
	end)
end)

addTest('external actions merge and index correctly', function ()
	local actions = {
		{
			name = 'primary.action',
			actions = { 'primary()' },
			menuDetails = {
				inMenu = { 'globalRoot' },
			},
		},
	}
	local external = {
		{
			name = 'external.global.sample',
			actions = { 'externalGlobal()' },
			menuDetails = {
				inMenu = { 'externalHotkeysGlobal' },
			},
			tags = { 'hotkeys.external', 'hotkeys.external.global' },
		},
		{
			name = 'external.app.sample',
			actions = { 'externalApp()' },
			menuDetails = {
				inMenu = { 'externalHotkeysApps' },
			},
			tags = { 'hotkeys.external', 'hotkeys.external.app' },
		},
	}
	local menus = {
		{ title = 'globalRoot', memberRoot = true },
		{ title = 'externalHotkeysGlobal' },
		{ title = 'externalHotkeysApps' },
	}
	withModules({ actions = actions, external = external, menus = menus }, function ()
		local result = ConfigLoader.load()
		assertTrue(result.ok, 'Expected loader ok with external actions')
		assertEquals(#result.actions, 3, 'Expected merged actions to include external entries')
		assertTrue(result.actionIndex['primary.action'] ~= nil, 'Primary action should be indexed')
		assertTrue(result.actionIndex['external.global.sample'] ~= nil, 'External global action should be indexed')
		assertTrue(result.actionIndex['external.app.sample'] ~= nil, 'External app action should be indexed')
	end)
end)

addTest('unknown menu reference reported', function ()
	local actions = {
		{
			name = 'missingMenu',
			actions = { 'step()' },
			menuDetails = {
				inMenu = { 'notDefined' },
			},
		},
	}
	local menus = {
		{ title = 'globalRoot' },
	}
	withModules({ actions = actions, menus = menus }, function ()
		local result = ConfigLoader.load()
		assertTrue(not result.ok, 'Expected loader failure')
		assertContainsError(result, 'action.menuDetails.inMenu.unknown')
	end)
end)

addTest('hotkey multikeyType required when multiple keys', function ()
	local actions = {
		{
			name = 'multi',
			actions = { 'step()' },
			hotkey = {
				trigger = {
					keys = {
						{ key = 's' },
						{ key = 'o' },
					},
				},
			},
		},
	}
	withModules({ actions = actions }, function ()
		local result = ConfigLoader.load()
		assertTrue(not result.ok, 'Expected loader failure')
		assertContainsError(result, 'action.hotkey.multikeyType.missing')
	end)
end)

addTest('duplicate menu titles reported', function ()
	local menus = {
		{ title = 'globalRoot' },
		{ title = 'globalRoot' },
	}
	withModules({ menus = menus }, function ()
		local result = ConfigLoader.load()
		assertTrue(not result.ok, 'Expected loader failure')
		assertContainsError(result, 'menu.title.duplicate')
	end)
end)

local passed = 0
for _, test in ipairs(tests) do
	local ok, err = pcall(test.fn)
	if ok then
		print('[PASS] ' .. test.name)
		passed = passed + 1
	else
		print('[FAIL] ' .. test.name)
		print(err)
	end
end

print(string.format('Executed %d tests: %d passed, %d failed', #tests, passed, #tests - passed))

if passed ~= #tests then
	error('Some config loader tests failed')
end

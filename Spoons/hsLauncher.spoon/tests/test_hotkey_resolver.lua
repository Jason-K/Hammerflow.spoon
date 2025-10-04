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

local LOADER_GUARD = '__hslauncher_loader_hotkey_resolver'

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

local Resolver = require('hsLauncher.main.runtime.hyper.hotkey_resolver')

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

local function captureActions()
	local fired = {}
	local actions = {}
	for index = 1, 3 do
		actions[index] = {
			name = 'action' .. index,
			actions = {
				function ()
					fired[#fired + 1] = 'action' .. index
				end,
			},
		}
	end
	return actions, fired
end

local function runTests()
	-- Test 1: basic global single hotkey
	do
		local actions, fired = captureActions()
		actions[1].hotkey = {
			trigger = {
				keys = {
					{ mods = { 'cmd' }, key = 'k' },
				},
			},
			context = {},
		}
		actions[1].menuDetails = { description = 'Test Action' }

		local result = Resolver.resolve(actions)
		assertEquals(#result.assignments, 1, 'Expected one assignment')
		local assignment = result.assignments[1]
		assertEquals(assignment.context, 'global', 'Expected global context')
		assertEquals(assignment.triggerType, 'single', 'Expected single trigger type')
		assertEquals(assignment.trigger.canonical, 'single:cmd+k', 'Expected canonical key for single combo')
		assignment.handler()
		assertEquals(#fired, 1, 'Handler should execute action')
		assertEquals(fired[1], 'action1', 'Handler should record action')
	end

	-- Test 2: sequence with contexts and suppression
	do
		local actions, _ = captureActions()
		actions[2].hotkey = {
			trigger = {
				keys = {
					{ mods = { 'ctrl' }, key = 'h' },
					{ mods = { 'ctrl' }, key = 'j' },
				},
				multikeyType = 'sequence',
				sequenceTimeoutMs = 750,
			},
			context = {
				{ context = 'global' },
				{ context = 'com.apple.finder', active = false },
			},
		}

		local result = Resolver.resolve(actions)
		assertEquals(#result.assignments, 1, 'Expected one active assignment')
		local assignment = result.assignments[1]
		assertEquals(assignment.context, 'global')
		assertEquals(assignment.triggerType, 'sequence')
		assertEquals(assignment.trigger.canonical, 'sequence:ctrl+h>ctrl+j')
		assertEquals(assignment.trigger.sequenceTimeoutMs, 750)
		assertEquals(#result.suppressed, 1, 'Expected one suppressed entry')
		assertEquals(result.suppressed[1].context, 'com.apple.finder')
	end

	-- Test 3: conflict detection
	do
		local actions, _ = captureActions()
		actions[1].hotkey = {
			trigger = {
				keys = {
					{ mods = { 'ctrl', 'alt' }, key = 'm' },
				},
			},
		}
		actions[2].hotkey = {
			trigger = {
				keys = {
					{ mods = { 'alt', 'ctrl' }, key = 'm' },
				},
			},
		}
		local result = Resolver.resolve(actions)
		assertEquals(#result.assignments, 2, 'Expected two assignments')
		assertEquals(#result.conflicts, 1, 'Expected one conflict entry')
		local conflict = result.conflicts[1]
		assertEquals(conflict.context, 'global')
		assertEquals(conflict.canonical, 'single:opt+ctrl+m')
		assertEquals(#conflict.assignments, 2, 'Conflict should include both assignments')
	end

	-- Test 4: disabled action skipped
	do
		local actions, _ = captureActions()
		actions[3].enabled = false
		actions[3].hotkey = {
			trigger = {
				keys = {
					{ key = 'p' },
				},
			},
		}
		local result = Resolver.resolve(actions)
		assertEquals(#result.assignments, 0, 'Disabled actions should not produce assignments')
		assertEquals(#result.disabled, 1, 'Disabled list recorded')
	end
end

runTests()

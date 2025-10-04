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

local Resolver = require('hsLauncher.main.runtime.hyper.hotkey_resolver')
local Dispatcher = require('hsLauncher.main.runtime.hyper.dispatcher')
local Registrar = require('hsLauncher.main.runtime.hyper.registrar')
local UI = require('hsLauncher.main.runtime.hyper.ui')

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

local function fakeAdapter()
	local adapter = { calls = {}, released = {} }
	function adapter:register(contextId, assignment)
		local token = {
			context = contextId,
			canonical = assignment.trigger and assignment.trigger.canonical,
			actionId = assignment.actionId or assignment.name,
		}
		self.calls[#self.calls + 1] = token
		return token
	end
	function adapter:unregister(binding)
		binding = binding or {}
		binding.released = true
		self.released[#self.released + 1] = binding
	end
	return adapter
end

local function captureActions()
	return {
		{
			name = 'alpha',
			hotkey = {
				trigger = {
					keys = {
						{ mods = { 'cmd', 'ctrl' }, key = 'p' },
					},
				},
				context = {
					{ context = 'global' },
				},
			},
			description = 'Alpha Action',
			actions = {
				function () end,
			},
		},
		{
			name = 'beta',
			hotkey = {
				trigger = {
					keys = {
						{ mods = { 'shift' }, key = 'b' },
						{ key = 'n' },
					},
					multikeyType = 'sequence',
					sequenceTimeoutMs = 500,
				},
				context = {
					{ context = 'global' },
					{ context = 'com.apple.Terminal', active = true },
				},
			},
			description = 'Beta Action',
			tags = { 'sequence' },
			actions = {
				function () end,
			},
		},
	}
end

local function runTests()
	local actions = captureActions()
	local resolution = Resolver.resolve(actions)
	assertEquals(#resolution.assignments, 3, 'Two contexts should produce three assignments (global twice, Terminal once)')

	local adapter = fakeAdapter()
	local registrar = Registrar.new({ hotkeyAdapter = adapter })
	local dispatcher = Dispatcher.new(resolution, { registrar = registrar })

	local registered = dispatcher:registerAll()
	assertTrue(registered.global ~= nil, 'Global context should register')
	assertEquals(#adapter.calls, #resolution.assignments, 'Adapter should receive each assignment')

	local contextBucket = dispatcher:getContext('global')
	assertTrue(contextBucket ~= nil, 'Context bucket should exist')
	assertEquals(#contextBucket.assignments, 2, 'Global bucket should include two assignments')

	local summary = dispatcher:summary()
	assertEquals(#summary, 2, 'Summary should include two contexts')

	local ui = UI.build(dispatcher.assignments)
	local text = ui:toPlainText()
	assertTrue(text:match('Alpha Action') ~= nil, 'UI output should include action descriptions')

	local released = dispatcher:teardown()
	assertEquals(released, #resolution.assignments, 'Teardown should release each binding')
	assertEquals(#adapter.released, #resolution.assignments, 'Adapter should record releases')
end

runTests()

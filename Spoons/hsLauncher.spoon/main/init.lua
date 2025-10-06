-- hsLauncher entrypoint for the declarative runtime

local logger = require('hsLauncher.main.core.logger')
local userRegistry = require('hsLauncher.main.user.registry')

local runtimeModule
local runtimeMode

local M = {}

local function declarativeRuntime()
	if runtimeModule == nil then
		runtimeModule = require('hsLauncher.main.runtime.init')
	end
	return runtimeModule
end

local function startDeclarative(options)
	local runtime = declarativeRuntime()
	if not runtime or type(runtime.start) ~= 'function' then
		return nil, 'declarative runtime module missing start()'
	end
	local instance, err = runtime.start(options)
	if not instance then
		return nil, err
	end
	runtimeMode = 'declarative'
	return instance
end

local function stopDeclarative()
	if runtimeMode ~= 'declarative' then return end
	local runtime = declarativeRuntime()
	if type(runtime) ~= 'table' or type(runtime.stop) ~= 'function' then
		runtimeMode = nil
		return
	end
	runtime.stop()
	runtimeMode = nil
end

function M.start(options)
	logger.info('hsLauncher start')
	userRegistry.load()
	local instance, err = startDeclarative(options)
	if instance then
		return M
	end
	local reason = tostring(err or 'unknown error')
	logger.error('hsLauncher: declarative runtime failed -> ' .. reason)
	return nil, err
end

function M.stop()
	stopDeclarative()
	logger.info('hsLauncher stop')
end

return M

---@diagnostic disable: undefined-global

local logger = require('hsLauncher.main.core.logger')
local UserActions = require('hsLauncher.main.user.userActions')

local contextId = 'window_management'

local function emptyContext()
	return {
		id = contextId,
		hyperBindings = {},
		modes = {},
		sequences = {},
		apps = {},
	}
end

local ctx = UserActions.hotkeys(contextId)
if not ctx then
	logger.warn('hotkeys_window_management: user actions did not define hotkeys context; returning empty context')
	ctx = emptyContext()
end

return ctx

-- hsLauncher/backup/core/shortcuts_modal.lua
-- Archived legacy shortcuts modal wrapper preserved for reference.

local M = {}
local log = require('hsLauncher.main.core.logger')
local modal = require('hsLauncher.main.backup.core.hyper_modal')

local MODE_NAME = 'shortcuts'

function M.start()
	if modal.isModeActive(MODE_NAME) then
		return
	end

	if not modal.describeMode(MODE_NAME) then
		log.error('shortcuts_modal: shortcuts mode has not been defined via hyper.defineMode')
		return
	end

	modal.enterMode(MODE_NAME)
	log.info('Shortcuts modal started (delegated to hyper modal)')
end

function M.stop()
	if modal.isModeActive(MODE_NAME) then
		modal.exitMode()
	end
end

return M

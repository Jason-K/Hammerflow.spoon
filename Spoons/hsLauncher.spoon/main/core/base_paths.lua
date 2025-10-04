local fs = require('hsLauncher.main.core.fs')

local M = {}

local function computeRoot()
	local info = debug.getinfo(1, 'S')
	local source = info and info.source or ''
	if source:sub(1, 1) == '@' then
		local path = source:sub(2)
		local root = path:match('^(.*)/main/core/base_paths%.lua$')
		if root then return root end
	end
	local envHome = os.getenv('HSLAUNCHER_HOME')
	if envHome and envHome ~= '' then return fs.expandUser(envHome) end
	local defaultHome = os.getenv('HOME') or ''
	return fs.join(defaultHome, 'Scripts', 'Metascripts', 'hsLauncher', 'hsLauncher')
end

local ROOT = computeRoot()

function M.root()
	return ROOT
end

function M.logsDir()
	return fs.join(ROOT, 'logs')
end

function M.backupsDir()
	return fs.join(ROOT, 'backups')
end

function M.docsDir()
	return fs.join(ROOT, 'docs')
end

function M.tempDir()
	return fs.join(ROOT, 'temp')
end

function M.testsDir()
	return fs.join(ROOT, 'tests')
end

function M.runtimeFile(...)
	return fs.join(ROOT, ...)
end

return M

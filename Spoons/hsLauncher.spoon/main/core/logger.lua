local fs = require('hsLauncher.main.core.fs')
local BasePaths = require('hsLauncher.main.core.base_paths')

local M = {}
local logFile = BasePaths.runtimeFile('logs', 'log.txt')
local errFile = BasePaths.runtimeFile('logs', 'errors.log')

local function ts()
	return os.date('!%Y-%m-%dT%H:%M:%SZ')
end

local function append(path, line)
	local dir = path:match('(.+)/[^/]+$')
	if dir then fs.ensureDirectory(dir) end
	local f, e = io.open(path, 'a')
	if not f then return nil, e end
	f:write(line .. "\n")
	f:close()
	return true
end

function M.info(msg)
	append(logFile, string.format('%s - INFO - %s', ts(), msg))
end

function M.warn(msg)
	append(logFile, string.format('%s - WARN - %s', ts(), msg))
end

function M.error(msg)
	append(logFile, string.format('%s - ERROR - %s', ts(), msg))
	append(errFile, string.format('%s - %s', ts(), msg))
end

return M

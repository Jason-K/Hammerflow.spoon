local fs = require('hs.fs')

local M = {}

local SEP = '/'

local function trimSlashes(segment, isFirst)
	if not segment or segment == '' then return '' end
	if isFirst and segment:sub(1, 1) == '/' then
		return segment:gsub('/+$', '')
	end
	return segment:gsub('^/*', ''):gsub('/*$', '')
end

function M.join(...)
	local segments = { ... }
	local out = {}
	for idx, seg in ipairs(segments) do
		if seg and seg ~= '' then
			local cleaned = trimSlashes(seg, idx == 1)
			if cleaned ~= '' then table.insert(out, cleaned) end
		end
	end
	local path = table.concat(out, SEP)
	if segments[1] and segments[1]:match('^/') then
		return '/' .. path:gsub('^/*', '')
	end
	return path
end

function M.expandUser(path)
	if not path then return nil end
	if path:sub(1, 1) ~= '~' then return path end
	local home = os.getenv('HOME') or ''
	return home .. path:sub(2)
end

local function ensureDir(dir)
	if not dir or dir == '' then return false, 'invalid-directory' end
	dir = M.expandUser(dir)
	if not dir or dir == '' then return false, 'invalid-directory' end
	local attr = fs.attributes(dir)
	if attr and attr.mode == 'directory' then return true end
	local parent = dir:match('(.+)/[^/]+$')
	if parent and parent ~= dir then
		local ok, err = ensureDir(parent)
		if not ok then return false, err end
	end
	local ok, err = fs.mkdir(dir)
	if ok or (err and err:find('File exists')) then return true end
	return false, err or 'mkdir-failed'
end

function M.ensureDirectory(path)
	return ensureDir(path)
end

function M.readFile(path)
	if not path then return nil, 'no-path' end
	local expanded = M.expandUser(path)
	if not expanded or expanded == '' then return nil, 'no-path' end
	local file, err = io.open(expanded, 'r')
	if not file then return nil, err end
	local ok, data = pcall(function ()
		return file:read('*a')
	end)
	file:close()
	if not ok then return nil, data end
	return data
end

function M.writeFile(path, contents, opts)
	opts = opts or {}
	if not path then return nil, 'no-path' end
	local expanded = M.expandUser(path)
	if not expanded or expanded == '' then return nil, 'no-path' end
	local dir = expanded:match('(.+)/[^/]+$')
	if dir then
		local ok, err = ensureDir(dir)
		if not ok then return nil, err end
	end
	local mode = opts.mode or 'w'
	local file, err = io.open(expanded, mode)
	if not file then return nil, err end
	local ok, writeErr = pcall(function ()
		file:write(contents or '')
	end)
	file:close()
	if not ok then return nil, writeErr end
	if opts.sync then fs.touch(expanded) end
	return true
end

function M.exists(path)
	if not path then return false end
	local expanded = M.expandUser(path)
	return fs.attributes(expanded) ~= nil
end

return M

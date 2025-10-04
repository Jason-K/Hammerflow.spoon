local obj = {}
obj.__index = obj

obj.name = 'hsLauncher'
obj.version = '0.3.0-dev'
obj.author = 'hsLauncher Contributors'
obj.homepage = 'https://github.com/jason/hsLauncher'
obj.license = 'MIT'

local logger = (hs and hs.logger and hs.logger.new) and hs.logger.new('hsLauncher.spoon', 'info') or nil

local rootCache
local pathAugmented = false
local loaderRegistered = false

local function debugLog(level, message)
	if logger and logger[level] then
		logger[level](logger, message)
	end
end

local function resourceRoot()
	if rootCache then return rootCache end
	if hs and hs.spoons and hs.spoons.resourcePath then
		local ok, path = pcall(hs.spoons.resourcePath)
		if ok and path and path ~= '' then
			rootCache = path
			if rootCache:sub(-1) ~= '/' then
				rootCache = rootCache .. '/'
			end
			debugLog('d', 'resourceRoot via hs.spoons.resourcePath -> ' .. rootCache)
			return rootCache
		end
	end

	local info = debug.getinfo(1, 'S')
	local source = info and info.source
	if source and source:sub(1, 1) == '@' then
		local dir = source:match('^@(.*)/init%.lua$')
		if dir then
			if dir:sub(-1) ~= '/' then
				dir = dir .. '/'
			end
			rootCache = dir
			debugLog('d', 'resourceRoot via debug.getinfo -> ' .. rootCache)
			return rootCache
		end
	end

	debugLog('w', 'resourceRoot could not determine spoon root; package.path will not be augmented')
	return nil
end

local function ensurePackagePath()
	if pathAugmented then return end
	local root = resourceRoot()
	if not root then return end

	local segments = {
		root .. '?.lua',
		root .. '?/init.lua',
	}

	local currentPath = package.path or ''
	local toPrepend = {}
	for _, segment in ipairs(segments) do
		if not currentPath:find(segment, 1, true) then
			table.insert(toPrepend, segment)
		end
	end

	if #toPrepend > 0 then
		package.path = table.concat(toPrepend, ';') .. ';' .. currentPath
		debugLog('d', 'prepended package.path entries: ' .. table.concat(toPrepend, ', '))
	end

	pathAugmented = true
end

local function ensureModuleLoader()
	if loaderRegistered then return end
	loaderRegistered = true

	table.insert(package.searchers, 2, function (moduleName)
		local relative = moduleName:match('^hsLauncher%.(.+)$')
		if not relative then return nil end

		local root = resourceRoot()
		if not root then
			return nil, 'hsLauncher module loader could not determine resource root'
		end

		local basePath = root .. relative:gsub('%.', '/')
		local tried = {}

		local function try(path)
			local loader, err = loadfile(path)
			if loader then return loader end
			table.insert(tried, err or ('no file \'' .. path .. '\''))
			return nil
		end

		local loader = try(basePath .. '.lua') or try(basePath .. '/init.lua')
		if loader then
			return loader
		end

		return nil, table.concat(tried, '\n')
	end)
end

function obj:core()
	ensurePackagePath()
	ensureModuleLoader()
	if not self._core then
		local ok, mod = pcall(require, 'hsLauncher.main.init')
		if not ok then
			error('hsLauncher: unable to load core module -> ' .. tostring(mod))
		end
		self._core = mod
	end
	return self._core
end

function obj:start(options)
	local core = self:core()
	if core.start then
		core.start(options)
		debugLog('i', 'hsLauncher core started via spoon wrapper')
	end
	return self
end

function obj:stop()
	if not self._core then return self end
	if self._core.stop then
		self._core.stop()
		debugLog('i', 'hsLauncher core stopped via spoon wrapper')
	end
	return self
end

function obj:restart(options)
	self:stop()
	self._core = nil
	pathAugmented = false
	self:start(options)
	return self
end

ensurePackagePath()
ensureModuleLoader()

return obj

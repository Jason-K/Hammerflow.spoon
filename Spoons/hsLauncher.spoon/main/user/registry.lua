local logger = require('hsLauncher.main.core.logger')
local Actions = require('hsLauncher.main.core.actions')
local Diagnostics = require('hsLauncher.main.core.diagnostics')

local ConfigLoader = require('hsLauncher.main.core.config_loader')
local MenuBuilder = require('hsLauncher.main.core.menu_builder')

local Registry = {}

local legacyModule
local legacyLoadErr

local function deepCopy(value, visited)
	if type(value) ~= 'table' then return value end
	visited = visited or {}
	if visited[value] then return visited[value] end
	local copy = {}
	visited[value] = copy
	for k, v in pairs(value) do
		copy[k] = deepCopy(v, visited)
	end
	return copy
end

local function parseBool(value, default)
	if value == nil then return default end
	local valueType = type(value)
	if valueType == 'boolean' then return value end
	if valueType == 'number' then return value ~= 0 end
	if valueType == 'string' then
		local lowered = value:lower()
		if lowered == '1' or lowered == 'true' or lowered == 'yes' or lowered == 'on' then return true end
		if lowered == '0' or lowered == 'false' or lowered == 'no' or lowered == 'off' then return false end
	end
	return default
end

local function isFeatureEnabled(config, name, envVar, defaultValue)
	local flags = (config and config.featureFlags) or {}
	local value = flags[name]
	if value ~= nil then
		return parseBool(value, defaultValue)
	end
	if envVar then
		local env = os.getenv(envVar)
		if env ~= nil then
			return parseBool(env, defaultValue)
		end
	end
	return defaultValue
end

local function mergeDiagnostics(primary, secondary)
	local combined = {
		errors = {},
		warnings = {},
		conflicts = {},
	}
	local function copyEntries(target, entries, sourceLabel)
		for _, entry in ipairs(entries or {}) do
			local record = deepCopy(entry)
			record.context = record.context or {}
			if sourceLabel then
				record.context.source = record.context.source or sourceLabel
				record.source = record.source or sourceLabel
			end
			target[#target + 1] = record
		end
	end
	copyEntries(combined.errors, primary and primary.errors, 'config-loader')
	copyEntries(combined.warnings, primary and primary.warnings, 'config-loader')
	copyEntries(combined.errors, secondary and secondary.errors, 'menu-builder')
	copyEntries(combined.warnings, secondary and secondary.warnings, 'menu-builder')
	copyEntries(combined.conflicts, secondary and secondary.conflicts, 'menu-builder')
	return combined
end

local function shallowCopy(source)
	if type(source) ~= 'table' then return source end
	local copy = {}
	for k, v in pairs(source) do copy[k] = v end
	return copy
end

local function loadLegacyUserActions(silent)
	if legacyModule ~= nil then return legacyModule end
	if legacyLoadErr ~= nil then
		if not silent then
			logger.error('user.registry: legacy userActions previously failed to load -> ' .. tostring(legacyLoadErr))
		end
		return nil
	end
	local ok, mod = pcall(require, 'hsLauncher.main.user.userActions')
	if not ok then
		legacyLoadErr = mod
		if not silent then
			logger.error('user.registry: unable to load legacy userActions -> ' .. tostring(mod))
		end
		return nil
	end
	legacyModule = mod
	return legacyModule
end

local state = {
	actions = {},
	actionIndex = {},
	actionList = {},
	loader = nil,
	builder = nil,
	diagnostics = {
		loader = nil,
		builder = nil,
		combined = nil,
	},
	leader = {
		options = {},
		layout = {},
	},
	contributions = {
		sequences = {},
		chords = {},
	},
	features = {
		menuBuilder = false,
	},
	legacy = {
		menuOrder = {},
	},
}

local hasLoaded = false

local function resetState()
	state.actions = {}
	state.actionIndex = {}
	state.actionList = {}
	state.loader = nil
	state.builder = nil
	state.diagnostics = {
		loader = nil,
		builder = nil,
		combined = nil,
	}
	state.leader = {
		options = {},
		layout = {},
	}
	state.contributions = {
		sequences = {},
		chords = {},
	}
	state.features = {
		menuBuilder = false,
	}
	state.legacy = {
		menuOrder = {},
	}
	hasLoaded = false
end

local function loadUserConfig()
	local ok, cfg = pcall(require, 'hsLauncher.main.user.config')
	if not ok then
		logger.error('user.registry: unable to load user config -> ' .. tostring(cfg))
		return {}
	end
	if type(cfg) ~= 'table' then
		logger.error('user.registry: user config must return a table')
		return {}
	end
	return cfg
end

local function compileActionSpec(action)
	local steps = {}
	for _, step in ipairs(action.actions or {}) do
		local stepType = type(step)
		if stepType == 'table' then
			steps[#steps + 1] = deepCopy(step)
		elseif stepType == 'function' then
			steps[#steps + 1] = Actions.call(step)
		elseif stepType == 'string' then
			logger.error(string.format('user.registry: action %s uses unsupported string step - convert to descriptor table', action.name))
		end
	end
	if #steps == 0 then return Actions.noop() end
	if #steps == 1 then return steps[1] end
	return Actions.sequence(steps)
end

local function registerActions(actionSpecs)
	for _, action in ipairs(actionSpecs or {}) do
		if type(action.name) == 'string' and action.name ~= '' then
			local entry = {
				id = action.name,
				name = action.name,
				action = deepCopy(action),
				actionSpec = compileActionSpec(action),
				menuDetails = deepCopy(action.menuDetails or {}),
				tags = deepCopy(action.tags or {}),
				enabled = action.enabled ~= false,
				hotkey = deepCopy(action.hotkey),
			}
			local label = nil
			if entry.menuDetails and entry.menuDetails.description then
				label = entry.menuDetails.description
			end
			entry.label = label or action.name
			entry.description = entry.menuDetails and entry.menuDetails.description or action.name
			state.actions[#state.actions + 1] = entry
			state.actions[action.name] = entry
			state.actionIndex[action.name] = entry
			state.actionList[#state.actionList + 1] = entry
		end
	end
end

local function extractLegacyActionSpec(spec)
	if type(spec) ~= 'table' then return nil end
	if spec.actionSpec ~= nil then return deepCopy(spec.actionSpec) end
	if spec.action ~= nil then return deepCopy(spec.action) end
	if type(spec.actions) == 'table' then
		local steps = {}
		for index, step in ipairs(spec.actions) do
			local stepType = type(step)
			if stepType == 'table' then
				steps[index] = deepCopy(step)
			elseif stepType == 'function' then
				steps[index] = Actions.call(step)
			end
		end
		if #steps == 0 then return nil end
		if #steps == 1 then return steps[1] end
		return Actions.sequence(steps)
	end
	return nil
end

local function registerLegacyActions()
	local legacy = loadLegacyUserActions(true)
	if not legacy then return end
	local ok, legacyActions = pcall(legacy.actions)
	if not ok then
		logger.warn('user.registry: unable to read legacy actions -> ' .. tostring(legacyActions))
		return
	end
	if type(legacyActions) ~= 'table' then return end
	for id, spec in pairs(legacyActions) do
		if type(id) == 'string' and id ~= '' and state.actionIndex[id] == nil then
			local actionSpec = extractLegacyActionSpec(spec)
			if actionSpec ~= nil then
				local entry = {
					id = id,
					name = id,
					action = deepCopy(spec),
					actionSpec = actionSpec,
					menuDetails = deepCopy(spec.menuDetails or {}),
					tags = deepCopy(spec.tags or {}),
					enabled = spec.enabled ~= false,
					hotkey = deepCopy(spec.hotkey),
					label = spec.label or spec.description or id,
					description = spec.description or spec.label or id,
				}
				local exitAfter = spec.exitAfter
				if exitAfter ~= nil then
					entry.action = entry.action or {}
					entry.action.exitAfter = exitAfter
				end
				state.actions[#state.actions + 1] = entry
				state.actions[id] = entry
				state.actionIndex[id] = entry
				state.actionList[#state.actionList + 1] = entry
			end
		end
	end
end

local function fallbackShortcut(label)
	if type(label) ~= 'string' then return nil end
	local glyph = label:match('%w')
	if glyph then return glyph:lower() end
	return nil
end

local function orderValue(item)
	return item.order or item.displayIndex or item.insertOrder or math.huge
end

local function normalizeShortcut(item, label)
	if type(item.shortcut) == 'string' and item.shortcut ~= '' then return item.shortcut end
	if type(item.defaultShortcut) == 'string' and item.defaultShortcut ~= '' then return item.defaultShortcut end
	if type(item.fallbackShortcut) == 'string' and item.fallbackShortcut ~= '' then return item.fallbackShortcut end
	return fallbackShortcut(label)
end

local function buildActionEntryFromMenuItem(item, section)
	local entry = state.actionIndex[item.id]
	if not entry or entry.enabled == false then return nil end
	local key = normalizeShortcut(item, entry.label)
	if not key or key == '' then
		logger.warn(string.format('user.registry: menu %s action %s missing shortcut', tostring(item.menuId or 'root'), tostring(item.id)))
		return nil
	end
	local exitAfter = true
	if entry.action and entry.action.exitAfter ~= nil then
		exitAfter = entry.action.exitAfter
	elseif item.action and item.action.exitAfter ~= nil then
		exitAfter = item.action.exitAfter
	end
	return {
		key = key,
		label = item.label or entry.label or item.id,
		description = item.description or entry.description or item.id,
		order = orderValue(item),
		section = section or 'Shortcuts',
		actionSpec = entry.actionSpec,
		actionId = item.id,
		exitAfter = exitAfter,
		metadata = {
			menuId = item.menuId,
			source = item.origin,
		},
	}
end

local function sortEntries(entries)
	table.sort(entries, function (a, b)
		local ao = a.order or math.huge
		local bo = b.order or math.huge
		if ao ~= bo then return ao < bo end
		return (a.label or '') < (b.label or '')
	end)
end

local function buildGroupFromMenu(menu, visited)
	if type(menu) ~= 'table' then return nil end
	visited = visited or {}
	if visited[menu.id] then return nil end
	visited[menu.id] = true
	local group = {
		type = 'group',
		label = menu.description or menu.title or menu.id,
		section = 'Menus',
		order = menu.orderIndex or math.huge,
		moduleId = menu.id,
		actions = {},
	}
	---@diagnostic disable-next-line: undefined-field
	local menus = (state.builder and state.builder.menus) or {}
	for _, item in ipairs(menu.items or {}) do
		if item.type == 'action' then
			local actionEntry = buildActionEntryFromMenuItem(item, 'Shortcuts')
			if actionEntry then
				actionEntry.metadata = actionEntry.metadata or {}
				actionEntry.metadata.menuId = menu.id
				actionEntry.metadata.parent = menu.id
				table.insert(group.actions, actionEntry)
			end
		elseif item.type == 'menu' then
			local child = menus[item.id]
			if type(child) == 'table' then
				local childGroup = buildGroupFromMenu(child, visited)
				if childGroup then
					childGroup.key = childGroup.key or normalizeShortcut(item, childGroup.label)
					childGroup.order = childGroup.order or orderValue(item)
					table.insert(group.actions, childGroup)
				end
			end
		end
	end
	visited[menu.id] = nil
	if #group.actions == 0 then return nil end
	sortEntries(group.actions)
	group.key = group.key or fallbackShortcut(group.label)
	if not group.key or group.key == '' then
		group.key = fallbackShortcut(menu.id) or 'm'
	end
	return group
end

local function buildLegacyActionEntry(legacy, actionId, entry, defaultSection, moduleId)
	if not legacy or type(legacy.resolve) ~= 'function' then return nil end
	local ok, spec = pcall(legacy.resolve, actionId)
	if not ok then
		logger.warn(string.format('user.registry: legacy action %s failed to resolve -> %s', tostring(actionId), tostring(spec)))
		return nil
	end
	if spec == nil then
		logger.warn(string.format('user.registry: legacy action %s missing spec', tostring(actionId)))
		return nil
	end
	local actionSpec = extractLegacyActionSpec(spec)
	if not actionSpec then
		logger.warn(string.format('user.registry: legacy action %s missing action descriptor', tostring(actionId)))
		return nil
	end
	local label = entry.label or spec.label or spec.description or actionId
	local description = entry.description or spec.description or spec.label or label
	local metadata = deepCopy(entry.metadata or {})
	metadata.module = metadata.module or moduleId
	local exitAfter = entry.exitAfter
	if exitAfter == nil then exitAfter = spec.exitAfter end
	if exitAfter == nil then exitAfter = true end
	local shortcut = normalizeShortcut({ shortcut = entry.key, defaultShortcut = entry.defaultShortcut, fallbackShortcut = entry.fallbackShortcut }, label)
	local key = entry.key or shortcut
	if not key or key == '' then key = fallbackShortcut(label) end
	return {
		key = key,
		label = label,
		description = description,
		order = entry.order,
		section = entry.section or defaultSection or 'Shortcuts',
		exitAfter = exitAfter ~= false,
		actionSpec = actionSpec,
		actionId = actionId,
		metadata = metadata,
	}
end

local function buildLegacyGroup(legacy, groupDef, defaultSection, moduleId)
	if type(groupDef) ~= 'table' then return nil end
	local section = groupDef.section or defaultSection or 'Menus'
	local entry = {
		type = 'group',
		key = groupDef.key,
		label = groupDef.label or groupDef.title or moduleId,
		description = groupDef.description or groupDef.label,
		order = groupDef.order,
		section = section,
		actions = {},
		metadata = deepCopy(groupDef.metadata or {}),
	}
	entry.metadata.moduleId = entry.metadata.moduleId or moduleId
	if type(groupDef.entries) == 'table' then
		for _, child in ipairs(groupDef.entries) do
			if child then
				if (child.kind == 'group') or type(child.entries) == 'table' then
					local nested = buildLegacyGroup(legacy, child, child.section or section, moduleId)
					if nested then entry.actions[#entry.actions + 1] = nested end
				else
					local ref = child.ref or child.id
					if ref then
						local actionEntry = buildLegacyActionEntry(legacy, ref, child, section, moduleId)
						if actionEntry then entry.actions[#entry.actions + 1] = actionEntry end
					end
				end
			end
		end
	end
	if #entry.actions == 0 then return nil end
	sortEntries(entry.actions)
	entry.key = entry.key or fallbackShortcut(entry.label) or fallbackShortcut(moduleId)
	entry.metadata.group = true
	return entry
end

local function buildLegacyLeaderEntries(legacy, ctx, moduleId)
	if type(ctx) ~= 'table' then return {} end
	local leader = ctx.leader
	if type(leader) ~= 'table' then return {} end
	local section = leader.section or ctx.section or moduleId or 'Modules'
	local results = {}
	if type(leader.rootEntries) == 'function' then
		local ok, entries = pcall(leader.rootEntries)
		if ok and type(entries) == 'table' then
			for _, entry in ipairs(entries) do
				local ref = entry and (entry.ref or entry.id)
				if ref then
					local actionEntry = buildLegacyActionEntry(legacy, ref, entry, section, moduleId)
					if actionEntry then results[#results + 1] = actionEntry end
				end
			end
		end
	end
	if type(leader.groups) == 'table' then
		for _, groupDef in ipairs(leader.groups) do
			local groupEntry = buildLegacyGroup(legacy, groupDef, section, moduleId)
			if groupEntry then results[#results + 1] = groupEntry end
		end
	elseif type(leader.root) == 'table' and type(leader.groups) == 'table' then
		for _, groupDef in ipairs(leader.groups) do
			local groupEntry = buildLegacyGroup(legacy, groupDef, section, moduleId)
			if groupEntry then
				groupEntry.key = groupEntry.key or leader.root.key
				groupEntry.label = groupEntry.label or leader.root.label
				groupEntry.order = groupEntry.order or leader.root.order
				results[#results + 1] = groupEntry
			end
		end
	end
	return results
end

local function ensureSectionOrder(layout)
	layout = layout or {}
	local order = layout.sectionOrder or {}
	local seen = {}
	for _, name in ipairs(order) do
		seen[name] = true
	end
	local function add(section)
		if not seen[section] then
			order[#order + 1] = section
			seen[section] = true
		end
	end
	add('Shortcuts')
	add('Menus')
	add('Exit')
	layout.sectionOrder = order
	layout.defaultSection = layout.defaultSection or 'Shortcuts'
	layout.title = layout.title or 'Leader Launcher'
	layout.footerText = layout.footerText or 'Select action or menu'
	return layout
end

local function buildLeaderConfigFromBuilder()
	local builder = state.builder
	if type(builder) ~= 'table' or type(builder.root) ~= 'table' then
		return { actions = {}, _layout = ensureSectionOrder(deepCopy(state.leader.layout)) }
	end
	local actions = {}
	local menus = builder.menus or {}
	for _, item in ipairs(builder.root.items or {}) do
		if item.type == 'action' then
			local actionEntry = buildActionEntryFromMenuItem(item, 'Shortcuts')
			if actionEntry then
				table.insert(actions, actionEntry)
			end
		elseif item.type == 'menu' then
			local child = menus[item.id]
			if child then
				local group = buildGroupFromMenu(child, {})
				if group then
					group.key = group.key or normalizeShortcut(item, group.label)
					group.order = group.order or orderValue(item)
					table.insert(actions, group)
				end
			end
		end
	end
	sortEntries(actions)
	local layout = ensureSectionOrder(deepCopy(state.leader.layout))
	return { actions = actions, _layout = layout }
end

local function buildLeaderConfigFromLegacy()
	local legacy = loadLegacyUserActions(false)
	if not legacy then
		return { actions = {}, _layout = ensureSectionOrder(deepCopy(state.leader.layout)) }
	end
	local menuOrder = state.legacy.menuOrder or {}
	if type(menuOrder) ~= 'table' or #menuOrder == 0 then
		local ok, names = pcall(legacy.contextNames)
		if ok and type(names) == 'table' then
			menuOrder = names
		else
			menuOrder = {}
		end
	end
	local actions = {}
	for _, name in ipairs(menuOrder) do
		local ok, ctx = pcall(legacy.menu, name)
		if ok and type(ctx) == 'table' then
			local entries = buildLegacyLeaderEntries(legacy, ctx, name)
			for _, entry in ipairs(entries) do actions[#actions + 1] = entry end
		else
			logger.warn(string.format('user.registry: unable to load legacy context %s -> %s', tostring(name), tostring(ctx)))
		end
	end
	sortEntries(actions)
	local layout = ensureSectionOrder(deepCopy(state.leader.layout))
	return { actions = actions, _layout = layout }
end

local function extractLeaderSettings(leaderConfig)
	if type(leaderConfig) ~= 'table' then
		return {}, {}
	end
	local options = {}
	local layout = {}
	for key, value in pairs(leaderConfig) do
		if key == 'rootLayout' and type(value) == 'table' then
			for layoutKey, layoutValue in pairs(value) do
				layout[layoutKey] = layoutValue
			end
		else
			options[key] = value
		end
	end
	return options, layout
end

local function ensureLoaded()
	if hasLoaded then return end
	Registry.load()
end

function Registry.load(configOverride)
	resetState()
	local config = loadUserConfig()
	if configOverride then
		for k, v in pairs(configOverride) do config[k] = v end
	end

	state.features.menuBuilder = isFeatureEnabled(config, 'menuBuilder', 'HSLAUNCHER_MENU_BUILDER', state.features.menuBuilder or false)
	state.legacy.menuOrder = deepCopy(config.menus or {})

	local loaderResult = ConfigLoader.load()
	state.loader = loaderResult
	state.diagnostics.loader = loaderResult and loaderResult.diagnostics or nil

	if loaderResult and loaderResult.ok then
		registerActions(loaderResult.actions)
	else
		loaderResult = loaderResult or { actions = {}, menus = {} }
	end

	registerLegacyActions()

	local builderResult = nil
	if loaderResult and loaderResult.ok then
		builderResult = MenuBuilder.build({ actions = loaderResult.actions, menus = loaderResult.menus })
	end
	state.builder = builderResult
	state.diagnostics.builder = builderResult and builderResult.diagnostics or nil
	state.diagnostics.combined = mergeDiagnostics(state.diagnostics.loader, state.diagnostics.builder)
	Diagnostics.report('config', state.diagnostics.combined, { prefix = '[config]' })

	local options, layout = extractLeaderSettings(config.leader)
	state.leader.options = options
	state.leader.layout = layout

	hasLoaded = true
	return state
end

function Registry.reload()
	package.loaded['hsLauncher.main.user.config'] = nil
	Actions.invalidateHandlers()
	return Registry.load()
end

function Registry.getAction(id)
	ensureLoaded()
	return state.actionIndex[id]
end

function Registry.resolveAction(id)
	ensureLoaded()
	local entry = state.actionIndex[id]
	if not entry or entry.enabled == false then return nil end
	return entry.actionSpec, entry
end

function Registry.iterActions(callback)
	ensureLoaded()
	for id, entry in pairs(state.actionIndex) do
		callback(id, entry)
	end
end

function Registry.buildLeaderConfig()
	ensureLoaded()
	if state.features.menuBuilder and state.builder and state.builder.root then
		return buildLeaderConfigFromBuilder()
	end
	return buildLeaderConfigFromLegacy()
end

function Registry.leaderOptions()
	ensureLoaded()
	return shallowCopy(state.leader.options)
end

function Registry.contributions()
	ensureLoaded()
	return state.contributions
end

function Registry.declarativeState()
	ensureLoaded()
	return {
		loader = state.loader,
		builder = state.builder,
		diagnostics = deepCopy(state.diagnostics),
		features = shallowCopy(state.features),
		legacy = {
			menuOrder = deepCopy(state.legacy.menuOrder),
		},
	}
end

return Registry

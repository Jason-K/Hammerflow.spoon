local json = require('hs.json')

local logger = require('hsLauncher.main.core.logger')
local Actions = require('hsLauncher.main.core.actions')
local hyper = require('hsLauncher.main.core.hyper_modal')

local M = {}

local function mergeOptions(base, override)
    local merged = {}
    if base then
        for k, v in pairs(base) do merged[k] = v end
    end
    if override then
        for k, v in pairs(override) do merged[k] = v end
    end
    return merged
end

local shiftCharMap = {
    ['~'] = '`',
    ['!'] = '1',
    ['@'] = '2',
    ['#'] = '3',
    ['$'] = '4',
    ['%'] = '5',
    ['^'] = '6',
    ['&'] = '7',
    ['*'] = '8',
    ['('] = '9',
    [')'] = '0',
    ['_'] = '-',
    ['+'] = '=',
    ['{'] = '[',
    ['}'] = ']',
    [':'] = ';',
    ['"'] = "'",
    ['<'] = ',',
    ['>'] = '.',
    ['?'] = '/',
}

local function segmentId(segment, label)
    if label and label ~= '' then
        local slug = label:lower():gsub('%s+', '_'):gsub('[^%w_]', ''):gsub('_+', '_')
        slug = slug:gsub('^_', ''):gsub('_$', '')
        if slug ~= '' then return slug end
    end
    if segment and segment ~= '' then
        local slug = tostring(segment):gsub('%s+', '_')
        slug = slug:gsub('[^%w_]', function(ch)
            return string.format('%02x', string.byte(ch))
        end)
        slug = slug:gsub('_+', '_')
        slug = slug:gsub('^_', ''):gsub('_$', '')
        if slug ~= '' then return slug end
    end
    return 'group'
end

local function trim(value)
    return value and (value:gsub('^%s+', ''):gsub('%s+$', '')) or value
end

local function normalizeKey(key)
    if not key or key == '' then return nil end
    if #key == 1 then
        if key:match('%l') ~= nil then return key end
        if key:match('%d') ~= nil then return key end
        if key:match('%u') ~= nil then return 'shift-' .. key:lower() end
        local shifted = shiftCharMap[key]
        if shifted ~= nil then return 'shift-' .. shifted end
        return key
    end
    return key
end

local function ensureSection(order, section)
    for _, existing in ipairs(order) do
        if existing == section then return end
    end
    table.insert(order, section)
end

local function describeAction(action)
    if action.description and action.description ~= '' then return action.description end
    if action.label and action.label ~= '' then return action.label end
    if action.type == 'application' then
        local path = trim(action.value) or ''
        local name = path:gsub('/+$', ''):match('([^/]+)%.app$')
            or path:match('([^/]+)$')
        return name or path or 'Application'
    end
    return trim(action.value) or action.value or 'Unnamed'
end

local function buildActionEntry(action, orderBase)
    local key = normalizeKey(action.key)
    if not key then return nil end
    local entry = {
        key = key,
        description = describeAction(action),
        label = action.label or action.key,
        order = action.order or orderBase,
        exitAfter = action.exitAfter ~= false,
        section = action.section or 'Actions',
    }
    if action.actionSpec then
        entry.action = action.actionSpec
    elseif action.action then
        entry.action = action.action
    else
        local value = trim(action.value)
        if not value or value == '' then
            logger.error(string.format('leader_config: action %s missing value', tostring(action.key)))
            return nil
        end
        if action.type == 'application' then
            entry.action = Actions.open({ path = value })
        elseif action.type == 'command' then
            entry.action = Actions.shell(value)
            entry.note = action.note or value
        elseif action.type == 'url' then
            entry.action = Actions.open({ url = value })
            entry.note = action.note or value
        else
            logger.error(string.format('leader_config: unsupported action type %s', tostring(action.type)))
            return nil
        end
    end
    if action.note and action.note ~= '' then entry.note = action.note end
    if action.badge then entry.badge = action.badge end
    if not entry.action then
        logger.error(string.format('leader_config: action %s missing action handler', tostring(action.key)))
        return nil
    end
    return entry
end

local function buildGroupEntry(groupInfo, orderBase)
    local key = normalizeKey(groupInfo.key)
    if not key then return nil end
    local modeName = groupInfo.modeName
    local entry = {
        key = key,
        description = groupInfo.label or modeName,
        label = groupInfo.label or groupInfo.key,
        order = groupInfo.order or orderBase,
        section = groupInfo.section or 'Groups',
        action = Actions.call(function()
            hyper.enterMode(modeName)
        end),
        exitAfter = false,
    }
    if groupInfo.note and groupInfo.note ~= '' then entry.note = groupInfo.note end
    return entry
end

local function registerMode(modeName, group, context)
    group._modeName = modeName
    local entries = {}
    local sectionOrder = context and context.isRoot and {} or { 'Actions' }
    local order = 0
    local groupEntries = {}
    context = context or {}
    local isRoot = false
    if context.isRoot == true then
        isRoot = true
    elseif context.rootConfig and group == context.rootConfig then
        isRoot = true
    end
    local layoutOverrides = nil
    if type(group._layout) == 'table' then
        layoutOverrides = group._layout
    elseif context.rootConfig and type(context.rootConfig._layout) == 'table' and group == context.rootConfig then
        layoutOverrides = context.rootConfig._layout
    end
    group._layout = nil
    local moduleIndex = 0
    local moduleSections = {}

    for _, action in ipairs(group.actions or {}) do
        order = order + 10
        if action.type == 'group' then
            local childContext = {
                path = { table.unpack(context.path or {}) },
                prefix = context.prefix,
                rootConfig = context.rootConfig,
                isRoot = false,
            }
            local childModeName = M.registerGroup(action, childContext)
            local groupSpec = {
                key = action.key,
                label = action.label,
                modeName = childModeName,
                section = action.section,
                note = action.note,
                order = action.order,
            }
            local entry = buildGroupEntry(groupSpec, order)
            if entry then
                if isRoot then
                    moduleIndex = moduleIndex + 1
                    local baseDescription = entry.description or entry.label or action.label or childModeName
                    entry.description = baseDescription
                    if not entry.displayKey then entry.displayKey = entry.key or entry.label end
                    entry.metadata = entry.metadata or {}
                    entry.metadata.moduleId = action.moduleId or action._modeName
                    entry.metadata.moduleIndex = moduleIndex
                    entry.metadata.leaderRoot = true
                    local moduleId = entry.metadata.moduleId
                    if moduleId then
                        entry.order = entry.order or (moduleIndex * 1000)
                        if entry.section then
                            local existing = moduleSections[moduleId]
                            if not existing or entry.metadata.moduleIndex < existing.index then
                                moduleSections[moduleId] = {
                                    index = entry.metadata.moduleIndex,
                                    section = entry.section,
                                }
                            end
                        end
                    end
                end
                table.insert(groupEntries, entry)
            end
        else
            local entry = buildActionEntry(action, order)
            if entry then table.insert(entries, entry) end
        end
    end

    if #groupEntries > 0 then
        ensureSection(sectionOrder, 'Groups')
        for _, entry in ipairs(groupEntries) do table.insert(entries, entry) end
    end

    ensureSection(sectionOrder, 'Exit')
    table.insert(entries, {
        key = 'escape',
        label = 'Esc',
        description = 'Exit',
        order = 1000,
        action = Actions.exit(),
        exitAfter = true,
        section = 'Exit',
    })
    table.insert(entries, {
        key = 'delete',
        label = '⌫',
        description = 'Back',
        order = 1010,
        action = Actions.exit(),
        exitAfter = true,
        section = 'Exit',
    })

    local layout = {
        width = 420,
        defaultSection = 'Actions',
        exitSection = 'Exit',
        chordSection = 'Groups',
        sectionOrder = sectionOrder,
    }
    if isRoot then
        layout.title = 'Leader Modules'
        layout.footerText = layout.footerText or 'Selection copied · press module key or Esc to exit'
        local orderedModules = {}
        for _, info in pairs(moduleSections) do
            orderedModules[#orderedModules + 1] = info
        end
        table.sort(orderedModules, function(a, b)
            return (a.index or math.huge) < (b.index or math.huge)
        end)
        local sectionOrderRoot = {}
        for _, info in ipairs(orderedModules) do
            local sectionName = info.section or 'Groups'
            ensureSection(sectionOrderRoot, sectionName)
        end
        ensureSection(sectionOrderRoot, 'Exit')
        layout.sectionOrder = sectionOrderRoot
    end

    if layoutOverrides then
        if layoutOverrides.title then layout.title = layoutOverrides.title end
        if layoutOverrides.footerText ~= nil then layout.footerText = layoutOverrides.footerText end
        if layoutOverrides.width then layout.width = layoutOverrides.width end
        if layoutOverrides.defaultSection then layout.defaultSection = layoutOverrides.defaultSection end
        if layoutOverrides.exitSection then layout.exitSection = layoutOverrides.exitSection end
        if layoutOverrides.chordSection then layout.chordSection = layoutOverrides.chordSection end
        if type(layoutOverrides.sectionOrder) == 'table' then
            local overrideOrder = {}
            for _, section in ipairs(layoutOverrides.sectionOrder) do
                overrideOrder[#overrideOrder + 1] = section
            end
            layout.sectionOrder = overrideOrder
        end
    end
    if layout.sectionOrder then
        ensureSection(layout.sectionOrder, layout.exitSection or 'Exit')
    end

    hyper.defineMode(modeName, {
        consume = true,
        layout = layout,
        entries = entries,
    })
end

function M.registerGroup(group, context)
    local path = { table.unpack(context.path or {}) }
    if group ~= context.rootConfig then
        local segment = segmentId(group.key, group.label)
        table.insert(path, segment)
    end
    local modeName
    if context.modeName then
        modeName = context.modeName
    else
        modeName = (context.prefix or 'leader') .. '.' .. table.concat(path, '.')
            :gsub('%.%.$', '.')
            :gsub('%.%.', '.')
    end
    registerMode(modeName, group, {
        path = path,
        prefix = context.prefix,
        rootConfig = context.rootConfig,
        isRoot = (group == context.rootConfig),
    })
    return modeName
end

local function toSequenceKeys(seq)
    if not seq then return nil end
    if type(seq) == 'table' then return seq end
    return { seq }
end

local function processRoot(config, opts)
    if type(config) ~= 'table' then return end
    local prefix = (opts and opts.prefix) or 'leader'
    local rootName = (opts and opts.rootName) or 'root'
    local rootModeName = (opts and opts.rootMode) or (prefix .. '.' .. rootName)

    M.registerGroup(config, {
        path = {},
        prefix = prefix,
        modeName = rootModeName,
        rootConfig = config,
    })

    local sequences = {}

    local rootSequence = opts and opts.rootSequence
    if rootSequence ~= false then
        rootSequence = rootSequence or 'space'
        local keys = toSequenceKeys(rootSequence)
        if keys then
            local addSequence = hyper.addSequenceSpec and function(spec)
                hyper.addSequenceSpec(spec)
            end or function(spec)
                hyper.addSequence(spec.keys, spec.fn)
            end
            addSequence({
                keys = keys,
                fn = function()
                    hyper.enterMode(rootModeName)
                end,
                description = string.format('Enter leader root mode (%s)', rootModeName),
                label = opts and opts.rootLabel,
                metadata = {
                    mode = rootModeName,
                    leaderRoot = true,
                },
                tags = { 'leader', 'root' },
                source = 'leader_config:rootSequence',
            })
            table.insert(sequences, { keys = keys, mode = rootModeName, root = true })
        end
    end

    local groupSequences = true
    if opts and opts.groupSequences ~= nil then
        groupSequences = opts.groupSequences
    end
    if groupSequences then
        for _, action in ipairs(config.actions or {}) do
            if action.type == 'group' and action._modeName then
                local key = normalizeKey(action.key)
                if key then
                    local addSequence = hyper.addSequenceSpec and function(spec)
                        hyper.addSequenceSpec(spec)
                    end or function(spec)
                        hyper.addSequence(spec.keys, spec.fn)
                    end
                    addSequence({
                        keys = { key },
                        fn = function()
                            hyper.enterMode(action._modeName)
                        end,
                        description = string.format('Enter leader group %s', action.label or action._modeName),
                        label = action.label,
                        metadata = {
                            mode = action._modeName,
                            leaderGroup = true,
                            groupKey = key,
                        },
                        tags = { 'leader', 'group' },
                        source = string.format('leader_config:group[%s]', tostring(action.key or action._modeName)),
                    })
                    table.insert(sequences, { keys = { key }, mode = action._modeName })
                end
            end
        end
    end

    return sequences
end

local function readConfigFile(path)
    local handle, err = io.open(path, 'r')
    if not handle then
        logger.error(string.format('leader_config: unable to read %s -> %s', tostring(path), tostring(err)))
        return nil
    end
    local content = handle:read('*a')
    handle:close()
    if not content then return nil end
    local decoded, decodeErr = json.decode(content)
    if not decoded then
        logger.error(string.format('leader_config: invalid JSON in %s -> %s', tostring(path), tostring(decodeErr)))
    end
    return decoded
end

function M.registerFromFile(path, opts)
    local config = readConfigFile(path)
    if not config then return nil end
    return M.registerFromConfig(config, opts)
end

function M.registerFromConfig(config, opts)
    return processRoot(config, opts or {})
end

function M.registerFromModules(opts)
    local registry = require('hsLauncher.main.user.registry')
    local config = registry.buildLeaderConfig()
    local leaderOpts = registry.leaderOptions()
    local mergedOpts = mergeOptions(leaderOpts, opts)
    return processRoot(config, mergedOpts)
end

return M

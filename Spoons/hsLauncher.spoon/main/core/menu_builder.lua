local MenuBuilder = {}

local DEFAULT_AUTO_SHORTCUTS = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' }

local function deepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[k] = deepCopy(v, seen)
    end
    return copy
end

local function toSet(list)
    if type(list) ~= 'table' then return nil, nil end
    local set = {}
    local ordered = {}
    for _, value in ipairs(list) do
        if type(value) == 'string' and value ~= '' then
            if not set[value] then ordered[#ordered + 1] = value end
            set[value] = true
        end
    end
    if #ordered == 0 then return nil, nil end
    return set, ordered
end

local function intersects(list, setRef)
    if not setRef or type(list) ~= 'table' then return false end
    for _, value in ipairs(list) do
        if type(value) == 'string' and setRef[value] then return true end
    end
    return false
end

local function buildIndex(list, key)
    local index = {}
    for _, item in ipairs(list or {}) do
        local name = item[key]
        if type(name) == 'string' and name ~= '' then
            index[name] = item
        end
    end
    return index
end

local function cloneMenus(menus)
    local order = {}
    local mapped = {}
    for _, spec in ipairs(menus or {}) do
        if type(spec) == 'table' and type(spec.title) == 'string' and spec.title ~= '' then
            local title = spec.title
            if not mapped[title] then
                mapped[title] = deepCopy(spec)
                order[#order + 1] = title
            end
        end
    end
    if not mapped.globalRoot then
        mapped.globalRoot = {
            title = 'globalRoot',
            description = 'Global Root',
            memberRoot = true,
            policy = { includeSubMenus = true },
        }
        table.insert(order, 1, 'globalRoot')
    end
    return mapped, order
end

local function nextInsertId(menu)
    menu._nextId = (menu._nextId or 0) + 1
    return menu._nextId
end

local function newMenu(spec, index)
    spec.policy = spec.policy or {}
    spec.subMenus = spec.subMenus or {}
    spec.excludeMenu = spec.excludeMenu or {}
    spec.sort = spec.sort or {}
    local includeTagsSet, includeTagsOrdered = toSet(spec.policy.includeTags)
    local excludeTagsSet = toSet(spec.policy.excludeTags)
    local excludeMenuSet = toSet(spec.excludeMenu)
    local autoPopulate = spec.policy.autoPopulateFromActions
    if autoPopulate == nil then autoPopulate = true end
    local includeSubMenus = spec.policy.includeSubMenus
    if includeSubMenus == nil then includeSubMenus = true end
    return {
        id = spec.title,
        title = spec.title,
        description = spec.description or spec.title,
        defaultShortcut = spec.defaultShortcut,
        fallbackShortcut = spec.fallbackShortcut,
        spec = spec,
        memberRoot = (spec.title == 'globalRoot') or spec.memberRoot == true,
        autoPopulate = autoPopulate,
        includeSubMenus = includeSubMenus,
        includeTagsSet = includeTagsSet,
        includeTagsOrdered = includeTagsOrdered,
        excludeTagsSet = excludeTagsSet,
        excludeMenuSet = excludeMenuSet,
        sortBy = spec.sort.by or 'alpha',
        sortKey = spec.sort.key,
        items = {},
        actionLookup = {},
        menuLookup = {},
        children = {},
        subMenuIds = deepCopy(spec.subMenus),
        orderIndex = index,
        shortcuts = {},
    }
end

local function ensureChildList(menu, childId)
    for _, existing in ipairs(menu.children) do
        if existing == childId then return end
    end
    menu.children[#menu.children + 1] = childId
end

local function applyOverrides(item, baseDetails, override)
    local description = nil
    if override and type(override.description) == 'string' and override.description ~= '' then
        description = override.description
    elseif baseDetails and type(baseDetails.description) == 'string' and baseDetails.description ~= '' then
        description = baseDetails.description
    end
    item.label = description or item.label or item.id
    item.description = description or item.description or item.id
    local defaultShortcut = override and override.defaultShortcut
    if defaultShortcut == nil and baseDetails then
        defaultShortcut = baseDetails.defaultShortcut
    end
    local fallbackShortcut = override and override.fallbackShortcut
    if fallbackShortcut == nil and baseDetails then
        fallbackShortcut = baseDetails.fallbackShortcut
    end
    if defaultShortcut ~= nil then item.defaultShortcut = defaultShortcut end
    if fallbackShortcut ~= nil then item.fallbackShortcut = fallbackShortcut end
    if override and override.order ~= nil then
        item.order = override.order
    end
    return item
end

local function addMenuItem(menu, child, reason)
    if menu.menuLookup[child.id] then return menu.menuLookup[child.id] end
    local item = {
        type = 'menu',
        id = child.id,
        menu = child,
        label = child.description or child.title,
        description = child.description or child.title,
        defaultShortcut = child.defaultShortcut,
        fallbackShortcut = child.fallbackShortcut,
        origin = reason or 'submenu',
        insertOrder = nextInsertId(menu),
    }
    menu.items[#menu.items + 1] = item
    menu.menuLookup[child.id] = item
    ensureChildList(menu, child.id)
    return item
end

local function actionHidden(details, override)
    if details and details.hidden then return true end
    if override and override.hidden then return true end
    return false
end

local function addActionItem(menu, action, reason, override)
    local existing = menu.actionLookup[action.name]
    local baseDetails = action.menuDetails or {}
    if actionHidden(baseDetails, override) then return existing end
    if existing then
        existing.origin = existing.origin == 'explicit' and existing.origin or reason
        applyOverrides(existing, baseDetails, override)
        return existing
    end
    local item = {
        type = 'action',
        id = action.name,
        action = action,
        label = action.name,
        description = action.menuDetails and action.menuDetails.description or action.name,
        defaultShortcut = baseDetails.defaultShortcut,
        fallbackShortcut = baseDetails.fallbackShortcut,
        origin = reason,
        insertOrder = nextInsertId(menu),
        tags = action.tags,
        enabled = action.enabled ~= false,
    }
    applyOverrides(item, baseDetails, override)
    item.order = item.order or baseDetails.order
    menu.items[#menu.items + 1] = item
    menu.actionLookup[action.name] = item
    return item
end

local function filterByExcludeTags(menu)
    if not menu.excludeTagsSet then return end
    local filtered = {}
    menu.actionLookup = {}
    menu.menuLookup = {}
    menu.children = {}
    for _, item in ipairs(menu.items) do
        if item.type == 'action' then
            if not intersects(item.tags, menu.excludeTagsSet) then
                filtered[#filtered + 1] = item
                menu.actionLookup[item.id] = item
            else
                -- action removed, skip
            end
        else
            filtered[#filtered + 1] = item
            menu.menuLookup[item.id] = item
            menu.children[#menu.children + 1] = item.id
        end
    end
    menu.items = filtered
end

local function assignShortcuts(menu, diagnostics, autoKeys)
    autoKeys = autoKeys or DEFAULT_AUTO_SHORTCUTS
    local used = {}
    for key, item in pairs(menu.shortcuts) do
        used[key] = item
    end
    menu.shortcuts = used
    local sorted = {}
    for _, item in ipairs(menu.items) do
        sorted[#sorted + 1] = item
        item.shortcut = nil
        item.shortcutSource = nil
    end
    table.sort(sorted, function(a, b)
        return (a.insertOrder or math.huge) < (b.insertOrder or math.huge)
    end)
    local pending = {}
    local function claim(item, key, source)
        if type(key) ~= 'string' or key == '' then return false end
        if used[key] then return false end
        item.shortcut = key
        item.shortcutSource = source
        used[key] = item
        return true
    end
    for _, item in ipairs(sorted) do
        local assigned = false
        if claim(item, item.defaultShortcut, 'default') then
            assigned = true
        elseif claim(item, item.fallbackShortcut, 'fallback') then
            assigned = true
        else
            pending[#pending + 1] = item
        end
    end
    for _, item in ipairs(pending) do
        local assigned = false
        for _, key in ipairs(autoKeys) do
            if not used[key] then
                claim(item, key, 'auto')
                assigned = true
                break
            end
        end
        if not assigned then
            diagnostics.errors[#diagnostics.errors + 1] = {
                code = 'menu.shortcut.exhausted',
                message = string.format('menu %s exhausted shortcut options for %s', menu.id, item.id),
                context = { menu = menu.id, item = item.id },
            }
        else
            diagnostics.conflicts[#diagnostics.conflicts + 1] = {
                menu = menu.id,
                item = item.id,
                type = item.type,
                assigned = item.shortcut,
                requested = item.defaultShortcut or item.fallbackShortcut,
                reason = 'auto-assigned',
            }
        end
    end
    menu.shortcuts = used
end

local function sortItems(menu)
    if menu.sortBy == 'shortcut' then
        table.sort(menu.items, function(a, b)
            local ka = a.shortcut or ''
            local kb = b.shortcut or ''
            if ka == kb then
                return (a.insertOrder or math.huge) < (b.insertOrder or math.huge)
            end
            return ka < kb
        end)
    elseif menu.sortBy == 'custom' then
        local key = menu.sortKey
        table.sort(menu.items, function(a, b)
            local va = a.order or (key and a[key]) or math.huge
            local vb = b.order or (key and b[key]) or math.huge
            if va == vb then
                return (a.insertOrder or math.huge) < (b.insertOrder or math.huge)
            end
            return va < vb
        end)
    else
        table.sort(menu.items, function(a, b)
            local la = (a.label or a.description or ''):lower()
            local lb = (b.label or b.description or ''):lower()
            if la == lb then
                return (a.insertOrder or math.huge) < (b.insertOrder or math.huge)
            end
            return la < lb
        end)
    end
    for index, item in ipairs(menu.items) do
        item.displayIndex = index
    end
end

local function includeTaggedActions(menu, actions)
    if not menu.includeTagsSet or not menu.autoPopulate then return end
    for _, action in ipairs(actions) do
        if action.enabled ~= false and intersects(action.tags, menu.includeTagsSet) then
            local override = nil
            if action.menuDetails and action.menuDetails.perMenu then
                override = action.menuDetails.perMenu[menu.id]
            end
            addActionItem(menu, action, 'policy.includeTags', override)
        end
    end
end

function MenuBuilder.build(config, opts)
    opts = opts or {}
    local diagnostics = {
        errors = {},
        warnings = {},
        conflicts = {},
    }
    if type(config) ~= 'table' then
        diagnostics.errors[#diagnostics.errors + 1] = {
            code = 'menu.config.invalid',
            message = 'menu builder expects table config',
        }
        return {
            ok = false,
            menus = {},
            orderedMenus = {},
            root = nil,
            diagnostics = diagnostics,
        }
    end
    local menusMap, order = cloneMenus(config.menus)
    local nodes = {}
    for idx, title in ipairs(order) do
        nodes[title] = newMenu(menusMap[title], idx)
    end
    for _, menu in pairs(nodes) do
        local seen = {}
        for index, childId in ipairs(menu.subMenuIds or {}) do
            if childId == menu.id then
                diagnostics.errors[#diagnostics.errors + 1] = {
                    code = 'menu.subMenus.self',
                    message = string.format('menu %s references itself as a submenu', menu.id),
                    context = { menu = menu.id, index = index },
                }
            elseif seen[childId] then
                diagnostics.warnings[#diagnostics.warnings + 1] = {
                    code = 'menu.subMenus.duplicate',
                    message = string.format('menu %s lists submenu %s multiple times', menu.id, childId),
                    context = { menu = menu.id, subMenu = childId },
                }
            else
                seen[childId] = true
            end
        end
    end
    local actions = config.actions or {}
    local actionIndex = buildIndex(actions, 'name')

    for _, action in ipairs(actions) do
        if action.enabled == false then goto continue end
        local details = action.menuDetails
        if details and details.hidden then goto continue end
        if details and type(details.inMenu) == 'table' then
            for _, menuName in ipairs(details.inMenu) do
                local node = nodes[menuName]
                if node then
                    local override = nil
                    if details.perMenu and details.perMenu[menuName] then
                        override = details.perMenu[menuName]
                    end
                    node.memberRoot = node.memberRoot or details.memberRoot == true
                    addActionItem(node, action, 'explicit', override)
                else
                    diagnostics.warnings[#diagnostics.warnings + 1] = {
                        code = 'menu.missingNode',
                        message = string.format('action %s references unknown menu %s', action.name, tostring(menuName)),
                    }
                end
            end
        end
        ::continue::
    end

    for _, menu in pairs(nodes) do
        if menu.includeSubMenus then
            for _, childId in ipairs(menu.subMenuIds) do
                local child = nodes[childId]
                if child ~= nil then addMenuItem(menu, child, 'submenu') end
            end
        end
    end

    for _, menu in pairs(nodes) do
        includeTaggedActions(menu, actions)
    end

    for _, menu in pairs(nodes) do
        filterByExcludeTags(menu)
    end

    local root = nodes.globalRoot
    if root then
        local exclusions = root.excludeMenuSet or {}
        for id, menu in pairs(nodes) do
            if menu ~= root and menu.memberRoot and not (exclusions and exclusions[id]) then
                addMenuItem(root, menu, 'rootMember')
            end
        end
    end

    for _, menu in pairs(nodes) do
        assignShortcuts(menu, diagnostics, opts.autoShortcuts or DEFAULT_AUTO_SHORTCUTS)
    end

    for _, menu in pairs(nodes) do
        sortItems(menu)
    end

    return {
        ok = #diagnostics.errors == 0,
        menus = nodes,
        orderedMenus = order,
        root = root,
        diagnostics = diagnostics,
        actions = actionIndex,
    }
end

return MenuBuilder

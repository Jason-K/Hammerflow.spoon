local MenuUI = {}
MenuUI.__index = MenuUI

local hsGlobal = rawget(_G, 'hs')

local function deepCopy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, val in pairs(value) do
        copy[key] = deepCopy(val, seen)
    end
    return copy
end

local function normalizeMenuItem(item)
    if type(item) ~= 'table' then return nil end
    local entry = {
        type = item.type or 'action',
        id = item.id,
        label = item.label or item.id,
        description = item.description or item.label or item.id,
        shortcut = item.shortcut,
        shortcutSource = item.shortcutSource,
        defaultShortcut = item.defaultShortcut,
        fallbackShortcut = item.fallbackShortcut,
        origin = item.origin,
        order = item.order,
        insertOrder = item.insertOrder,
        enabled = item.enabled ~= false,
        tags = deepCopy(item.tags or {}),
        action = item.action,
        metadata = deepCopy(item.metadata or {}),
    }
    if entry.type == 'menu' then
        entry.menuId = (item.menu and item.menu.id) or item.id
    elseif entry.type == 'action' then
        entry.actionId = (item.action and item.action.name) or item.id
    end
    return entry
end

local function exportMenu(menu)
    if type(menu) ~= 'table' then return nil end
    local exported = {
        id = menu.id,
        title = menu.title or menu.id,
        description = menu.description or menu.title or menu.id,
        defaultShortcut = menu.defaultShortcut,
        fallbackShortcut = menu.fallbackShortcut,
        memberRoot = menu.memberRoot == true,
        includeSubMenus = menu.includeSubMenus ~= false,
        orderIndex = menu.orderIndex,
        subMenus = deepCopy(menu.subMenuIds or menu.children or {}),
        items = {},
        lookup = {},
    }
    for _, item in ipairs(menu.items or {}) do
        local entry = normalizeMenuItem(item)
        if entry and entry.id then
            exported.items[#exported.items + 1] = entry
            exported.lookup[entry.id] = entry
        end
    end
    table.sort(exported.items, function(a, b)
        local keyA = a.order or a.insertOrder or math.huge
        local keyB = b.order or b.insertOrder or math.huge
        if keyA == keyB then
            return (a.label or a.id or '') < (b.label or b.id or '')
        end
        return keyA < keyB
    end)
    return exported
end

local function buildMenus(result)
    local menus = {}
    if not result then return menus, nil end
    for id, menu in pairs(result.menus or {}) do
        local exported = exportMenu(menu)
        if exported then menus[id] = exported end
    end
    local root = exportMenu(result.root or (result.menus and result.menus.globalRoot))
    if root then menus[root.id or 'globalRoot'] = root end
    local rootId = root and root.id or (result.root and result.root.id) or 'globalRoot'
    return menus, rootId
end

---@param builderResult table|nil
---@param options table|nil
---@return table
function MenuUI.new(builderResult, options)
    local menus, rootId = buildMenus(builderResult or {})
    local ui = {
        menus = menus,
        rootId = rootId,
        options = options or {},
    }
    return setmetatable(ui, MenuUI)
end

function MenuUI:root()
    return self.menus[self.rootId]
end

function MenuUI:menu(menuId)
    return self.menus[menuId or self.rootId]
end

function MenuUI:entries(menuId)
    local menu = self:menu(menuId)
    if not menu then return {} end
    return menu.items
end

function MenuUI:getEntry(menuId, entryId)
    local menu = self:menu(menuId)
    if not menu then return nil end
    return menu.lookup[entryId]
end

local function entrySummary(entry)
    local shortcut = entry.shortcut or entry.defaultShortcut or entry.fallbackShortcut
    if shortcut and shortcut ~= '' then
        return string.format('[%s] %s', shortcut, entry.description or entry.label or entry.id or '')
    end
    return entry.description or entry.label or entry.id or ''
end

function MenuUI:toPlainText(menuId)
    local menu = self:menu(menuId)
    if not menu then return '' end
    local lines = { string.format('# %s', menu.title or menu.id or 'menu') }
    for _, entry in ipairs(menu.items) do
        local prefix = entry.type == 'menu' and '>' or '-'
        lines[#lines + 1] = string.format('%s %s — %s', prefix, entry.label or entry.id or '', entrySummary(entry))
    end
    return table.concat(lines, '\n')
end

function MenuUI:chooserRows(menuId)
    local menu = self:menu(menuId)
    if not menu then return {} end
    local rows = {}
    for _, entry in ipairs(menu.items) do
        rows[#rows + 1] = {
            text = entry.label or entry.id or '',
            subText = entrySummary(entry),
            id = entry.id,
            type = entry.type,
            menuId = menu.id,
            entry = entry,
        }
    end
    return rows
end

local function defaultChooserFactory(rows, menu, handler, options)
    if not hsGlobal or not hsGlobal.chooser then
        return nil, 'hs.chooser unavailable'
    end
    local chooser = hsGlobal.chooser.new(function(choice)
        if not choice then return end
        local entry = choice.entry or (choice.id and menu.lookup[choice.id])
        if entry and handler then handler(entry, menu, choice) end
    end)
    chooser:choices(rows)
    if chooser.searchSubText and options.searchSubText ~= false then chooser:searchSubText(true) end
    if options.placeholder and chooser.placeholderText then chooser:placeholderText(options.placeholder) end
    if options.width and chooser.width then chooser:width(options.width) end
    chooser:show()
    return chooser
end

function MenuUI:show(menuId, options)
    options = options or {}
    local menu = self:menu(menuId)
    if not menu then return nil, 'menu not found' end
    local rows = self:chooserRows(menu.id)
    local handler = options.onSelect
    local factory = options.chooserFactory or defaultChooserFactory
    return factory(rows, menu, handler, options)
end

return MenuUI

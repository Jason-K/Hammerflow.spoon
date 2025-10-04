local MenuUI = require('hsLauncher.main.runtime.menu.ui')
local ActionFactory = require('hsLauncher.main.runtime.action_factory')

local MenuSequences = {}
MenuSequences.__index = MenuSequences

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

local function makeKey(path)
    return table.concat(path, '>')
end

local function compileAction(entry, options)
    if entry.type ~= 'action' then return nil end
    if type(entry.action) ~= 'table' then return nil end
    return ActionFactory.resolve(entry.action, options and options.actionOptions or nil)
end

local function clonePath(path)
    local out = {}
    for index = 1, #path do out[index] = path[index] end
    return out
end

local function extractShortcut(entry)
    if type(entry.shortcut) == 'string' and entry.shortcut ~= '' then
        return entry.shortcut
    end
    if type(entry.defaultShortcut) == 'string' and entry.defaultShortcut ~= '' then
        return entry.defaultShortcut
    end
    if type(entry.fallbackShortcut) == 'string' and entry.fallbackShortcut ~= '' then
        return entry.fallbackShortcut
    end
    return nil
end

local function normalizeRecord(menu, entry, path, options)
    local record = {
        menuId = menu.id,
        parent = menu.id,
        keys = clonePath(path),
        keyPath = makeKey(path),
        type = entry.type or 'action',
        label = entry.label or entry.description or entry.id,
        description = entry.description or entry.label or entry.id,
        shortcut = entry.shortcut,
        shortcutSource = entry.shortcutSource,
        defaultShortcut = entry.defaultShortcut,
        fallbackShortcut = entry.fallbackShortcut,
        origin = entry.origin,
        enabled = entry.enabled ~= false,
        metadata = deepCopy(entry.metadata or {}),
        tags = deepCopy(entry.tags or {}),
        entry = entry,
        depth = #path,
    }
    if entry.type == 'action' then
        record.actionId = entry.actionId or entry.id
        record.action = entry.action
        record.handler = compileAction(entry, options)
        record.exitAfter = entry.exitAfter
    elseif entry.type == 'menu' then
        record.targetMenuId = entry.menuId or entry.id
    end
    return record
end

local function gatherSequences(ui, options)
    local menus = ui.menus or {}
    local perMenu = {}
    local lookup = {}
    local all = {}
    local visited = {}

    local function visit(menuId, path)
        local menu = menus[menuId]
        if not menu or visited[menuId] then return end
        visited[menuId] = true
        local list = {}
        for _, entry in ipairs(menu.items or {}) do
            if entry.enabled == false then goto continue end
            local key = extractShortcut(entry)
            if not key then goto continue end
            local nextPath = clonePath(path)
            nextPath[#nextPath + 1] = key
            local record = normalizeRecord(menu, entry, nextPath, options)
            list[#list + 1] = record
            all[#all + 1] = record
            lookup[record.keyPath] = record
            if entry.type == 'menu' then
                visit(record.targetMenuId, nextPath)
            end
            ::continue::
        end
        perMenu[menuId] = list
        visited[menuId] = nil
    end

    visit(ui.rootId, {})
    return {
        all = all,
        perMenu = perMenu,
        lookup = lookup,
    }
end

---@param builderResult table|nil
---@param options table|nil
---@return table
function MenuSequences.new(builderResult, options)
    local ui = MenuUI.new(builderResult or {}, options and options.uiOptions or nil)
    local sequences = gatherSequences(ui, options)
    local instance = {
        ui = ui,
        menus = ui.menus,
        rootId = ui.rootId,
        all = sequences.all,
        perMenu = sequences.perMenu,
        lookup = sequences.lookup,
    }
    return setmetatable(instance, MenuSequences)
end

function MenuSequences:root()
    return self.ui:root()
end

function MenuSequences:forMenu(menuId)
    return self.perMenu[menuId or self.rootId] or {}
end

function MenuSequences:allSequences()
    return self.all
end

function MenuSequences:find(path)
    if type(path) == 'table' then
        return self.lookup[makeKey(path)]
    end
    if type(path) == 'string' then
        return self.lookup[path]
    end
    return nil
end

return MenuSequences

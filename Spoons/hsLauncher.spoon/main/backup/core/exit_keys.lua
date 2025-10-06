-- hsLauncher/backup/core/exit_keys.lua
-- Archived legacy exit key helpers used by the legacy hyper modal stack.

local M = {}

local DEFAULT_KEYS = { 'escape', 'return', 'space', 'tab' }

local function copyArray(source)
    local out = {}
    if not source then return out end
    for index, value in ipairs(source) do
        out[index] = value
    end
    return out
end

local function normalizeKey(value)
    if type(value) == 'string' then
        return value
    end
    if type(value) == 'table' then
        if type(value.key) == 'string' then return value.key end
        if type(value[1]) == 'string' then return value[1] end
    end
    return nil
end

local function uniqueKeys(keys)
    local out = {}
    local seen = {}
    for _, raw in ipairs(keys or {}) do
        local key = normalizeKey(raw)
        if key and not seen[key] then
            seen[key] = true
            out[#out + 1] = key
        end
    end
    return out
end

function M.defaults()
    return copyArray(DEFAULT_KEYS)
end

function M.normalize(keys)
    local normalized = uniqueKeys(keys)
    if #normalized == 0 then
        return M.defaults()
    end
    return normalized
end

local function ensureEntry(target, key, opts, index)
    local entry = target[key]
    if type(entry) ~= 'table' then
        entry = {}
        target[key] = entry
    end
    entry.key = entry.key or key
    if not entry.description or entry.description == '' then
        entry.description = opts.description
    end
    entry.passive = true
    entry.isExit = true
    entry.section = entry.section or opts.section
    if entry.order == nil then
        entry.order = (opts.orderBase or 1000) + (index - 1)
    end
    return entry
end

function M.ensure(target, opts)
    opts = opts or {}
    local keys = opts.keys and M.normalize(opts.keys) or M.defaults()
    local description = opts.description or string.format('Exit %s mode', tostring(opts.modeName or ''))
    local section = opts.exitSection or opts.section or 'Exit'
    local orderBase = opts.orderBase or 1000

    for index, key in ipairs(keys) do
        ensureEntry(target, key, {
            description = description,
            section = section,
            orderBase = orderBase,
        }, index)
    end

    return keys
end

return M

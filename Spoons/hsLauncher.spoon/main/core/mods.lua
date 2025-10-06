local M = {}

local config
local function getConfig()
    if config ~= nil then return config end
    local ok, cfg = pcall(require, 'hsLauncher.main.core.config')
    if ok and type(cfg) == 'table' then
        config = cfg
    else
        config = {}
    end
    return config
end

local function cloneList(list)
    if type(list) ~= 'table' then return {} end
    local out = {}
    for _, value in ipairs(list) do out[#out + 1] = value end
    return out
end

local function normalizeLabel(label)
    if type(label) ~= 'string' or label == '' then return nil end
    local lower = label:lower()
    if lower == 'option' or lower == 'opt' then return 'alt' end
    if lower == 'control' then return 'ctrl' end
    if lower == 'command' or lower == 'cmd' then return 'cmd' end
    if lower == 'shift' then return 'shift' end
    if lower == 'alt' then return 'alt' end
    if lower == 'ctrl' then return 'ctrl' end
    if lower == 'super' then return 'cmd' end
    return lower
end

local function fallbackHyper()
    return { 'cmd', 'alt', 'ctrl', 'shift' }
end

local function fallbackMeh()
    return { 'alt', 'ctrl', 'shift' }
end

function M.hyperChord()
    local cfg = getConfig()
    if type(cfg.hyperChord) == 'table' and #cfg.hyperChord > 0 then
        return cloneList(cfg.hyperChord)
    end
    if type(cfg.hyperMods) == 'table' and #cfg.hyperMods > 0 then
        return cloneList(cfg.hyperMods)
    end
    return fallbackHyper()
end

function M.mehChord()
    local cfg = getConfig()
    if type(cfg.mehChord) == 'table' and #cfg.mehChord > 0 then
        return cloneList(cfg.mehChord)
    end
    return fallbackMeh()
end

local function appendUnique(target, value)
    for _, existing in ipairs(target) do
        if existing == value then return end
    end
    target[#target + 1] = value
end

local function expandInto(target, mods)
    for _, value in ipairs(mods) do
        local normalized = normalizeLabel(value)
        if normalized then appendUnique(target, normalized) end
    end
end

function M.normalizeMods(mods)
    if mods == nil then return nil end
    local out = {}
    local function addSingle(label)
        local normalized = normalizeLabel(label)
        if normalized then appendUnique(out, normalized) end
    end

    if type(mods) == 'string' then
        if mods == 'hyper' then
            expandInto(out, M.hyperChord())
        elseif mods == 'meh' then
            expandInto(out, M.mehChord())
        else
            addSingle(mods)
        end
    elseif type(mods) == 'table' then
        for _, entry in ipairs(mods) do
            if entry == 'hyper' then
                expandInto(out, M.hyperChord())
            elseif entry == 'meh' then
                expandInto(out, M.mehChord())
            elseif type(entry) == 'table' then
                expandInto(out, entry)
            else
                addSingle(entry)
            end
        end
    end

    if #out == 0 then return nil end
    return out
end

return M

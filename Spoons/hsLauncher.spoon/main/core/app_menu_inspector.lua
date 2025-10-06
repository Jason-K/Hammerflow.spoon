-- hsLauncher/main/core/app_menu_inspector.lua
local M = {}
local log = require('hsLauncher.main.core.logger')

local function walk(items, used)
    if type(items) ~= 'table' then return end
    for _, it in ipairs(items) do
        local mods = it.AXMenuItemCmdModifiers or it.shortcutModifiers
        local key = it.AXMenuItemCmdChar or it.shortcut
        if mods and key and key ~= '' then
            table.insert(used, { mods = mods, key = key, title = it.AXTitle or it.title or '' })
        end
        if it.AXChildren then walk(it.AXChildren, used) end
        if it.children then walk(it.children, used) end
    end
end

function M.getUsedCombos(app)
    local used = {}
    local ok, items = pcall(function()
        --- @diagnostic disable-next-line: undefined-field
        return app:getMenuItems()
    end)
    if ok and items then walk(items, used) end
    return used
end

return M

local M = {}

local moduleName = 'hsLauncher.main.user.userActions'

local function buildModule()
    local contexts = {
        hotkey_management = {
            id = 'hotkey_management',
            section = 'Hotkey Management',
            leader = {
                section = 'Hotkey Management',
                rootEntries = function()
                    return {
                        {
                            ref = 'hotkey_management.enter_mode',
                            key = 'h',
                            label = 'Hotkey Mode',
                            description = 'Enter hotkey management modal',
                            exitAfter = false,
                            order = 10,
                            section = 'Hotkey Management',
                        },
                    }
                end,
            },
        },
        shortcuts = {
            id = 'shortcuts',
            section = 'Shortcuts',
            leader = {
                section = 'Shortcuts',
                rootEntries = function()
                    return {
                        {
                            ref = 'shortcuts.enter_mode',
                            key = 's',
                            label = 'Shortcuts Mode',
                            description = 'Enter shortcuts modal',
                            exitAfter = false,
                            order = 10,
                            section = 'Shortcuts',
                        },
                    }
                end,
            },
        },
        window_management = {
            id = 'window_management',
            section = 'Window Management',
            leader = {
                section = 'Window Management',
                rootEntries = function()
                    return {
                        {
                            ref = 'window_management.enter_mode',
                            key = 'w',
                            label = 'Window Mode',
                            description = 'Enter window management modal',
                            exitAfter = false,
                            order = 10,
                            section = 'Window Management',
                        },
                    }
                end,
            },
        },
    }

    local actions = {
        ['hotkey_management.enter_mode'] = {
            label = 'Hotkey Mode',
            description = 'Enter hotkey management modal',
            actionSpec = { kind = 'noop' },
            exitAfter = false,
        },
        ['shortcuts.enter_mode'] = {
            label = 'Shortcuts Mode',
            description = 'Enter shortcuts modal',
            actionSpec = { kind = 'noop' },
            exitAfter = false,
        },
        ['window_management.enter_mode'] = {
            label = 'Window Mode',
            description = 'Enter window management modal',
            actionSpec = { kind = 'noop' },
            exitAfter = false,
        },
    }

    local function copyContext(spec)
        if not spec then
            return nil
        end
        return {
            id = spec.id,
            section = spec.section,
            leader = spec.leader,
            actions = {},
        }
    end

    local function contextNames()
        local names = {}
        for key, _ in pairs(contexts) do
            names[#names + 1] = key
        end
        table.sort(names)
        return names
    end

    return {
        menu = function(name)
            local ctx = contexts[name]
            if not ctx then
                return { id = name, section = name, leader = { section = name }, actions = {} }
            end
            return copyContext(ctx)
        end,
        actions = function()
            return actions
        end,
        resolve = function(id)
            return actions[id]
        end,
        contextNames = contextNames,
    }
end

function M.install()
    package.loaded[moduleName] = nil
    package.preload[moduleName] = function()
        return buildModule()
    end
end

return M

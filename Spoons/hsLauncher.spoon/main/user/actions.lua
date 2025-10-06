local Actions = require('hsLauncher.main.core.actions')
local fs = require('hsLauncher.main.core.fs')
local logger = require('hsLauncher.main.core.logger')

local function expand(path)
    if not path or path == '' then return nil end
    return fs.expandUser(path)
end

local function shellOpenWithApplication(appName, targetPath)
    assert(type(appName) == 'string' and appName ~= '', 'shellOpenWithApplication: appName required')
    local expanded = expand(targetPath)
    if expanded ~= nil and expanded ~= '' then
        return Actions.shell(string.format([[open -a %q %q]], appName, expanded))
    end
    return Actions.shell(string.format([[open -a %q]], appName))
end

local function shellOpenPath(targetPath)
    assert(type(targetPath) == 'string' and targetPath ~= '', 'shellOpenPath: targetPath required')
    local expanded = expand(targetPath)
    if expanded == nil or expanded == '' then
        error('shellOpenPath: unable to expand path')
    end
    return Actions.shell(string.format([[open %q]], expanded))
end

local function shellOpenWithBundle(targetPath, bundleId)
    assert(type(targetPath) == 'string' and targetPath ~= '', 'shellOpenWithBundle: targetPath required')
    assert(type(bundleId) == 'string' and bundleId ~= '', 'shellOpenWithBundle: bundleId required')
    local expanded = expand(targetPath)
    if expanded == nil or expanded == '' then
        error('shellOpenWithBundle: unable to expand path')
    end
    return Actions.shell(string.format([[open %q -b %q]], expanded, bundleId))
end

local function pythonCommand(scriptPath, args)
    assert(type(scriptPath) == 'string' and scriptPath ~= '', 'pythonCommand: scriptPath required')
    local expanded = expand(scriptPath)
    if expanded == nil or expanded == '' then
        error('pythonCommand: unable to expand script path')
    end
    local command = string.format([[python3 %q]], expanded)
    if args and args ~= '' then command = command .. ' ' .. args end
    return Actions.shell(command)
end

local function shellCommandWithArgs(executablePath, args)
    assert(type(executablePath) == 'string' and executablePath ~= '', 'shellCommandWithArgs: executablePath required')
    local expanded = expand(executablePath)
    if expanded == nil or expanded == '' then
        error('shellCommandWithArgs: unable to expand executable path')
    end
    local command = string.format([[%q]], expanded)
    if args and args ~= '' then command = command .. ' ' .. args end
    return Actions.shell(command)
end

local function cloneList(list)
    local result = {}
    for index, value in ipairs(list or {}) do
        result[index] = value
    end
    return result
end

local function showLauncherMenu(menuId)
    return Actions.call(function ()
        local ok, runtime = pcall(require, 'hsLauncher.main.runtime.init')
        if not ok then
            if logger and logger.warn then
                logger.warn('user.actions: runtime unavailable -> ' .. tostring(runtime))
            end
            return
        end
        local chooser, err = runtime.show(menuId)
        if not chooser and err and logger and logger.warn then
            logger.warn('user.actions: unable to present menu -> ' .. tostring(err))
        end
    end)
end

local actions = {
    {
        name = 'launcher.showMenu',
        actions = {
            showLauncherMenu(),
        },
        menuDetails = {
            hidden = true,
        },
        tags = { 'launcher', 'system' },
        hotkey = {
            trigger = {
                keys = {
                    { key = 'f15' },
                },
            },
        },
    },
    {
        name = 'applications.brave',
        actions = {
            Actions.open({
                path = expand('/Applications/Brave Browser.app'),
                app_name = 'Brave Browser',
                bundle_id = 'com.brave.Browser',
            }),
        },
        menuDetails = {
            description = 'Brave Browser',
            defaultShortcut = 'b',
            inMenu = { 'applications', 'applicationsBrowsers' },
            perMenu = {
                applications = {
                    description = 'Brave Browser',
                    defaultShortcut = 'b',
                    order = 20,
                },
                applicationsBrowsers = {
                    description = 'Brave Browser',
                    defaultShortcut = 'b',
                    order = 10,
                },
            },
        },
        tags = { 'applications', 'browser' },
    },
    {
        name = 'applications.dia',
        actions = {
            Actions.open({
                path = expand('/Applications/Dia.app'),
                app_name = 'Dia',
            }),
        },
        menuDetails = {
            description = 'Dia',
            defaultShortcut = 'd',
            inMenu = { 'applications', 'applicationsBrowsers' },
            perMenu = {
                applications = {
                    description = 'Dia',
                    defaultShortcut = 'd',
                    order = 30,
                },
                applicationsBrowsers = {
                    description = 'Dia',
                    defaultShortcut = 'd',
                    order = 20,
                },
            },
        },
        tags = { 'applications', 'browser' },
    },
    {
        name = 'applications.edge',
        actions = {
            Actions.open({
                path = expand('/Applications/Microsoft Edge.app'),
                app_name = 'Microsoft Edge',
                bundle_id = 'com.microsoft.Edge',
            }),
        },
        menuDetails = {
            description = 'Edge',
            defaultShortcut = 'e',
            inMenu = { 'applications', 'applicationsBrowsers' },
            perMenu = {
                applications = {
                    description = 'Edge',
                    defaultShortcut = 'e',
                    order = 40,
                },
                applicationsBrowsers = {
                    description = 'Edge',
                    defaultShortcut = 'e',
                    order = 30,
                },
            },
        },
        tags = { 'applications', 'browser' },
    },
    {
        name = 'applications.orion',
        actions = {
            Actions.open({
                path = expand('/Applications/Orion.app'),
                app_name = 'Orion',
            }),
        },
        menuDetails = {
            description = 'Orion',
            defaultShortcut = 'o',
            inMenu = { 'applications', 'applicationsBrowsers' },
            perMenu = {
                applications = {
                    description = 'Orion',
                    defaultShortcut = 'o',
                    order = 50,
                },
                applicationsBrowsers = {
                    description = 'Orion',
                    defaultShortcut = 'o',
                    order = 40,
                },
            },
        },
        tags = { 'applications', 'browser' },
    },
    {
        name = 'applications.sigma',
        actions = {
            Actions.open({
                path = expand('/Applications/SigmaOS.app'),
                app_name = 'SigmaOS',
            }),
        },
        menuDetails = {
            description = 'SigmaOS',
            defaultShortcut = 's',
            inMenu = { 'applications', 'applicationsBrowsers' },
            perMenu = {
                applications = {
                    description = 'SigmaOS',
                    defaultShortcut = 's',
                    order = 60,
                },
                applicationsBrowsers = {
                    description = 'SigmaOS',
                    defaultShortcut = 's',
                    order = 50,
                },
            },
        },
        tags = { 'applications', 'browser' },
    },
    {
        name = 'applications.tor',
        actions = {
            Actions.open({
                path = expand('/Applications/Tor Browser.app'),
                app_name = 'Tor Browser',
            }),
        },
        menuDetails = {
            description = 'Tor Browser',
            defaultShortcut = 't',
            inMenu = { 'applications', 'applicationsBrowsers' },
            perMenu = {
                applications = {
                    description = 'Tor Browser',
                    defaultShortcut = 't',
                    order = 70,
                },
                applicationsBrowsers = {
                    description = 'Tor Browser',
                    defaultShortcut = 't',
                    order = 60,
                },
            },
        },
        tags = { 'applications', 'browser' },
    },
    {
        name = 'applications.zen',
        actions = {
            Actions.open({
                path = expand('/Applications/Zen.app'),
                app_name = 'Zen',
            }),
        },
        menuDetails = {
            description = 'Zen',
            defaultShortcut = 'z',
            inMenu = { 'applications', 'applicationsBrowsers' },
            perMenu = {
                applications = {
                    description = 'Zen',
                    defaultShortcut = 'z',
                    order = 80,
                },
                applicationsBrowsers = {
                    description = 'Zen',
                    defaultShortcut = 'z',
                    order = 70,
                },
            },
        },
        tags = { 'applications', 'browser' },
    },
    {
        name = 'applications.acrobat',
        actions = {
            Actions.open({
                path = expand('/Applications/Adobe Acrobat DC/Adobe Acrobat.app'),
                app_name = 'Adobe Acrobat',
            }),
        },
        menuDetails = {
            description = 'Acrobat',
            defaultShortcut = 'a',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'Acrobat',
                    defaultShortcut = 'a',
                    order = 90,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.code',
        actions = {
            Actions.open({
                path = expand('/Applications/Visual Studio Code - Insiders.app'),
                app_name = 'Visual Studio Code - Insiders',
            }),
        },
        menuDetails = {
            description = 'Code',
            defaultShortcut = 'c',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'Code',
                    defaultShortcut = 'c',
                    order = 100,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.QSpace',
        actions = {
            Actions.open({
                path = expand('/Applications/QSpace Pro.app'),
                app_name = 'QSpace Pro',
            }),
        },
        menuDetails = {
            description = 'Finder',
            defaultShortcut = 'f',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'Finder',
                    defaultShortcut = 'f',
                    order = 110,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.github',
        actions = {
            Actions.open({
                path = expand('/Applications/GitHub Desktop.app'),
                app_name = 'GitHub Desktop',
            }),
        },
        menuDetails = {
            description = 'GitHub Desktop',
            defaultShortcut = 'g',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'GitHub Desktop',
                    defaultShortcut = 'g',
                    order = 120,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.iterm',
        actions = {
            Actions.open({
                path = expand('~/Applications/iTerm.app'),
                app_name = 'iTerm',
            }),
        },
        menuDetails = {
            description = 'iTerm',
            defaultShortcut = 'i',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'iTerm',
                    defaultShortcut = 'i',
                    order = 130,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.outlook',
        actions = {
            Actions.open({
                path = expand('/Applications/Microsoft Outlook.app'),
                app_name = 'Microsoft Outlook',
            }),
        },
        menuDetails = {
            description = 'Outlook',
            defaultShortcut = 'o',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'Outlook',
                    defaultShortcut = 'o',
                    order = 140,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.proton',
        actions = {
            Actions.open({
                path = expand('/Applications/Proton Mail.app'),
                app_name = 'Proton Mail',
            }),
        },
        menuDetails = {
            description = 'Proton Mail',
            defaultShortcut = 'p',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'Proton Mail',
                    defaultShortcut = 'p',
                    order = 150,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.goodtask',
        actions = {
            Actions.open({
                path = expand('~/Applications/Setapp/GoodTask.app'),
                app_name = 'GoodTask',
            }),
        },
        menuDetails = {
            description = 'Reminders',
            defaultShortcut = 'r',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'Reminders',
                    defaultShortcut = 'r',
                    order = 160,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.messages',
        actions = {
            Actions.open({
                path = expand('/System/Applications/Messages.app'),
                app_name = 'Messages',
            }),
        },
        menuDetails = {
            description = 'SMS',
            defaultShortcut = 's',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'SMS',
                    defaultShortcut = 's',
                    order = 170,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.teams',
        actions = {
            Actions.open({
                path = expand('/Applications/Microsoft Teams.app'),
                app_name = 'Microsoft Teams',
            }),
        },
        menuDetails = {
            description = 'Teams',
            defaultShortcut = 't',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'Teams',
                    defaultShortcut = 't',
                    order = 180,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.word',
        actions = {
            Actions.open({
                path = expand('/Applications/Microsoft Word.app'),
                app_name = 'Microsoft Word',
            }),
        },
        menuDetails = {
            description = 'Word',
            defaultShortcut = 'w',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'Word',
                    defaultShortcut = 'w',
                    order = 190,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.excel',
        actions = {
            Actions.open({
                path = expand('/Applications/Microsoft Excel.app'),
                app_name = 'Microsoft Excel',
            }),
        },
        menuDetails = {
            description = 'Excel',
            defaultShortcut = 'x',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = 'Excel',
                    defaultShortcut = 'x',
                    order = 200,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.onepassword',
        actions = {
            Actions.open({
                path = expand('/Applications/1Password.app'),
                app_name = '1Password',
            }),
        },
        menuDetails = {
            description = '1Password',
            defaultShortcut = '1',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = '1Password',
                    defaultShortcut = '1',
                    order = 210,
                },
            },
        },
        tags = { 'applications' },
    },
    {
        name = 'applications.eightx8',
        actions = {
            Actions.open({
                path = expand('/Applications/8x8 Work.app'),
                app_name = '8x8 Work',
            }),
        },
        menuDetails = {
            description = '8x8',
            defaultShortcut = '8',
            inMenu = { 'applications' },
            perMenu = {
                applications = {
                    description = '8x8',
                    defaultShortcut = '8',
                    order = 220,
                },
            },
        },
        tags = { 'applications' },
    },
}

do
    local pathCases = [[~/Library/CloudStorage/OneDrive-BoxerandGerson,LLP/Documents/Cases]]
    local pathLibrary = [[~/Library/CloudStorage/OneDrive-Personal/1 - Work/---- - workers' compensation resources]]
    local pathAmaGuides =
    [[~/Library/CloudStorage/OneDrive-Personal/1 - Work/---- - workers' compensation resources/SOURCES - AMAG - AMA - Guides for the Evaluation of Permanent Impairment/2001, AMA Guides, Fifth Edition/AMA Guides to the Evaluation of Permanent Impairment - 5th Ed., 2001.pdf]]
    local pathPdrs =
    [[~/Library/CloudStorage/OneDrive-Personal/1 - Work/---- - workers' compensation resources/SOURCES - PDRS - Permanent Disability Rating Schedules/New Schedule - 2005 Schedule for Rating Permanent Disabilities PDRS - DOI on or after 2005.pdf]]
    local pathClaude = '~/Library/Application Support/Claude/claude_desktop_config.json'
    local pathLeaderKey = '~/Library/Application Support/Leader Key/config.json'
    local pathKarabinerRules = '~/.config/karabiner/karabiner.json'
    local pathSortLeaderKey = '~/Scripts/Application_Specific/Leaderkey/jjk_SortLeaderkey/jjk_sort_leaderkey_config.py'
    local pathKarabinerWorkspace = '~/Scripts/Workspaces/karabiner.ts.code-workspace'
    local pathScriptsWorkspace = '~/Scripts/Workspaces/Scripts.code-workspace'

    local directoryTags = { 'filesystem', 'filesystem.directory', 'directory' }
    local fileTags = { 'filesystem', 'filesystem.file', 'file' }
    local workspaceTags = { 'filesystem', 'filesystem.workspace', 'workspace' }

    local directories = {
        {
            name = 'filesystem.folders_applications',
            description = 'Applications',
            action = shellOpenWithApplication('QSpace Pro', '/Applications'),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'a', order = 10 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_cases',
            description = 'Cases',
            action = shellOpenWithApplication('QSpace Pro', pathCases),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'c', order = 20 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_downloads',
            description = 'Downloads',
            action = shellOpenWithApplication('QSpace Pro', '~/Downloads'),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'd', order = 30 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_finder',
            description = 'Finder',
            action = shellOpenWithApplication('QSpace Pro'),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'f', order = 40 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_gits',
            description = 'Gits',
            action = shellOpenWithApplication('QSpace Pro', '~/Gits'),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'g', order = 50 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_hammerspoon',
            description = 'Hammerspoon',
            action = shellOpenWithApplication('QSpace Pro', '~/.hammerspoon'),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'h', order = 60 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_home',
            description = 'Home',
            action = shellOpenWithApplication('QSpace Pro', '~'),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'j', order = 70 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_library',
            description = 'Library',
            action = shellOpenWithApplication('QSpace Pro', pathLibrary),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'l', order = 80 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_programs',
            description = 'Programs',
            action = shellOpenWithApplication('QSpace Pro', '~/Documents/programming'),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'p', order = 90 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_scripts',
            description = 'Scripts',
            action = shellOpenWithApplication('QSpace Pro', '~/Scripts'),
            menus = {
                { id = 'filesystemDirectories', shortcut = 's', order = 100 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_workspaces',
            description = 'Workspaces',
            action = shellOpenWithApplication('QSpace Pro', '~/Scripts/Workspaces'),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'w', order = 110 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_devonthink',
            description = 'DEVONthink',
            action = Actions.open({
                path = expand('/Applications/DEVONthink.app'),
                app_name = 'DEVONthink',
            }),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'D', order = 120 },
            },
            tags = directoryTags,
        },
        {
            name = 'filesystem.folders_scripts_workspace',
            description = 'Scripts workspace',
            action = shellOpenPath(pathScriptsWorkspace),
            menus = {
                { id = 'filesystemDirectories', shortcut = 'S', order = 130 },
            },
            tags = directoryTags,
        },
    }

    local files = {
        {
            name = 'filesystem.files_ama_guides',
            description = 'AMA Guides',
            action = shellOpenWithBundle(pathAmaGuides, 'net.sourceforge.skim-app.skim'),
            menus = {
                { id = 'filesystemFiles', shortcut = 'a', order = 10 },
            },
            tags = fileTags,
        },
        {
            name = 'filesystem.files_claude_mcps',
            description = 'Claude MCPs',
            action = shellOpenWithBundle(pathClaude, 'com.microsoft.vscodeinsiders'),
            menus = {
                { id = 'filesystemFiles', shortcut = 'c', order = 20 },
            },
            tags = fileTags,
        },
        {
            name = 'filesystem.files_karabiner_rules',
            description = 'Karabiner rules',
            action = shellOpenWithBundle(pathKarabinerRules, 'com.microsoft.vscodeinsiders'),
            menus = {
                { id = 'filesystemFiles', shortcut = 'k', order = 30 },
            },
            tags = fileTags,
        },
        {
            name = 'filesystem.files_leaderkey_shortcuts',
            description = 'Leaderkey shortcuts',
            action = shellOpenWithBundle(pathLeaderKey, 'com.microsoft.vscodeinsiders'),
            menus = {
                { id = 'filesystemFiles', shortcut = 'l', order = 40 },
            },
            tags = fileTags,
        },
        {
            name = 'filesystem.files_pdrs',
            description = 'PDRS',
            action = shellOpenWithBundle(pathPdrs, 'net.sourceforge.skim-app.skim'),
            menus = {
                { id = 'filesystemFiles', shortcut = 'p', order = 50 },
            },
            tags = fileTags,
        },
        {
            name = 'filesystem.files_sort_leaderkey',
            description = 'Sort leaderkey shortcuts',
            action = pythonCommand(pathSortLeaderKey, '--source clipboard --dest paste'),
            menus = {
                { id = 'filesystemFiles', shortcut = 's', order = 60 },
            },
            tags = fileTags,
        },
        {
            name = 'filesystem.files_zshrc',
            description = '.zshrc',
            action = shellOpenWithBundle('~/.zshrc', 'com.microsoft.vscodeinsiders'),
            menus = {
                { id = 'filesystemFiles', shortcut = '.', order = 70 },
            },
            tags = fileTags,
        },
    }

    local workspaces = {
        {
            name = 'filesystem.workspaces_karabiner',
            description = 'Karabiner workspace',
            action = shellOpenPath(pathKarabinerWorkspace),
            menus = {
                { id = 'filesystemWorkspaces', shortcut = 'k', order = 10 },
            },
            tags = workspaceTags,
        },
        {
            name = 'filesystem.workspaces_scripts',
            description = 'Scripts workspace',
            action = shellOpenPath(pathScriptsWorkspace),
            menus = {
                { id = 'filesystemWorkspaces', shortcut = 's', order = 20 },
            },
            tags = workspaceTags,
        },
        {
            name = 'filesystem.workspaces_ocr',
            description = 'OCR',
            action = Actions.open({ url = 'cleanshot://capture-text?linebreaks=false' }),
            menus = {
                { id = 'filesystemWorkspaces', shortcut = 'o', order = 30 },
            },
            tags = workspaceTags,
        },
        {
            name = 'filesystem.workspaces_privileges',
            description = 'Privileges',
            action = Actions.shell('/Applications/Privileges.app/Contents/MacOS/PrivilegesCLI -a'),
            menus = {
                { id = 'filesystemWorkspaces', shortcut = 'p', order = 40 },
            },
            tags = workspaceTags,
        },
        {
            name = 'filesystem.workspaces_recent_download',
            description = 'Recent download',
            action = Actions.open({ url = 'kmtrigger://macro=Open%20most%20recently%20downloaded%20file' }),
            menus = {
                { id = 'filesystemWorkspaces', shortcut = 'r', order = 50 },
            },
            tags = workspaceTags,
        },
        {
            name = 'filesystem.workspaces_eval_clipboard',
            description = 'Evaluate clipboard',
            action = Actions.shell('/opt/homebrew/bin/hs -c "FormatClip()"'),
            menus = {
                { id = 'filesystemWorkspaces', shortcut = '=', order = 60 },
            },
            tags = workspaceTags,
        },
    }

    local function copyList(list)
        local out = {}
        for index, value in ipairs(list or {}) do
            out[index] = value
        end
        return out
    end

    local function addFilesystemAction(spec)
        assert(spec.name and spec.action, 'filesystem action requires name and action')
        spec.menus = spec.menus or {}
        local perMenu = {}
        local inMenu = {}
        for _, menu in ipairs(spec.menus) do
            inMenu[#inMenu + 1] = menu.id
            perMenu[menu.id] = {
                description = menu.description or spec.description,
                defaultShortcut = menu.shortcut,
                fallbackShortcut = menu.fallbackShortcut,
                order = menu.order,
            }
        end
        assert(#inMenu > 0, string.format('filesystem action %s requires at least one menu', spec.name))
        actions[#actions + 1] = {
            name = spec.name,
            actions = { spec.action },
            menuDetails = {
                description = spec.description,
                defaultShortcut = spec.defaultShortcut or (spec.menus[1] and spec.menus[1].shortcut) or
                spec.fallbackShortcut,
                fallbackShortcut = spec.fallbackShortcut,
                inMenu = inMenu,
                perMenu = perMenu,
            },
            tags = copyList(spec.tags or {}),
        }
    end

    for _, spec in ipairs(directories) do
        addFilesystemAction(spec)
    end
    for _, spec in ipairs(files) do
        addFilesystemAction(spec)
    end
    for _, spec in ipairs(workspaces) do
        addFilesystemAction(spec)
    end
end

local function createTaggedAction(spec)
    assert(type(spec) == 'table', 'createTaggedAction: spec table required')
    assert(type(spec.name) == 'string' and spec.name ~= '', 'createTaggedAction: name required')
    assert(spec.action ~= nil, 'createTaggedAction: action required')
    assert(type(spec.description) == 'string' and spec.description ~= '', 'createTaggedAction: description required')
    local tags = cloneList(spec.tags or {})
    local perMenu
    if spec.menu then
        perMenu = {
            [spec.menu] = {
                description = spec.menuDescription or spec.description,
                defaultShortcut = spec.shortcut,
                order = spec.order,
            },
        }
    end
    actions[#actions + 1] = {
        name = spec.name,
        actions = { spec.action },
        menuDetails = {
            description = spec.description,
            defaultShortcut = spec.shortcut,
            perMenu = perMenu,
        },
        tags = tags,
        enabled = spec.enabled,
    }
end

do
    local function addGroup(config)
        local order = config.orderStart or 0
        local function nextOrder()
            order = order + (config.orderStep or 10)
            return order
        end
        for _, item in ipairs(config.items or {}) do
            local itemTags = cloneList(item.tags or {})
            if config.tag then
                itemTags[#itemTags + 1] = config.tag
            end
            createTaggedAction({
                name = item.name,
                description = item.description,
                shortcut = item.shortcut,
                action = item.action,
                tags = itemTags,
                menu = config.menu,
                menuDescription = item.menuDescription or config.menuDescription,
                order = item.order or nextOrder(),
                enabled = item.enabled,
            })
        end
    end

    local function quotePath(path)
        return string.format([[%q]], expand(path))
    end

    addGroup({
        tag = 'lk.default',
        menu = 'lkDefault',
        menuDescription = 'Default Tools',
        items = {
            {
                name = 'lk.default.evaluate_clipboard',
                description = 'Evaluate clipboard',
                shortcut = '=',
                action = Actions.shell('/opt/homebrew/bin/hs -c "formatClip()"'),
                tags = { 'clipboard', 'utilities' },
            },
            {
                name = 'lk.default.edit_clipboard_stringthing',
                description = 'Edit clipboard with StringThing',
                shortcut = 'O',
                action = Actions.shell(string.format('%s %s', quotePath('/opt/anaconda3/bin/python3'), quotePath('/Users/jason/Scripts/Text_Manipulation/text_processor/interfaces/hotkey_gui.py'))),
                tags = { 'clipboard', 'utilities' },
            },
            {
                name = 'lk.default.ocr_clipboard',
                description = 'OCR selection with CleanShot',
                shortcut = 'o',
                action = Actions.open({ url = 'cleanshot://capture-text?linebreaks=false' }),
                tags = { 'clipboard', 'utilities' },
            },
            {
                name = 'lk.default.toggle_privileges',
                description = 'Toggle Privileges',
                shortcut = 'p',
                action = shellCommandWithArgs('/Applications/Privileges.app/Contents/MacOS/privilegescli', '-a'),
                tags = { 'utilities' },
            },
            {
                name = 'lk.default.reopen_recent_download',
                description = 'Open most recent download',
                shortcut = 'r',
                action = Actions.open({ url = 'kmtrigger://macro=Open%20most%20recently%20downloaded%20file' }),
                tags = { 'utilities' },
            },
            {
                name = 'lk.default.redo_last_action',
                description = 'Redo last launcher action',
                shortcut = 'z',
                action = Actions.redoLast(),
                tags = { 'utilities', 'history' },
            },
        },
    })

    addGroup({
        tag = 'lk.rectangle',
        menu = 'lkRectangle',
        menuDescription = 'Rectangle Pro',
        items = {
            {
                name = 'lk.rectangle.toggle_pin_mode',
                description = 'Toggle pin mode',
                shortcut = 'P',
                action = Actions.open({ url = 'rectangle-pro://execute-action?name=pin' }),
                tags = { 'windows' },
            },
            {
                name = 'lk.rectangle.reflow_pinned_app',
                description = 'Reflow pinned app',
                shortcut = 'R',
                action = Actions.open({ url = 'rectangle-pro://execute-action?name=reflow-pin' }),
                tags = { 'windows' },
            },
        },
    })

    addGroup({
        tag = 'lk.misc',
        menu = 'lkMiscScripts',
        menuDescription = 'Miscellaneous Scripts',
        items = {
            {
                name = 'lk.misc.name_scan_in_merus',
                description = 'Name scan in Merus',
                shortcut = 'n',
                action = pythonCommand('~/Scripts/Application_Specific/Meruscase/jjk_Rename_MerusScans.py', '--source clipboard --dest paste'),
                tags = { 'clipboard', 'automation' },
            },
            {
                name = 'lk.misc.raycast_text_extension',
                description = 'Raycast text extension',
                shortcut = 'r',
                action = Actions.open({ url = 'raycast://extensions/koinzhang/text-shortcuts/shortcut-library' }),
                tags = { 'automation' },
            },
            {
                name = 'lk.misc.sort_leaderkey_config',
                description = 'Sort leaderkey shortcuts',
                shortcut = 's',
                action = pythonCommand('~/Scripts/Application_Specific/Leaderkey/jjk_SortLeaderkey/jjk_sort_leaderkey_config.py'),
                tags = { 'automation' },
            },
        },
    })

    addGroup({
        tag = 'lk.benefitRates',
        menu = 'lkBenefitRates',
        menuDescription = 'Benefit Rates',
        items = {
            {
                name = 'lk.benefit_rates.aww_from_ttd',
                description = 'AWW from TTD',
                shortcut = 'a',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'td_to_aww --source clipboard --dest paste'),
                tags = { 'clipboard', 'calculation' },
            },
            {
                name = 'lk.benefit_rates.ttd_from_aww',
                description = 'TTD from AWW',
                shortcut = 't',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'aww_to_td --source clipboard --dest paste'),
                tags = { 'clipboard', 'calculation' },
            },
        },
    })

    addGroup({
        tag = 'lk.caseChangers',
        menu = 'lkCaseChangers',
        menuDescription = 'Case Changers',
        items = {
            {
                name = 'lk.case_changers.lowercase',
                description = 'Lowercase clipboard text',
                shortcut = 'l',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'lowercase --source clipboard --dest paste'),
                tags = { 'clipboard', 'text' },
            },
            {
                name = 'lk.case_changers.sentence_case',
                description = 'Sentence case clipboard text',
                shortcut = 's',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'sentence_case --source clipboard --dest paste'),
                tags = { 'clipboard', 'text' },
            },
            {
                name = 'lk.case_changers.title_case',
                description = 'Title case clipboard text',
                shortcut = 't',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'title_case --source clipboard --dest paste'),
                tags = { 'clipboard', 'text' },
            },
            {
                name = 'lk.case_changers.uppercase',
                description = 'Uppercase clipboard text',
                shortcut = 'u',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'uppercase --source clipboard --dest paste'),
                tags = { 'clipboard', 'text' },
            },
        },
    })

    addGroup({
        tag = 'lk.dateScripts',
        menu = 'lkDateScripts',
        menuDescription = 'Date Scripts',
        items = {
            {
                name = 'lk.date_scripts.alpha',
                description = 'Alpha - MMMM D, YYYY',
                shortcut = 'a',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'date_alpha --source clipboard --dest paste'),
                tags = { 'clipboard', 'dates' },
            },
            {
                name = 'lk.date_scripts.diff',
                description = 'Date diff',
                shortcut = 'd',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'date_diff --source clipboard --dest paste'),
                tags = { 'clipboard', 'dates' },
            },
            {
                name = 'lk.date_scripts.file',
                description = 'File - YYYY.MM.DD',
                shortcut = 'f',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'date_file --source clipboard --dest paste'),
                tags = { 'clipboard', 'dates' },
            },
            {
                name = 'lk.date_scripts.iso',
                description = 'ISO - YYYY-MM-DD',
                shortcut = 'i',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'date_iso --source clipboard --dest paste'),
                tags = { 'clipboard', 'dates' },
            },
            {
                name = 'lk.date_scripts.long',
                description = 'Long - MM/DD/YYYY',
                shortcut = 'l',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'date_long --source clipboard --dest paste'),
                tags = { 'clipboard', 'dates' },
            },
            {
                name = 'lk.date_scripts.medium',
                description = 'Medium - M/D/YYYY',
                shortcut = 'm',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'date_medium --source clipboard --dest paste'),
                tags = { 'clipboard', 'dates' },
            },
            {
                name = 'lk.date_scripts.padded_medium',
                description = 'Padded medium - MM/DD/YYYY',
                shortcut = 'p',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'date_pad --source clipboard --dest paste'),
                tags = { 'clipboard', 'dates' },
            },
            {
                name = 'lk.date_scripts.relative',
                description = 'Relative date',
                shortcut = 'r',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'format_relative_date --source clipboard --dest paste'),
                tags = { 'clipboard', 'dates' },
            },
        },
    })

    addGroup({
        tag = 'lk.markdown',
        menu = 'lkMarkdown',
        menuDescription = 'Markdown Tools',
        items = {
            {
                name = 'lk.markdown.horizontal_rule',
                description = 'Markdown horizontal line',
                shortcut = 'H',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_horizontal_rule --source clipboard --dest paste'),
                tags = { 'markdown', 'clipboard' },
            },
            {
                name = 'lk.markdown.bold',
                description = 'Markdown bold',
                shortcut = 'b',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_bold --source clipboard --dest paste'),
                tags = { 'markdown', 'clipboard' },
            },
            {
                name = 'lk.markdown.italic',
                description = 'Markdown italics',
                shortcut = 'i',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_italic --source clipboard --dest paste'),
                tags = { 'markdown', 'clipboard' },
            },
            {
                name = 'lk.markdown.link',
                description = 'Markdown link',
                shortcut = 'l',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_link --source clipboard --dest paste'),
                tags = { 'markdown', 'clipboard' },
            },
            {
                name = 'lk.markdown.remove',
                description = 'Remove markdown',
                shortcut = 'r',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'remove_markdown --source clipboard --dest paste'),
                tags = { 'markdown', 'clipboard' },
            },
            {
                name = 'lk.markdown.strikethrough',
                description = 'Markdown strikethrough',
                shortcut = 's',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_strikethrough --source clipboard --dest paste'),
                tags = { 'markdown', 'clipboard' },
            },
            {
                name = 'lk.markdown.underline',
                description = 'Markdown underline',
                shortcut = 'u',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_underline --source clipboard --dest paste'),
                tags = { 'markdown', 'clipboard' },
            },
        },
    })

    addGroup({
        tag = 'lk.markdownLists',
        menu = 'lkMarkdownLists',
        menuDescription = 'Markdown Lists',
        items = {
            {
                name = 'lk.markdown_lists.ordered',
                description = 'Markdown ordered list',
                shortcut = 'o',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_ordered_list --source clipboard --dest paste'),
                tags = { 'markdown', 'clipboard' },
            },
            {
                name = 'lk.markdown_lists.unordered',
                description = 'Markdown unordered list',
                shortcut = 'u',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_unordered_list --source clipboard --dest paste'),
                tags = { 'markdown', 'clipboard' },
            },
        },
    })

    addGroup({
        tag = 'lk.markdownHeadings',
        menu = 'lkMarkdownHeadings',
        menuDescription = 'Markdown Headings',
        items = {
            {
                name = 'lk.markdown_headings.h1',
                description = 'Markdown heading level 1',
                shortcut = '1',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_heading --source clipboard --dest paste --level 1'),
                tags = { 'markdown', 'clipboard' },
            },
            {
                name = 'lk.markdown_headings.h2',
                description = 'Markdown heading level 2',
                shortcut = '2',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_heading --source clipboard --dest paste --level 2'),
                tags = { 'markdown', 'clipboard' },
            },
            {
                name = 'lk.markdown_headings.h3',
                description = 'Markdown heading level 3',
                shortcut = '3',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'markdown_heading --source clipboard --dest paste --level 3'),
                tags = { 'markdown', 'clipboard' },
            },
        },
    })

    addGroup({
        tag = 'lk.screenshots',
        menu = 'lkScreenshots',
        menuDescription = 'Screenshots',
        items = {
            {
                name = 'lk.screenshots.copy',
                description = 'CleanShot copy to clipboard',
                shortcut = 'C',
                action = Actions.open({ url = 'cleanshot://capture-area' }),
                tags = { 'screenshots' },
            },
            {
                name = 'lk.screenshots.annotate',
                description = 'CleanShot annotate capture',
                shortcut = 'a',
                action = Actions.open({ url = 'cleanshot://capture-area?action=annotate' }),
                tags = { 'screenshots' },
            },
            {
                name = 'lk.screenshots.ocr',
                description = 'CleanShot OCR',
                shortcut = 'c',
                action = Actions.open({ url = 'cleanshot://capture-text?linebreaks=false' }),
                tags = { 'screenshots', 'clipboard' },
            },
            {
                name = 'lk.screenshots.pin',
                description = 'CleanShot pin capture',
                shortcut = 'p',
                action = Actions.open({ url = 'cleanshot://capture-area?action=pin' }),
                tags = { 'screenshots' },
            },
            {
                name = 'lk.screenshots.save',
                description = 'CleanShot save capture',
                shortcut = 's',
                action = Actions.open({ url = 'cleanshot://capture-area?action=save' }),
                tags = { 'screenshots' },
            },
        },
    })

    addGroup({
        tag = 'lk.wrappers',
        menu = 'lkWrappers',
        menuDescription = 'Wrappers by Py',
        items = {
            {
                name = 'lk.wrappers.wrap_single_quotes',
                description = 'Wrap with single quotes',
                shortcut = "'",
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'wrap_single_quotes --source clipboard --dest paste'),
                tags = { 'clipboard', 'text' },
            },
            {
                name = 'lk.wrappers.wrap_parentheses',
                description = 'Wrap with parentheses',
                shortcut = '9',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'wrap_parentheses --source clipboard --dest paste'),
                tags = { 'clipboard', 'text' },
            },
            {
                name = 'lk.wrappers.wrap_brackets',
                description = 'Wrap with brackets',
                shortcut = 'b',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'wrap_brackets --source clipboard --dest paste'),
                tags = { 'clipboard', 'text' },
            },
            {
                name = 'lk.wrappers.wrap_curly_braces',
                description = 'Wrap with curly braces',
                shortcut = 'c',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'wrap_curly_braces --source clipboard --dest paste'),
                tags = { 'clipboard', 'text' },
            },
            {
                name = 'lk.wrappers.wrap_quotes',
                description = 'Wrap with double quotes',
                shortcut = 'q',
                action = pythonCommand('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py', 'wrap_quotes --source clipboard --dest paste'),
                tags = { 'clipboard', 'text' },
            },
        },
    })
end

actions[#actions + 1] = {
    name = 'window_management.enter_mode',
    exitAfter = false,
    actions = {
        Actions.enterMode('window'),
    },
    menuDetails = {
        description = 'Enter window management mode',
        inMenu = { 'globalRoot', 'leaderWindow' },
        defaultShortcut = 'w',
        perMenu = {
            leaderWindow = {
                description = 'Window Management Mode',
                defaultShortcut = 'w',
            },
        },
    },
    tags = { 'modules', 'leader' },
}

actions[#actions + 1] = {
    name = 'hotkey_management.enter_mode',
    exitAfter = false,
    actions = {
        Actions.enterMode('hotkeys'),
    },
    menuDetails = {
        description = 'Enter hotkey management mode',
        inMenu = { 'globalRoot', 'leaderHotkeys' },
        defaultShortcut = 'h',
        perMenu = {
            leaderHotkeys = {
                description = 'Hotkey Management Mode',
                defaultShortcut = 'h',
            },
        },
    },
    tags = { 'modules', 'leader' },
}

actions[#actions + 1] = {
    name = 'shortcuts.enter_mode',
    exitAfter = false,
    actions = {
        Actions.enterMode('shortcuts'),
    },
    menuDetails = {
        description = 'Enter shortcuts mode',
        inMenu = { 'globalRoot', 'leaderShortcuts' },
        defaultShortcut = 's',
        perMenu = {
            leaderShortcuts = {
                description = 'Shortcuts Mode',
                defaultShortcut = 's',
            },
        },
    },
    tags = { 'modules', 'leader' },
}

actions[#actions + 1] = {
    name = 'quicksearch.open_or_search_selection',
    actions = {
        Actions.noop(),
    },
    menuDetails = {
        description = 'Open clipboard target or search',
        inMenu = { 'leaderShortcuts' },
        defaultShortcut = 'o',
    },
    tags = { 'utilities' },
}

return actions

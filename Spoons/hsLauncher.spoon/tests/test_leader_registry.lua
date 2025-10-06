---@diagnostic disable: duplicate-set-field
-- tests/test_leader_registry.lua

local scriptPath = debug.getinfo(1, 'S').source:sub(2)
if scriptPath:sub(1, 1) ~= '/' then
  local cwd = assert(io.popen('pwd'):read('*l'), 'Unable to determine working directory')
  scriptPath = cwd .. '/' .. scriptPath
end
local testDir = scriptPath:match('(.*/)')
assert(testDir, 'Unable to determine test directory from ' .. tostring(scriptPath))
local projectRoot = testDir:gsub('/tests/?$', '/')
local parentRoot = projectRoot:gsub('/[^/]+/?$', '/')

package.path = table.concat({
  projectRoot .. '?.lua',
  projectRoot .. '?/init.lua',
  projectRoot .. 'main/?.lua',
  projectRoot .. 'main/?/init.lua',
  parentRoot .. '?.lua',
  parentRoot .. '?/init.lua',
  parentRoot .. 'main/?.lua',
  parentRoot .. 'main/?/init.lua',
  package.path,
}, ';')

  local function registerHsLauncherLoader(root)
    table.insert(package.searchers, 2, function(moduleName)
    local relative = moduleName:match('^hsLauncher%.(.+)$')
    if not relative then return nil end
    local base = root .. relative:gsub('%.', '/')
    local attempts = {}
    local function try(path)
      local chunk, err = loadfile(path)
      if chunk then return chunk end
      attempts[#attempts + 1] = err or ('no file ' .. path)
      return nil
    end
    local chunk = try(base .. '.lua') or try(base .. '/init.lua')
    if chunk then return chunk end
    return nil, table.concat(attempts, '\n')
  end)
  package.__hslauncher_loader = true
end

registerHsLauncherLoader(projectRoot)

if not package.preload['hs.fs'] then
  package.preload['hs.fs'] = function()
    return {
      attributes = function()
        return nil
      end,
      mkdir = function()
        return true
      end,
      touch = function()
        return true
      end,
      pathToAbsolute = function(path)
        return path
      end,
      dir = function()
        return function()
          return nil
        end
      end,
    }
  end
end

require('tests.fixtures.legacy_user_actions').install()

if not _G.hs then _G.hs = {} end
hs.execute = hs.execute or function()
  return true
end

package.preload['hs.pasteboard'] = package.preload['hs.pasteboard'] or function()
  return {
    getContents = function() return '' end,
    writeObjects = function() end,
  }
end

package.preload['hs.application'] = package.preload['hs.application'] or function()
  local frontmost = {
    name = function() return 'Finder' end,
    bundleID = function() return 'com.apple.finder' end,
  }
  return {
    get = function() return frontmost end,
    frontmostApplication = function() return frontmost end,
  }
end

package.preload['hs.urlevent'] = package.preload['hs.urlevent'] or function()
  return {
    openURLWithBundle = function()
      return false
    end,
  }
end

package.preload['hs.eventtap'] = package.preload['hs.eventtap'] or function()
  return {
    checkKeyboardModifiers = function()
      return {}
    end,
    keyStroke = function() end,
  }
end
local definedModes = {}
local registeredSequences = {}

---@diagnostic disable: duplicate-set-field
-- tests/test_leader_registry.lua
package.preload['hs.json'] = function()
  return {
    encode = function() return '{}' end,
    decode = function() return nil, 'not implemented' end,
  }
end

package.preload['hsLauncher.main.core.logger'] = function()
  return {
    info = function() end,
    error = function() end,
    warn = function() end,
  }
end

package.preload['hsLauncher.main.core.action_runner'] = function()
  return {
    exec = function() end,
  }
end

package.preload['hsLauncher.main.core.windows_native'] = function()
  return {}
end

package.preload['hsLauncher.main.modules.hotkeys.assign_global'] = function()
  return {
    assignForFrontmost = function() end,
    removeForFrontmost = function() end,
    listForFrontmost = function() return {} end,
  }
end

package.preload['hsLauncher.main.modules.hotkeys.assign_hotkey'] = function()
  return { assign = function() end }
end

package.preload['hsLauncher.main.core.hyper_modal'] = function()
  return {
    defineMode = function(name, spec)
      definedModes[name] = spec
    end,
    addSequence = function(keys, _)
      table.insert(registeredSequences, table.concat(keys, '+'))
    end,
    enterMode = function() end,
    bind = function() end,
  }
end

package.preload['hsLauncher.main.core.window_history'] = function() return {} end
package.preload['hsLauncher.main.core.window_geometry'] = function() return {} end
package.preload['hsLauncher.main.core.window_neighbors'] = function() return {} end
package.preload['hsLauncher.main.core.modal_gui'] = function() return { show = function() end, hide = function() end } end
package.preload['hsLauncher.main.core.config'] = function() return {} end

local Registry = require('hsLauncher.main.user.registry')
local leaderConfig = require('hsLauncher.main.core.leader_config')

local function assertTrue(condition, message)
  if not condition then error(message or 'Assertion failed') end
end

local function assertEquals(actual, expected, message)
  if actual ~= expected then
    error(string.format('%s\nexpected: %s\nactual: %s', message or 'Assertion failed', tostring(expected), tostring(actual)))
  end
end

local state = Registry.load({ featureFlags = { menuBuilder = true } })
assertTrue(state.actions['applications.brave'] ~= nil, 'expected applications.brave action to load')

assertTrue(state.features.menuBuilder == true, 'menu builder feature flag should be enabled for declarative path')
assertTrue(state.diagnostics.combined ~= nil, 'combined diagnostics should be available')

local spec = Registry.resolveAction('applications.brave')
assertTrue(spec ~= nil, 'expected to resolve applications.brave')
assertEquals(spec.kind, 'exec', 'applications.brave should be exec action')
assertEquals(spec.spec.type, 'open', 'applications.brave should open application')

local config = Registry.buildLeaderConfig()
assertTrue(type(config.actions) == 'table' and #config.actions > 0, 'leader config should contain actions')
local hasModuleGroup = false
local hasShortcut = false
local windowAction = nil
local hotkeyAction = nil
local shortcutsAction = nil
for _, entry in ipairs(config.actions) do
  if entry.type == 'group' then hasModuleGroup = true end
  if entry.section == 'Shortcuts' then hasShortcut = true end
  if entry.actionId == 'window_management.enter_mode' then windowAction = entry end
  if entry.actionId == 'hotkey_management.enter_mode' then hotkeyAction = entry end
  if entry.actionId == 'shortcuts.enter_mode' then shortcutsAction = entry end
end
assertTrue(hasModuleGroup, 'leader config should expose module directory groups')
assertTrue(hasShortcut, 'leader config should expose shortcuts at root')
assertTrue(windowAction ~= nil, 'window management action should be exposed at root')
if not windowAction then error('window management enter mode action missing from root') end
assertEquals(windowAction.exitAfter, false, 'window management enter mode should stay active')
assertEquals(windowAction.key, 'w', 'window management action should use key w')
assertTrue(hotkeyAction ~= nil, 'hotkey management action should be exposed at root')
if not hotkeyAction then error('hotkey management enter mode action missing from root') end
assertEquals(hotkeyAction.exitAfter, false, 'hotkey management enter mode should stay active')
assertEquals(hotkeyAction.key, 'h', 'hotkey management action should use key h')
assertTrue(shortcutsAction ~= nil, 'shortcuts mode action should be exposed at root')
if not shortcutsAction then error('shortcuts enter mode action missing from root') end
assertEquals(shortcutsAction.exitAfter, false, 'shortcuts enter mode should stay active')
assertEquals(shortcutsAction.key, 's', 'shortcuts enter mode should use key s')

local sequences = leaderConfig.registerFromModules()
assertTrue(type(sequences) == 'table', 'expected registerFromModules to return sequence info')
assertEquals(definedModes['leader.root'] ~= nil, true, 'leader root mode should be defined')
assertEquals(registeredSequences[1], 'space', 'root sequence should be space')

print('[PASS] Leader registry builds config and registers modes')

local legacyState = Registry.load({
  featureFlags = { menuBuilder = false },
  menus = {
    'hotkey_management',
    'shortcuts',
    'text_tools',
    'window_management',
  },
})
assertTrue(legacyState.features.menuBuilder == false, 'legacy load should disable menu builder')
local legacyConfig = Registry.buildLeaderConfig()
assertTrue(type(legacyConfig.actions) == 'table', 'legacy leader config should return actions table')
assertTrue(#legacyConfig.actions > 0, 'legacy leader config should include entries from userActions')

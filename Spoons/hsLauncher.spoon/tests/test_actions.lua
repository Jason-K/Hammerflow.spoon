-- tests/test_actions.lua

local scriptPath = debug.getinfo(1, "S").source:sub(2)
if scriptPath:sub(1, 1) ~= '/' then
  local cwd = assert(io.popen('pwd'):read('*l'), 'Unable to determine working directory')
  scriptPath = cwd .. '/' .. scriptPath
end
local testDir = scriptPath:match("(.*/)")
assert(testDir, "Unable to determine test directory from " .. tostring(scriptPath))
local projectRoot = testDir:gsub("/tests/?$", "/")
local parentRoot = projectRoot:gsub("/[^/]+/?$", "/")

package.path = table.concat({
  projectRoot .. "?.lua",
  projectRoot .. "?/init.lua",
  projectRoot .. "main/?.lua",
  projectRoot .. "main/?/init.lua",
  parentRoot .. "?.lua",
  parentRoot .. "?/init.lua",
  parentRoot .. "main/?.lua",
  parentRoot .. "main/?/init.lua",
  package.path,
}, ';')

local function registerHsLauncherLoader(root)
  if package.__hslauncher_loader then return end
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
    }
  end
end

-- Test doubles --------------------------------------------------------------

local execCalls = {}
local windowCalls = {}
local assignHotkeyCalls = 0
local assignGlobalCalls = { assign = 0, remove = 0, list = 0 }

local function resetState()
  execCalls = {}
  windowCalls = {}
  assignHotkeyCalls = 0
  assignGlobalCalls = { assign = 0, remove = 0, list = 0 }
end

package.preload['hsLauncher.main.core.logger'] = function()
  return {
    info = function() end,
    error = function() end,
  }
end

package.preload['hsLauncher.main.core.action_runner'] = function()
  return {
    exec = function(spec)
      table.insert(execCalls, spec)
    end,
  }
end

package.preload['hsLauncher.main.core.windows_native'] = function()
  return setmetatable({}, {
    __index = function(_, key)
      return function()
        windowCalls[key] = (windowCalls[key] or 0) + 1
      end
    end,
  })
end

package.preload['hsLauncher.main.modules.hotkeys.assign_hotkey'] = function()
  return {
    assign = function()
      assignHotkeyCalls = assignHotkeyCalls + 1
    end,
  }
end

package.preload['hsLauncher.main.modules.hotkeys.assign_global'] = function()
  return {
    assignForFrontmost = function()
      assignGlobalCalls.assign = assignGlobalCalls.assign + 1
    end,
    removeForFrontmost = function()
      assignGlobalCalls.remove = assignGlobalCalls.remove + 1
    end,
    listForFrontmost = function()
      assignGlobalCalls.list = assignGlobalCalls.list + 1
      return { 'example' }
    end,
  }
end
package.preload['hsLauncher.main.core.hyper_modal'] = function()
  return { exitMode = function() end }
end
package.preload['hsLauncher.main.core.window_history'] = function()
  return {}
end
package.preload['hsLauncher.main.core.window_geometry'] = function()
  return {}
end
package.preload['hsLauncher.main.core.window_neighbors'] = function()
  return {}
end
package.preload['hsLauncher.main.core.modal_gui'] = function()
  return { show = function() end, hide = function() end }
end
package.preload['hsLauncher.main.core.config'] = function()
  return {}
end

-- Under test ----------------------------------------------------------------

local Actions = require('hsLauncher.main.core.actions')

-- Lightweight harness -------------------------------------------------------

local testCases = {}

local function addTest(name, fn)
  table.insert(testCases, { name = name, fn = fn })
end

local function assertEquals(actual, expected, message)
  if actual ~= expected then
    error((message or "assertEquals failed") .. string.format("\nexpected: %s\nactual: %s", tostring(expected), tostring(actual)))
  end
end

local function assertTableContains(tbl, index, message)
  if tbl[index] == nil then
    error((message or "expected table value") .. string.format("\nmissing index: %s", tostring(index)))
  end
end

addTest('Actions.keystroke builds exec spec', function()
  resetState()
  local action = Actions.keystroke('x', { 'cmd' })
  assertEquals(action.kind, 'exec')
  assertEquals(action.spec.type, 'keystroke')
  assertEquals(action.spec.key, 'x')
  assertEquals(action.spec.mods[1], 'cmd')
end)

addTest('Actions.resolve executes keystroke spec', function()
  resetState()
  local fn = Actions.resolve(Actions.keystroke('k', { 'alt' }))
  assert(fn, 'Expected resolver to return function')
  fn()
  assertEquals(#execCalls, 1)
  assertEquals(execCalls[1].type, 'keystroke')
  assertEquals(execCalls[1].key, 'k')
end)

addTest('Actions.open wraps launch spec', function()
  resetState()
  local action = Actions.open({ bundle_id = 'com.test.App' })
  assertEquals(action.spec.type, 'open')
  assertEquals(action.spec.target.bundle_id, 'com.test.App')
end)

addTest('Actions.sequence dispatches all steps', function()
  resetState()
  local sequence = Actions.sequence({
    Actions.keystroke('a'),
    Actions.keystroke('b'),
  })
  local fn = Actions.resolve(sequence)
  assert(fn, 'Expected sequence to resolve')
  fn()
  assertEquals(#execCalls, 2)
  assertEquals(execCalls[1].key, 'a')
  assertEquals(execCalls[2].key, 'b')
end)

addTest('Actions.sequenceExec lifts raw specs', function()
  resetState()
  local sequence = Actions.sequenceExec({
    { type = 'keystroke', key = 'c' },
    { type = 'keystroke', key = 'd' },
  })
  local fn = Actions.resolve(sequence)
  assert(fn, 'Expected sequenceExec to resolve')
  fn()
  assertEquals(#execCalls, 2)
  assertEquals(execCalls[1].key, 'c')
  assertEquals(execCalls[2].key, 'd')
end)

addTest('Actions.window resolves module function', function()
  resetState()
  local fn = Actions.resolve(Actions.window('left'))
  assert(fn, 'Expected window action to resolve')
  fn()
  assertTableContains(windowCalls, 'left')
  assertEquals(windowCalls.left, 1)
end)

addTest('Actions.assign helpers call modules', function()
  resetState()
  local assignHotkeyFn = Actions.resolve(Actions.assignHotkey())
  local assignGlobalFn = Actions.resolve(Actions.assignGlobal())
  local removeGlobalFn = Actions.resolve(Actions.removeGlobal())
  local listGlobalFn = Actions.resolve(Actions.listGlobals())
  assert(assignHotkeyFn and assignGlobalFn and removeGlobalFn and listGlobalFn, 'Expected assign helpers to resolve')
  assignHotkeyFn()
  assignGlobalFn()
  removeGlobalFn()
  listGlobalFn()
  assertEquals(assignHotkeyCalls, 1)
  assertEquals(assignGlobalCalls.assign, 1)
  assertEquals(assignGlobalCalls.remove, 1)
  assertEquals(assignGlobalCalls.list, 1)
end)

addTest('Actions.hsFunction builds spec', function()
  resetState()
  local action = Actions.hsFunction('sleep', { 0.1 })
  assertEquals(action.spec.type, 'hs_function')
  assertEquals(action.spec.name, 'sleep')
  assertEquals(action.spec.args[1], 0.1)
end)

addTest('Actions.shell and applescript utilities', function()
  resetState()
  local shell = Actions.shell('echo hello')
  local script = Actions.applescript('/tmp/test.scpt')
  assertEquals(shell.spec.cmd, 'echo hello')
  assertEquals(script.spec.script_path, '/tmp/test.scpt')
end)

-- Runner --------------------------------------------------------------------

local failures = 0
for _, test in ipairs(testCases) do
  local ok, err = pcall(test.fn)
  if ok then
    io.stdout:write(string.format('[PASS] %s\n', test.name))
  else
    failures = failures + 1
    io.stderr:write(string.format('[FAIL] %s\n%s\n', test.name, err))
  end
end

if failures > 0 then
  io.stderr:write(string.format('\n%d test(s) failed.\n', failures))
  os.exit(1)
else
  io.stdout:write(string.format('\nAll %d test(s) passed.\n', #testCases))
end

-- hsLauncher/core/action_runner.lua
-- Executes action specs: keystroke, sequence, open targets, shell commands, AppleScript, and Hammerspoon helpers.

local M = {}
local log = require('hsLauncher.main.core.logger')
local Mods = require('hsLauncher.main.core.mods')
local ev = require('hs.eventtap').event

local function normMods(mods)
	return Mods.normalizeMods(mods) or {}
end

local function pressCombo(mods, key)
	local order = { ctrl = 1, alt = 2, shift = 3, cmd = 4 }
	local norm = normMods(mods)
	table.sort(norm, function (a, b) return (order[a] or 9) < (order[b] or 9) end)
	local function modDown(m) ev.newKeyEvent(m, true):post() end
	local function modUp(m) ev.newKeyEvent(m, false):post() end
	for _, m in ipairs(norm) do
		modDown(m); hs.timer.usleep(15000)
	end
	ev.newKeyEvent(norm, key, true):post(); hs.timer.usleep(20000)
	ev.newKeyEvent(norm, key, false):post(); hs.timer.usleep(15000)
	for i = #norm, 1, -1 do
		modUp(norm[i]); hs.timer.usleep(12000)
	end
end

local function sleep(sec)
	hs.timer.usleep(math.floor((sec or 0) * 1000000))
end

local function missionControl()
	hs.eventtap.keyStroke({ 'ctrl' }, 'up', 0)
end

local function quitActiveApp()
	local app = hs.application.frontmostApplication()
	if app then
		--- @diagnostic disable-next-line: undefined-field
		app:kill()
	end
end

local function runAppleScript(path)
	local cmd = string.format([[osascript %q]], path)
	local ok, out, _, rc = hs.execute(cmd, true)
	if not ok or rc ~= 0 then log.error('AppleScript failed: ' .. tostring(out)) end
end

local function openTarget(t)
	if not t then return end
	if t.bundle_id then
		hs.application.launchOrFocusByBundleID(t.bundle_id); return
	end
	if t.app_name then
		hs.application.launchOrFocus(t.app_name); return
	end
	if t.path then
		hs.execute(string.format('open -a %q', t.path), true); return
	end
	if t.url then
		hs.urlevent.openURL(t.url); return
	end
end

function M.exec(action)
	if not action or not action.type then return end
	local t = action.type
	if t == 'keystroke' then
		pressCombo(action.mods or {}, action.key)
	elseif t == 'keyDown' then
		ev.newKeyEvent(action.key, true):post()
	elseif t == 'keyUp' then
		ev.newKeyEvent(action.key, false):post()
	elseif t == 'sequence' then
		for _, step in ipairs(action.steps or {}) do M.exec(step) end
	elseif t == 'open' then
		openTarget(action.target)
	elseif t == 'shell' then
		hs.execute(action.cmd, true)
	elseif t == 'applescript' then
		runAppleScript(action.script_path)
	elseif t == 'hs_function' then
		local name = action.name
		if name == 'sleep' then
			sleep(tonumber((action.args or {})[1]) or 0)
		elseif name == 'missionControl' then
			missionControl()
		elseif name == 'quitActiveApp' then
			quitActiveApp()
		end
	end
end

M.pressCombo = pressCombo
M.sleep = sleep
M.missionControl = missionControl
M.quitActiveApp = quitActiveApp

return M

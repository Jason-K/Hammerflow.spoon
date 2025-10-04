-- hsLauncher/core/sequence_runner.lua
-- SequenceRunner: run JSON/base64-JSON sequences of steps
-- Steps: {type='keystroke'| 'keydown'|'keyup'|'pause'|'shell', key='a', mods={'cmd','alt'}, ms=120, cmd='...'}
local logger = require('hsLauncher.main.core.logger')
local json = require('hs.json')
local eventtap = require('hs.eventtap')
local keycodes = require('hs.keycodes')
local timer = require('hs.timer')

local M = {}

local function keyFromString(k)
	-- Accept names like 'a', 'tab', 'left', 'keypad,' etc.
	return keycodes.map[k] and k or k
end

local function modsFromTable(t)
	if type(t) ~= 'table' then return {} end
	local out = {}
	for _, m in ipairs(t) do out[#out + 1] = m end
	return out
end

local function sendKeystroke(key, mods)
	eventtap.keyStroke(modsFromTable(mods), keyFromString(key), 0)
end

local function sendKeydown(key, mods)
	eventtap.event.newKeyEvent(modsFromTable(mods), keyFromString(key), true):post()
end

local function sendKeyup(key, mods)
	eventtap.event.newKeyEvent(modsFromTable(mods), keyFromString(key), false):post()
end

function M.runSequence(steps)
	logger.info('Sequence start (' .. tostring(#steps) .. ' steps)')
	local i = 1
	local function stepper()
		if i > #steps then
			logger.info('Sequence end')
			return
		end
		local s = steps[i]
		i = i + 1
		local t = s.type
		if t == 'keystroke' then
			sendKeystroke(s.key, s.mods)
			timer.doAfter((s.ms or 0) / 1000, stepper)
		elseif t == 'keydown' then
			sendKeydown(s.key, s.mods)
			timer.doAfter((s.ms or 0) / 1000, stepper)
		elseif t == 'keyup' then
			sendKeyup(s.key, s.mods)
			timer.doAfter((s.ms or 0) / 1000, stepper)
		elseif t == 'pause' then
			timer.doAfter((s.ms or 0) / 1000, stepper)
		elseif t == 'shell' then
			local ok, _, _, rc = hs.execute(s.cmd or '', true)
			if not ok or rc ~= 0 then
				logger.error('Shell step failed: ' .. tostring(s.cmd) .. ' rc=' .. tostring(rc))
			end
			timer.doAfter((s.ms or 0) / 1000, stepper)
		else
			logger.error('Unknown step type: ' .. tostring(t))
			timer.doAfter(0, stepper)
		end
	end
	stepper()
end

function M.runSequenceB64(b64)
	local ok, decoded = pcall(hs.base64.decode, b64)
	if not ok then
		logger.error('Invalid base64 sequence')
		return false
	end
	local t = json.decode(decoded)
	if type(t) ~= 'table' then
		logger.error('Decoded sequence is not a table')
		return false
	end
	M.runSequence(t)
	return true
end

return M

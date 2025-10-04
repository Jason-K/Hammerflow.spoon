-- hsLauncher/core/input_engine.lua
-- Event engine for tap/hold/alone/double-tap, chords, and sequences with configurable thresholds.

local M = {}
local log = require('hsLauncher.main.core.logger')
local eventtap = require('hs.eventtap')
local keycodes = require('hs.keycodes')

local DEBUG = true
local function nameFor(code) return (keycodes.map[code] or tostring(code)) end
local function dbg(msg) if DEBUG then log.info('input_engine: ' .. msg) end end

local DEFAULTS = { tap_ms = 230, hold_ms = 300, double_ms = 320 }

local state = {
	down = {},
	lastUp = {},
	seq = {},
}

local handlers = {
	tap = {},
	hold = {},
	double = {},
	chord = {},
	seq = {},
	down = {},
	up = {},
}

local wildcardKey = '*'

local function now() return hs.timer.secondsSinceEpoch() end

local function codeFor(name)
	for k, v in pairs(keycodes.map) do
		if type(k) == 'number' and v == name then return k end
	end
	return keycodes.map[name]
end

local function modsActive(ev)
	local f = ev:getFlags()
	local mods = {}
	for k, v in pairs(f) do
		if v then
			table.insert(mods, k)
			mods[k] = true
		end
	end
	table.sort(mods)
	return mods
end

local function resolveHandlerBucket(container, key)
	local targetKey = key or wildcardKey
	if targetKey == wildcardKey then
		container[wildcardKey] = container[wildcardKey] or {}
		return container[wildcardKey]
	end
	local code = codeFor(targetKey)
	if not code then
		log.warn('input_engine: unknown key for handler registration: ' .. tostring(targetKey))
		return nil
	end
	container[code] = container[code] or {}
	return container[code], code
end

local function fireKeyHandlers(list, ev, meta)
	if not list then return false end
	local consumed = false
	for _, fn in ipairs(list) do
		local ok, ret = pcall(fn, ev, meta)
		if not ok then
			log.error('input_engine handler failed: ' .. tostring(ret))
		else
			if ret == true or (type(ret) == 'table' and ret.consume) then
				consumed = true
			end
			if type(ret) == 'table' and ret.stop then
				break
			end
		end
	end
	return consumed
end

function M.setThresholds(t)
	M.tap_ms = t.tap_ms or DEFAULTS.tap_ms
	M.hold_ms = t.hold_ms or DEFAULTS.hold_ms
	M.double_ms = t.double_ms or DEFAULTS.double_ms
end

local function fire(list, ...)
	if not list then return false end
	local consumed = false
	for _, fn in ipairs(list) do
		local ok, ret = pcall(fn, ...)
		if ok and ret == true then consumed = true end
	end
	return consumed
end

function M.onTap(key, requiredMods, alone, fn)
	local code = codeFor(key)
	if not code then
		log.warn('input_engine: unknown key for onTap: ' .. tostring(key)); return
	end
	handlers.tap[code] = handlers.tap[code] or {}
	table.insert(handlers.tap[code], function (ev)
		local mods = modsActive(ev)
		if requiredMods then
			for _, m in ipairs(requiredMods) do if not ev:getFlags()[m] then return false end end
		end
		if alone and next(mods) then return false end
		return fn(ev) or false
	end)
end

function M.onHold(key, requiredMods, alone, fn)
	local code = codeFor(key)
	if not code then
		log.warn('input_engine: unknown key for onHold: ' .. tostring(key)); return
	end
	handlers.hold[code] = handlers.hold[code] or {}
	table.insert(handlers.hold[code], function (ev) return fn(ev) or false end)
end

function M.onDoubleTap(key, requiredMods, alone, fn)
	local code = codeFor(key)
	if not code then
		log.warn('input_engine: unknown key for onDoubleTap: ' .. tostring(key)); return
	end
	handlers.double[code] = handlers.double[code] or {}
	table.insert(handlers.double[code], function (ev) return fn(ev) or false end)
end

function M.onChord(mods, key, fn)
	local code = codeFor(key)
	if not code then
		log.warn('input_engine: unknown key for onChord: ' .. tostring(key)); return
	end
	local sig = table.concat(mods or {}, '+') .. '+' .. tostring(code)
	handlers.chord[sig] = handlers.chord[sig] or {}
	table.insert(handlers.chord[sig], fn)
end

function M.onSequence(seqKeys, within_ms, fn)
	handlers.seq[#handlers.seq + 1] = { seq = seqKeys, within = within_ms, fn = fn }
end

function M.onKeyDown(key, fn)
	if type(fn) ~= 'function' then return end
	local bucket = resolveHandlerBucket(handlers.down, key)
	if bucket then table.insert(bucket, fn) end
end

function M.onKeyUp(key, fn)
	if type(fn) ~= 'function' then return end
	local bucket = resolveHandlerBucket(handlers.up, key)
	if bucket then table.insert(bucket, fn) end
end

function M.onAnyKey(fn)
	M.onKeyDown(nil, fn)
	M.onKeyUp(nil, fn)
end

local tapper
function M.start()
	if tapper then return end
	local ok, cfg = pcall(require, 'hsLauncher.main.core.config')
	if ok and type(cfg) == 'table' and cfg.debugInputEngine ~= nil then DEBUG = cfg.debugInputEngine end
	tapper = eventtap.new({ eventtap.event.types.keyDown, eventtap.event.types.keyUp }, function (ev)
		local code = ev:getKeyCode()
		local typ = ev:getType()
		local isBackspace = (code == keycodes.map.delete)
		local isArrowKey = (code == keycodes.map.left or code == keycodes.map.right or code == keycodes.map.up or code == keycodes.map.down)

		if typ == eventtap.event.types.keyDown then
			local isRepeat = ev:getProperty(eventtap.event.properties.keyboardEventAutorepeat) == 1
			local mods = modsActive(ev)
			local meta = {
				phase = 'down',
				code = code,
				name = nameFor(code),
				mods = mods,
				isRepeat = isRepeat,
				alone = (next(mods) == nil),
			}

			if isRepeat then
				local consumed = fireKeyHandlers(handlers.down[wildcardKey], ev, meta)
				consumed = fireKeyHandlers(handlers.down[code], ev, meta) or consumed
				if consumed then return true end
				return not (isBackspace or isArrowKey)
			end

			local sig = table.concat(mods, '+') .. '+' .. tostring(code)
			local tracked = false
			if handlers.tap[code] or handlers.hold[code] or handlers.chord[sig] then
				state.down[code] = { t = now(), alone = meta.alone }
				dbg('down ' .. nameFor(code))
				tracked = true
			end

			local consumed = fireKeyHandlers(handlers.down[wildcardKey], ev, meta)
			consumed = fireKeyHandlers(handlers.down[code], ev, meta) or consumed

			if tracked then
				return true
			end
			return consumed
		else
			local d = state.down[code]
			local mods = modsActive(ev)
			local meta = {
				phase = 'up',
				code = code,
				name = nameFor(code),
				mods = mods,
				isRepeat = false,
				alone = (next(mods) == nil),
			}

			local consumed = false
			if d then
				state.down[code] = nil
				local dt = (now() - d.t) * 1000
				meta.duration = dt
				meta.alone = d.alone
				local last = state.lastUp[code]
				state.lastUp[code] = now()
				if last and ((now() - last) * 1000 <= (M.double_ms or DEFAULTS.double_ms)) then
					local before = consumed
					consumed = fire(handlers.double[code], ev) or consumed
					if consumed and not before then dbg('double ' .. nameFor(code)) end
				end
				if dt <= (M.tap_ms or DEFAULTS.tap_ms) then
					local before = consumed
					consumed = fire(handlers.tap[code], ev) or consumed
					if consumed and not before then dbg('tap ' ..
						nameFor(code) .. ' dt=' .. string.format('%.0f', dt) .. 'ms') end
					if not consumed then
						if tapper then tapper:stop() end
						eventtap.keyStroke(ev:getFlags(), nameFor(code), 1000)
						if tapper then tapper:start() end
						consumed = true
					end
				elseif dt >= (M.hold_ms or DEFAULTS.hold_ms) then
					local before = consumed
					consumed = fire(handlers.hold[code], ev) or consumed
					if consumed and not before then dbg('hold ' ..
						nameFor(code) .. ' dt=' .. string.format('%.0f', dt) .. 'ms') end
				end
				if mods and #mods > 0 then
					local sig = table.concat(mods, '+') .. '+' .. tostring(code)
					local before = consumed
					consumed = fire(handlers.chord[sig], ev) or consumed
					if consumed and not before then dbg('chord ' .. sig) end
				end
				table.insert(state.seq, { code = code, t = now(), mods = mods })
				if #state.seq > 8 then table.remove(state.seq, 1) end
				for _, entry in ipairs(handlers.seq) do
					local okSeq = true
					local seq = entry.seq
					local within = entry.within / 1000
					local n = #seq
					if #state.seq < n then okSeq = false end
					if okSeq then
						local tnow = now()
						for i = 1, n do
							local want_mods = seq[i][1]
							local want_key = seq[i][2]
							local key_event = state.seq[#state.seq - (n - i)]
							local got_code = key_event.code
							local got_mods = key_event.mods

							if got_code ~= codeFor(want_key) then
								okSeq = false; break
							end

							local hyper = false
							if type(want_mods) == 'string' and want_mods == 'hyper' then
								hyper = true
							end

							if hyper then
								if not (got_mods.cmd and got_mods.alt and got_mods.ctrl and got_mods.shift) then
									okSeq = false; break
								end
							elseif type(want_mods) == 'table' then
								if #want_mods ~= #got_mods then
									okSeq = false; break
								end
								for _, mod in ipairs(want_mods) do
									if not got_mods[mod] then
										okSeq = false; break
									end
								end
								if not okSeq then break end
							end
						end
						if okSeq then
							local tstart = state.seq[#state.seq - (n - 1)].t
							if (tnow - tstart) <= within then
								dbg('sequence match'); entry.fn(); consumed = true
							end
						end
					end
				end
			end

			consumed = fireKeyHandlers(handlers.up[wildcardKey], ev, meta) or consumed
			consumed = fireKeyHandlers(handlers.up[code], ev, meta) or consumed
			return consumed
		end
	end)
	tapper:start()
	log.info('input_engine started')
end

function M.stop()
	if tapper then
		tapper:stop(); tapper = nil
	end
	log.info('input_engine stopped')
end

return M

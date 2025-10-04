-- hsLauncher/main/core/windows_native.lua
-- Native, deterministic window management and focus (no Rectangle dependency)
-- Derived in part from concepts in agzam/spacehammer (MIT). Adapted to Lua and hsLauncher.

--- @diagnostic disable: undefined-global

local M = {}
local log = require('hsLauncher.main.core.logger')
local drawing = require('hs.drawing')
local screen = require('hs.screen')
local window = require('hs.window')
local grid = require('hs.grid')
local hints = require('hs.hints')
local canvas = require('hs.canvas')
local wf = require('hs.window.filter')
wf.setLogLevel('warning')

local windowHistory = require('hsLauncher.main.core.window_history')
local windowGeometry = require('hsLauncher.main.core.window_geometry')
local windowNeighbors = require('hsLauncher.main.core.window_neighbors')

-- Reusable highlight overlay
local hiCanvas = nil
local hiTimer = nil

-- Config defaults; can be overridden from main/config.lua
local CFG = {
	gridSize = "3x2",
	gridMargins = { 0, 0 },
	centerRatio = "80:50", -- width:height percent
	adjustNeighbors = true,
	clampFrames = true,
}

local function deepCopy(value)
	if type(value) ~= 'table' then return value end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

local function highlight(win)
	if not win then return end
	local f = win:frame()
	if hiTimer then
		pcall(function () hiTimer:stop() end); hiTimer = nil
	end
	if hiCanvas then
		pcall(function () hiCanvas:delete() end); hiCanvas = nil
	end
	local cs = canvas.new(f)
	hiCanvas = cs
	cs:appendElements({
		type = "rectangle",
		action = "stroke",
		strokeColor = { red = 1, green = 0, blue = 1, alpha = 1 },
		strokeWidth = 5,
		fillColor = { alpha = 0 },
		roundedRectRadii = { xRadius = 4, yRadius = 4 },
	})
	cs:level(drawing.windowLevels.overlay)
	cs:behavior(canvas.windowBehaviors.canJoinAllSpaces)
	if cs.clickThrough then
		cs:clickThrough(true)
	elseif cs.behavior then
		cs:behavior({ 'canJoinAllSpaces', 'stationary' })
	end
	cs:show()
	hiTimer = hs.timer.doAfter(0.25, function ()
		if hiCanvas == cs then
			pcall(function () cs:delete() end); hiCanvas = nil
		end
	end)
end

function M.init(opts)
	opts = opts or {}
	CFG.gridSize = opts.gridSize or CFG.gridSize
	CFG.gridMargins = opts.gridMargins or CFG.gridMargins
	CFG.centerRatio = opts.centerRatio or CFG.centerRatio
	if opts.adjustNeighbors ~= nil then CFG.adjustNeighbors = opts.adjustNeighbors end
	if opts.clampFrames ~= nil then CFG.clampFrames = opts.clampFrames end

	grid.setGrid(CFG.gridSize)
	grid.setMargins(CFG.gridMargins)

	local presetsSource = opts.geometryPresets or windowGeometry.getPresets()
	local presets = deepCopy(presetsSource)
	presets.center = presets.center or {}
	presets.center.ratio = CFG.centerRatio
	presets.cycles = presets.cycles or {}
	if opts.horizontalCycle then presets.cycles.horizontal = opts.horizontalCycle end
	if opts.verticalCycle then presets.cycles.vertical = opts.verticalCycle end
	if opts.horizontalAnchor then presets.cycles.horizontalAnchor = opts.horizontalAnchor end
	if opts.verticalAnchor then presets.cycles.verticalAnchor = opts.verticalAnchor end

	windowGeometry.configure({
		presets = presets,
		clampToVisible = CFG.clampFrames,
	})

	log.info(string.format(
		"windows_native init grid=%s margins=%s adjustNeighbors=%s clampFrames=%s",
		CFG.gridSize,
		hs.inspect(CFG.gridMargins),
		tostring(CFG.adjustNeighbors),
		tostring(CFG.clampFrames)
	))
end

local function withNoAnim(fn)
	local prev = window.animationDuration
	window.animationDuration = 0
	local ok, err = pcall(fn)
	window.animationDuration = prev
	if not ok then log.error("window op failed: " .. tostring(err)) end
end

local function clampFrame(win, frame)
	if not frame then return nil end
	if not CFG.clampFrames then return frame end
	return windowGeometry.ensureVisible(frame, win)
end

local function commitFrame(mode, win, frame)
	frame = clampFrame(win, frame)
	if not frame then return false end
	windowHistory.record(win)
	withNoAnim(function () win:setFrame(frame, 0) end)
	if CFG.adjustNeighbors and mode then
		windowNeighbors.adjustNeighbors(mode, win, frame)
	end
	highlight(win)
	return true
end

local function commitFromGeometry(context, mode, generator)
	local win = window.focusedWindow()
	if not win then return end
	local frame, err = generator(win)
	if not frame then
		if err and err ~= 'no-screen' and err ~= 'no-window' and err ~= 'not-window' then
			log.error(string.format('windows_native.%s failed: %s', context, err))
		end
		return
	end
	commitFrame(mode, win, frame)
end

function M.undo()
	local ok = windowHistory.undoFocused({ duration = 0 })
	if ok then highlight(window.focusedWindow()) end
end

function M.maximize()
	local win = window.focusedWindow()
	if not win then return end
	windowHistory.record(win)
	withNoAnim(function () win:maximize(0) end)
	highlight(win)
end

function M.center()
	commitFromGeometry('center', nil, function (win)
		return windowGeometry.centerFrame(win, CFG.centerRatio)
	end)
end

function M.left()
	commitFromGeometry('left', 'left', function (win)
		return windowGeometry.cycleHorizontal(win, { anchor = 'left' })
	end)
end

function M.right()
	commitFromGeometry('right', 'right', function (win)
		return windowGeometry.cycleHorizontal(win, { anchor = 'right' })
	end)
end

function M.top()
	commitFromGeometry('top', 'top', function (win)
		return windowGeometry.cycleVertical(win, { anchor = 'top' })
	end)
end

function M.bottom()
	commitFromGeometry('bottom', 'bottom', function (win)
		return windowGeometry.cycleVertical(win, { anchor = 'bottom' })
	end)
end

function M.tl()
	commitFromGeometry('tl', 'tl', function (win)
		return windowGeometry.cycleCorner(win, 'left', 'top')
	end)
end

function M.tr()
	commitFromGeometry('tr', 'tr', function (win)
		return windowGeometry.cycleCorner(win, 'right', 'top')
	end)
end

function M.bl()
	commitFromGeometry('bl', 'bl', function (win)
		return windowGeometry.cycleCorner(win, 'left', 'bottom')
	end)
end

function M.br()
	commitFromGeometry('br', 'br', function (win)
		return windowGeometry.cycleCorner(win, 'right', 'bottom')
	end)
end

-- Directional window focus
local dirMap = { h = "West", j = "South", k = "North", l = "East" }

local function focusDir(dirKey)
	local wfCurrent = wf.defaultCurrentSpace
	local front = window.frontmostWindow()
	if not front then return end
	local method = "focusWindow" .. dirMap[dirKey]
	local ok, err = pcall(function ()
		wfCurrent[method](wfCurrent, front, true, true)
	end)
	if not ok then log.error("focus failed: " .. tostring(err)) end
	highlight(window.focusedWindow())
end

function M.focusLeft() focusDir("h") end

function M.focusDown() focusDir("j") end

function M.focusUp() focusDir("k") end

function M.focusRight() focusDir("l") end

function M.hints()
	local wins = window.allWindows()
	if not wins or #wins == 0 then return end
	hints.windowHints(wins, nil, true)
end

-- Display-number overlay for monitors
local activeCanvases = {}

local function showDisplayNumber(idx, scr)
	local f = scr:frame()
	local cs = canvas.new(f)
	table.insert(activeCanvases, cs)
	local fontSize = f.w / 10
	cs:appendElements({
		action = "fill",
		type = "text",
		frame = { x = "0.93", y = 0, w = "1", h = "1" },
		text = hs.styledtext.new(tostring(idx), { font = { size = fontSize }, color = { red = 1, green = 0.5, blue = 0, alpha = 1 } }),
		withShadow = true
	})
	cs:show()
end

function M.showDisplayNumbers()
	local screens = screen.allScreens()
	if #screens <= 1 then return end
	for i, scr in ipairs(screens) do showDisplayNumber(i, scr) end
end

function M.hideDisplayNumbers()
	for _, c in ipairs(activeCanvases) do pcall(function () c:delete(0.4) end) end
	activeCanvases = {}
end

function M.moveToScreenIndex(index)
	local win = window.focusedWindow()
	if not win then return end
	local screens = screen.allScreens()
	local target = screens[index]
	if not target then return end
	windowHistory.record(win)
	withNoAnim(function () win:moveToScreen(target, false, true) end)
	highlight(win)
end

return M

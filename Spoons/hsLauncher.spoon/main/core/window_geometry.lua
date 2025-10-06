--- @diagnostic disable: undefined-global

local screen = require('hs.screen')
local window = require('hs.window')

local hsobj = hs
local screenMT = hsobj and hsobj.getObjectMetatable and hsobj.getObjectMetatable('hs.screen') or nil
local windowMT = hsobj and hsobj.getObjectMetatable and hsobj.getObjectMetatable('hs.window') or nil

if not screenMT then
    local mainFn = screen and screen.mainScreen
    if type(mainFn) == 'function' then
        local ok, scr = pcall(mainFn)
        if ok and scr then screenMT = getmetatable(scr) end
    end
end

if not windowMT then
    local frontFn = window and window.frontmostWindow
    if type(frontFn) == 'function' then
        local ok, win = pcall(frontFn)
        if ok and win then windowMT = getmetatable(win) end
    end
end

local log = require('hsLauncher.main.core.logger')

local M = {}

local DEFAULT_PRESETS = {
    halves = {
        left   = { x = 0.0, y = 0.0, w = 0.5, h = 1.0 },
        right  = { x = 0.5, y = 0.0, w = 0.5, h = 1.0 },
        top    = { x = 0.0, y = 0.0, w = 1.0, h = 0.5 },
        bottom = { x = 0.0, y = 0.0, w = 1.0, h = 0.5 },
    },
    corners = {
        tl = { x = 0.0, y = 0.0, w = 0.5, h = 0.5 },
        tr = { x = 0.5, y = 0.0, w = 0.5, h = 0.5 },
        bl = { x = 0.0, y = 0.5, w = 0.5, h = 0.5 },
        br = { x = 0.5, y = 0.5, w = 0.5, h = 0.5 },
    },
    center = {
        ratio = '80:50',
    },
    cycles = {
        horizontal       = { 0.5, 1 / 3, 2 / 3 },
        vertical         = { 0.5, 1 / 3, 2 / 3 },
        horizontalAnchor = 'left',
        verticalAnchor   = 'top',
    }
}

local cfg = {
    presets = DEFAULT_PRESETS,
    clampToVisible = true,
}

local function cloneRect(rect)
    if not rect then return nil end
    return { x = rect.x, y = rect.y, w = rect.w, h = rect.h }
end

local function resolveCycle(sequence, current)
    if not sequence or #sequence == 0 then return current end
    local epsilon = 0.025
    local function approx(a, b)
        return math.abs((a or 0) - (b or 0)) < epsilon
    end
    for index, value in ipairs(sequence) do
        if approx(current, value) then
            local nextIndex = (index % #sequence) + 1
            return sequence[nextIndex]
        end
    end
    return sequence[1]
end

local function applyUnitRect(unitRect, frame)
    return {
        x = frame.x + frame.w * unitRect.x,
        y = frame.y + frame.h * unitRect.y,
        w = frame.w * unitRect.w,
        h = frame.h * unitRect.h,
    }
end

local function screenFrame(scr, includeMenu)
    if includeMenu then
        return scr:fullFrame()
    end
    return scr:frame()
end

local function isWindowObject(obj)
    if not obj then return false end
    if windowMT and getmetatable(obj) == windowMT then return true end
    if type(window.isWindow) == 'function' then
        local ok, result = pcall(window.isWindow, obj)
        if ok and result then return true end
    end
    if type(obj) == 'userdata' then
        local hasFrame = type(obj.frame) == 'function' or type(obj.frame) == 'table'
        local hasScreen = type(obj.screen) == 'function'
        if hasFrame and hasScreen then return true end
    end
    return false
end

local function isScreenObject(obj)
    if not obj then return false end
    if screenMT and getmetatable(obj) == screenMT then return true end
    if type(screen.isScreen) == 'function' then
        local ok, result = pcall(screen.isScreen, obj)
        if ok and result then return true end
    end
    if type(obj) == 'userdata' then
        local hasFrame = type(obj.frame) == 'function'
        local hasFullFrame = type(obj.fullFrame) == 'function'
        if hasFrame and hasFullFrame then return true end
    end
    return false
end

local function ensureScreen(obj)
    if not obj then return screen.mainScreen() end
    if isScreenObject(obj) then return obj end
    if isWindowObject(obj) then
        local ok, scr = pcall(function() return obj:screen() end)
        if ok and scr then return ensureScreen(scr) end
    end
    if type(obj) == 'table' then
        if type(obj.screen) == 'function' then
            local ok, scr = pcall(obj.screen, obj)
            if ok and scr then return ensureScreen(scr) end
        elseif type(obj.getScreen) == 'function' then
            local ok, scr = pcall(obj.getScreen, obj)
            if ok and scr then return ensureScreen(scr) end
        end
    end
    return screen.mainScreen()
end

function M.configure(opts)
    opts = opts or {}
    if opts.presets then cfg.presets = opts.presets end
    if opts.clampToVisible ~= nil then
        cfg.clampToVisible = opts.clampToVisible
    end
    return cfg
end

function M.getPresets()
    return cfg.presets
end

function M.frameForPreset(presetName, targetScreen, opts)
    opts = opts or {}
    local presets = cfg.presets
    local preset = presets.halves[presetName] or presets.corners[presetName]
    if not preset then
        log.error('window_geometry.frameForPreset: unknown preset ' .. tostring(presetName))
        return nil, 'unknown'
    end
    local scr = ensureScreen(targetScreen)
    if not scr then
        log.error('window_geometry.frameForPreset: unable to resolve screen')
        return nil, 'no-screen'
    end
    local frame = screenFrame(scr, opts.includeMenu)
    if not frame then
        log.error('window_geometry.frameForPreset: screen has no frame')
        return nil, 'no-frame'
    end
    local unit = cloneRect(preset)
    if opts.unitTransform then
        unit = opts.unitTransform(unit)
    end
    return applyUnitRect(unit, frame)
end

function M.centerFrame(winOrScreen, ratio)
    local scr = ensureScreen(winOrScreen)
    if not scr then return nil, 'no-screen' end
    local frame = screenFrame(scr, true)
    local centerPreset = cfg.presets.center or {}
    local presetRatio = ratio or centerPreset.ratio or '80:50'
    local wPct, hPct = presetRatio:match('^(%d+):(%d+)$')
    wPct = tonumber(wPct) or 80
    hPct = tonumber(hPct) or 50
    local w = frame.w * (wPct / 100)
    local h = frame.h * (hPct / 100)
    local x = frame.x + (frame.w - w) / 2
    local y = frame.y + (frame.h - h) / 2
    return { x = x, y = y, w = w, h = h }
end

local function cycleFrame(win, axis, opts)
    opts = opts or {}
    if not isWindowObject(win) then
        log.error('window_geometry.cycleFrame: expected hs.window object')
        return nil, 'not-window'
    end
    local scr = ensureScreen(win)
    if not scr then return nil, 'no-screen' end
    local frame = screenFrame(scr, false)
    local wFrame = win:frame()
    local presets = cfg.presets
    local sequence = axis == 'horizontal' and presets.cycles.horizontal or presets.cycles.vertical
    if not sequence or #sequence == 0 then return nil, 'no-cycle' end
    local currentRatio = axis == 'horizontal' and (wFrame.w / frame.w) or (wFrame.h / frame.h)
    local nextRatio = resolveCycle(sequence, currentRatio)
    if axis == 'horizontal' then
        local width = frame.w * nextRatio
        local anchor = opts.anchor or presets.cycles.horizontalAnchor or 'left'
        local x = (anchor == 'left') and frame.x or (frame.x + frame.w - width)
        return { x = x, y = frame.y, w = width, h = frame.h }
    else
        local height = frame.h * nextRatio
        local anchor = opts.anchor or presets.cycles.verticalAnchor or 'top'
        local y = (anchor == 'top') and frame.y or (frame.y + frame.h - height)
        return { x = frame.x, y = y, w = frame.w, h = height }
    end
end

function M.cycleHorizontal(win, opts)
    return cycleFrame(win, 'horizontal', opts)
end

function M.cycleVertical(win, opts)
    return cycleFrame(win, 'vertical', opts)
end

function M.cycleCorner(win, horizAnchor, vertAnchor)
    if not isWindowObject(win) then
        log.error('window_geometry.cycleCorner: expected hs.window object')
        return nil, 'not-window'
    end
    local scr = ensureScreen(win)
    if not scr then return nil, 'no-screen' end
    local frame = screenFrame(scr, false)
    local wFrame = win:frame()
    local halfHeight = frame.h * 0.5
    local y = (vertAnchor == 'top') and frame.y or (frame.y + frame.h - halfHeight)
    local sequence = cfg.presets.cycles.horizontal
    if not sequence or #sequence == 0 then return nil, 'no-cycle' end
    local currentWidthRatio = wFrame.w / frame.w
    local nextRatio = resolveCycle(sequence, currentWidthRatio)
    local width = frame.w * nextRatio
    local x = (horizAnchor == 'left') and frame.x or (frame.x + frame.w - width)
    return { x = x, y = y, w = width, h = halfHeight }
end

function M.ensureVisible(frame, winOrScreen)
    if not frame then return nil end
    if cfg.clampToVisible == false then return frame end
    local scr = ensureScreen(winOrScreen)
    if not scr then return frame end
    local vis = screenFrame(scr, true)
    if not vis then return frame end
    local clamped = {
        x = math.max(vis.x, math.min(frame.x, vis.x + vis.w - frame.w)),
        y = math.max(vis.y, math.min(frame.y, vis.y + vis.h - frame.h)),
        w = math.min(frame.w, vis.w),
        h = math.min(frame.h, vis.h),
    }
    return clamped
end

return M

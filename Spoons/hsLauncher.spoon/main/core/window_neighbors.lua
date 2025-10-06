local window = require('hs.window')
local inspect = require('hs.inspect')

local log = require('hsLauncher.main.core.logger')

local M = {}

local function rectArea(r)
    if not r or r.w <= 0 or r.h <= 0 then return 0 end
    return r.w * r.h
end

local function intersect(a, b)
    if not a or not b then return { x = 0, y = 0, w = 0, h = 0 } end
    local x1 = math.max(a.x, b.x)
    local y1 = math.max(a.y, b.y)
    local x2 = math.min(a.x + a.w, b.x + b.w)
    local y2 = math.min(a.y + a.h, b.y + b.h)
    local w = x2 - x1
    local h = y2 - y1
    if w <= 0 or h <= 0 then return { x = 0, y = 0, w = 0, h = 0 } end
    return { x = x1, y = y1, w = w, h = h }
end

local function visibleWindowsOnScreen(scr, excludeId)
    local wins = window.visibleWindows()
    local out = {}
    for _, w in ipairs(wins) do
        local ok = true
        if excludeId and w:id() == excludeId then ok = false end
        if ok and (not w:isStandard()) then ok = false end
        local ws = w:screen()
        if ok and (not ws or ws:id() ~= scr:id()) then ok = false end
        if ok then table.insert(out, w) end
    end
    return out
end

local function setFrame(win, frame, duration)
    if not win or not frame then return false end
    local ok, err = pcall(function()
        win:setFrame(frame, duration or 0)
    end)
    if not ok then
        log.error('window_neighbors.setFrame failed: ' .. tostring(err))
    end
    return ok
end

local function selectOverlap(candidates, region, threshold)
    local hits = {}
    threshold = threshold or 2000
    for _, w in ipairs(candidates) do
        local frame = w:frame()
        local overlap = rectArea(intersect(frame, region))
        if overlap > threshold then table.insert(hits, w) end
    end
    return hits
end

local function tileVertical(windows, region)
    if not windows or #windows == 0 then return end
    local h = region.h / #windows
    local y = region.y
    for _, w in ipairs(windows) do
        setFrame(w, { x = region.x, y = y, w = region.w, h = h })
        y = y + h
    end
end

local function tileHorizontal(windows, region)
    if not windows or #windows == 0 then return end
    local w = region.w / #windows
    local x = region.x
    for _, win in ipairs(windows) do
        setFrame(win, { x = x, y = region.y, w = w, h = region.h })
        x = x + w
    end
end

local function guardTarget(win, targetFrame)
    if not win then return false, 'no-window' end
    if not targetFrame then return false, 'no-frame' end
    local scr = win:screen()
    if not scr then return false, 'no-screen' end
    local frame = scr:frame()
    if targetFrame.x < frame.x - 5 or targetFrame.y < frame.y - 5 then
        log.error('window_neighbors.guardTarget: target outside visible bounds ' .. inspect(targetFrame))
        return false, 'out-of-bounds'
    end
    return true
end

local function remainderRegion(mode, screenFrame, targetFrame)
    if mode == 'left' then
        return {
            x = targetFrame.x + targetFrame.w,
            y = screenFrame.y,
            w = screenFrame.x + screenFrame.w - (targetFrame.x + targetFrame.w),
            h = screenFrame.h
        }
    elseif mode == 'right' then
        return {
            x = screenFrame.x,
            y = screenFrame.y,
            w = targetFrame.x - screenFrame.x,
            h = screenFrame.h
        }
    elseif mode == 'top' then
        return {
            x = screenFrame.x,
            y = targetFrame.y + targetFrame.h,
            w = screenFrame.w,
            h = screenFrame.y + screenFrame.h - (targetFrame.y + targetFrame.h)
        }
    elseif mode == 'bottom' then
        return {
            x = screenFrame.x,
            y = screenFrame.y,
            w = screenFrame.w,
            h = targetFrame.y - screenFrame.y
        }
    else
        return nil
    end
end

local function cornerRemainder(mode, screenFrame, targetFrame)
    local upper = (mode == 'tl' or mode == 'tr')
    local leftSide = (mode == 'tl' or mode == 'bl')
    local halfHeight = screenFrame.h * 0.5
    local halfRegion = upper
        and { x = screenFrame.x, y = screenFrame.y, w = screenFrame.w, h = halfHeight }
        or { x = screenFrame.x, y = screenFrame.y + halfHeight, w = screenFrame.w, h = halfHeight }
    local remainder
    if leftSide then
        remainder = {
            x = targetFrame.x + targetFrame.w,
            y = halfRegion.y,
            w = halfRegion.x + halfRegion.w - (targetFrame.x + targetFrame.w),
            h = halfRegion.h
        }
    else
        remainder = {
            x = halfRegion.x,
            y = halfRegion.y,
            w = targetFrame.x - halfRegion.x,
            h = halfRegion.h
        }
    end
    return remainder, halfRegion
end

function M.adjustNeighbors(mode, win, targetFrame, opts)
    opts = opts or {}
    if not mode or not win or not targetFrame then return false end
    local ok, reason = guardTarget(win, targetFrame)
    if not ok then return false, reason end
    local scr = win:screen()
    if not scr then return false, 'no-screen' end
    local scrFrame = opts.screenFrame or scr:frame()
    local others = visibleWindowsOnScreen(scr, win:id())
    if not others or #others == 0 then return false, 'no-others' end

    if mode == 'left' or mode == 'right' or mode == 'top' or mode == 'bottom' then
        local remainder = remainderRegion(mode, scrFrame, targetFrame)
        if not remainder or remainder.w <= 0 or remainder.h <= 0 then return false, 'no-space' end
        local primary = selectOverlap(others, targetFrame)
        if #primary == 0 then return false, 'no-overlap' end
        if #primary == 1 then
            setFrame(primary[1], remainder)
            return true, 'single'
        end
        if mode == 'left' or mode == 'right' then
            tileVertical(primary, remainder)
        else
            tileHorizontal(primary, remainder)
        end
        log.info(string.format('window_neighbors.adjustNeighbors %s tiled %d windows', mode, #primary))
        return true, 'tiled'
    end

    local remainder, halfRegion = cornerRemainder(mode, scrFrame, targetFrame)
    if not remainder or remainder.w <= 0 or remainder.h <= 0 then return false, 'no-space' end
    local inHalf = {}
    for _, other in ipairs(others) do
        local frame = other:frame()
        if rectArea(intersect(frame, halfRegion)) > 2000 and rectArea(intersect(frame, targetFrame)) > 0 then
            table.insert(inHalf, other)
        end
    end
    if #inHalf == 0 then return false, 'no-overlap' end
    if #inHalf == 1 then
        setFrame(inHalf[1], remainder)
        return true, 'single'
    end
    tileHorizontal(inHalf, remainder)
    log.info(string.format('window_neighbors.adjustNeighbors %s tiled %d windows', mode, #inHalf))
    return true, 'tiled'
end

return M

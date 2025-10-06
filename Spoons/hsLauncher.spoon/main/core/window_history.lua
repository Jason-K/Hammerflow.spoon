local window = require('hs.window')
local alert = require('hs.alert')

local log = require('hsLauncher.main.core.logger')

local M = {}

local history = {}

local function cloneFrame(frame)
    if not frame then return nil end
    return { x = frame.x, y = frame.y, w = frame.w, h = frame.h }
end

local function framesEqual(a, b)
    if not a or not b then return false end
    return a.x == b.x and a.y == b.y and a.w == b.w and a.h == b.h
end

local function stackFor(id)
    if not id then return nil end
    history[id] = history[id] or {}
    return history[id]
end

function M.clear(id)
    if id then
        history[id] = nil
        return
    end
    history = {}
end

local function ensureWindow(win)
    if not win or not win.id then return nil end
    local ok, id = pcall(function() return win:id() end)
    if not ok or not id then return nil end
    return id
end

function M.record(win, frame)
    local id = ensureWindow(win)
    if not id then
        log.error('window_history.record: invalid window handle')
        return false
    end
    local snapshot = cloneFrame(frame or win:frame())
    if not snapshot then
        log.error('window_history.record: unable to capture frame')
        return false
    end
    local stack = stackFor(id)
    if not stack then
        log.error('window_history.record: unable to resolve stack')
        return false
    end
    local last = stack[#stack]
    if not framesEqual(last, snapshot) then
        table.insert(stack, snapshot)
        return true
    end
    return false
end

local function applyFrame(win, frame, duration)
    if not frame then return false, 'no-frame' end
    local ok, err = pcall(function()
        win:setFrame(frame, duration or 0)
    end)
    if not ok then
        log.error('window_history.applyFrame failed: ' .. tostring(err))
    end
    return ok, err
end

local function notify(message, opts)
    opts = opts or {}
    if opts.alert == false then return end
    alert.show(message, opts.textStyle, opts.duration)
end

function M.undo(win, opts)
    opts = opts or {}
    local id = ensureWindow(win)
    if not id then
        notify('No window to undo', opts)
        return false, 'no-window'
    end
    local stack = history[id]
    if not stack or #stack == 0 then
        notify('Nothing to undo', opts)
        return false, 'empty'
    end
    local frame = table.remove(stack)
    local ok, err = applyFrame(win, frame, opts.duration)
    if not ok then
        notify('Undo failed', opts)
        return false, err
    end
    notify(string.format('%d undo steps left', #stack), opts)
    return true, frame, #stack
end

function M.undoFocused(opts)
    local win = window.focusedWindow()
    if not win then
        notify('No focused window', opts)
        return false, 'no-focused-window'
    end
    return M.undo(win, opts)
end

function M.peek(win)
    local id = ensureWindow(win)
    if not id then return nil end
    local stack = history[id]
    if not stack then return nil end
    return stack[#stack]
end

function M.depth(win)
    local id = ensureWindow(win)
    if not id then return 0 end
    local stack = history[id]
    return stack and #stack or 0
end

return M

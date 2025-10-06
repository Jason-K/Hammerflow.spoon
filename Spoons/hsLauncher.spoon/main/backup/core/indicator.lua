-- hsLauncher/backup/core/indicator.lua
-- Canvas indicator preserved for the legacy hyper modal stack.

local screen = require('hs.screen')
local drawing = require('hs.drawing')
local canvas = require('hs.canvas')
local timer = require('hs.timer')

local Indicator = {}
Indicator.__index = Indicator

local function primaryFrame()
    return screen.primaryScreen():frame()
end

function Indicator.new(opts)
    local self = setmetatable({}, Indicator)
    self.opts = opts or {}
    self.width = self.opts.width or 400
    self.height = self.opts.height or 34
    self.marginTop = self.opts.marginTop or 8
    self.radius = 6
    self.alpha = self.opts.alpha or 0.9
    self.fontSize = self.opts.fontSize or 16
    self.position = self.opts.position or 'top-center' -- or 'top-right'
    self.sticky = false
    self.c = nil
    self.flashTimer = nil
    return self
end

local function calcRect(self)
    local f = primaryFrame()
    local x
    if self.position == 'top-right' then
        x = f.x + f.w - self.width - 10
    else
        x = f.x + (f.w - self.width) / 2
    end
    local y = f.y + self.marginTop
    return { x = x, y = y, w = self.width, h = self.height }
end

local function ensureCanvas(self)
    if self.c then return end
    local r = calcRect(self)
    local c = canvas.new { x = r.x, y = r.y, w = r.w, h = r.h }
    c:level(drawing.windowLevels.overlay)
    c[1] = { type = 'rectangle', action = 'fill', fillColor = { white = 0, alpha = self.alpha }, roundedRectRadii = { xRadius = self.radius, yRadius = self.radius } }
    c[2] = { type = 'text', text = 'Hy', textFont = 'Helvetica-Bold', textSize = self.fontSize, textColor = { white = 1, alpha = 1 }, frame = { x = 8, y = 4, w = r.w - 16, h = r.h - 8 }, textAlignment = 'center' }
    c[3] = { type = 'rectangle', action = 'stroke', strokeColor = { red = 1, green = 0, blue = 0, alpha = 0.9 }, strokeWidth = 2, roundedRectRadii = { xRadius = self.radius, yRadius = self.radius } }
    self.c = c
end

function Indicator.set(self, text)
    ensureCanvas(self)
    local r = calcRect(self)
    self.c:frame(r)
    self.c[2].frame = { x = 8, y = 4, w = r.w - 16, h = r.h - 8 }
    self.c[3].frame = { x = 0, y = 0, w = r.w, h = r.h }
    self.c[2].text = text or ''
    self.c:show()
end

function Indicator.show(self, text)
    self.sticky = true
    self:set(text or '')
end

function Indicator.hide(self)
    self.sticky = false
    if self.c then self.c:hide() end
end

function Indicator.flash(self, text, secs)
    self:set(text or '')
    if self.flashTimer then
        self.flashTimer:stop(); self.flashTimer = nil
    end
    self.flashTimer = timer.doAfter(secs or 0.6, function()
        if not self.sticky and self.c then self.c:hide() end
    end)
end

function Indicator.delete(self)
    if self.flashTimer then
        self.flashTimer:stop(); self.flashTimer = nil
    end
    if self.c then
        self.c:delete(); self.c = nil
    end
end

return Indicator

--- === WindowDragResize ===
---
--- Move and resize windows using keyboard modifiers and mouse dragging
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowDragResize.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/WindowDragResize.spoon.zip)

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "WindowDragResize"
obj.version = "1.0"
obj.author = "Hammerspoon"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Default settings
obj.moveModifiers = {"ctrl", "shift"}      -- Left Ctrl+Shift for moving
obj.resizeModifiers = {"ctrl", "shift"}    -- Left Ctrl+Shift for resizing
obj.continuousMove = true
obj.moveEventTap = nil
obj.resizeEventTap = nil
obj.debug = false

-- Logger
local log = hs.logger.new('WindowDragResize', 'warning')

--- WindowDragResize:init()
--- Method
--- Initialize the spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The WindowDragResize object
function obj:init()
    return self
end

--- WindowDragResize:debug(enable)
--- Method
--- Enable or disable debug logging
---
--- Parameters:
---  * enable - boolean: true to enable debugging, false to disable
---
--- Returns:
---  * The WindowDragResize object
function obj:debug(enable)
    if enable then
        log.setLogLevel('debug')
        self.debug = true
    else
        log.setLogLevel('warning')
        self.debug = false
    end
    return self
end

-- Get the window under the mouse cursor
local function getWindowUnderMouse()
    local mousePos = hs.geometry.new(hs.mouse.absolutePosition())
    local screen = hs.mouse.getCurrentScreen()
    
    return hs.fnutils.find(hs.window.orderedWindows(), function(w)
        return screen == w:screen() and mousePos:inside(w:frame())
    end)
end

--- WindowDragResize:bindMouseEvents()
--- Method
--- Binds the mouse events for window dragging and resizing
---
--- Parameters:
---  * None
---
--- Returns:
---  * The WindowDragResize object
function obj:bindMouseEvents()
    -- Stop any existing event taps
    self:unbindMouseEvents()

    -- Handle window resizing with resizeModifiers + left click + drag
    self.resizeEventTap = hs.eventtap.new({hs.eventtap.event.types.leftMouseDown, hs.eventtap.event.types.leftMouseDragged, hs.eventtap.event.types.leftMouseUp}, function(e)
        local eventType = e:getType()
        local flags = e:getFlags()
        
        -- Check if we have the required modifiers
        local modifiersMatch = true
        for _, modifier in ipairs(self.resizeModifiers) do
            if not flags[modifier] then
                modifiersMatch = false
                break
            end
        end
        
        if modifiersMatch then
            -- Get the window under the mouse
            local window = getWindowUnderMouse()
            
            if not window then
                log.d("No window found under mouse for resize")
                return false
            end
            
            if eventType == hs.eventtap.event.types.leftMouseDown then
                log.d("Left mouse down with modifiers for resize")
                -- Save initial position for calculation
                self.initialMousePos = hs.mouse.absolutePosition()
                self.initialFrame = window:frame()
                return true -- consume the event
                
            elseif eventType == hs.eventtap.event.types.leftMouseDragged then
                log.d("Left mouse drag for resize")
                -- Calculate the new size
                local currentPos = hs.mouse.absolutePosition()
                local dx = currentPos.x - self.initialMousePos.x
                local dy = currentPos.y - self.initialMousePos.y
                
                if window then
                    local newFrame = {
                        x = self.initialFrame.x,
                        y = self.initialFrame.y,
                        w = self.initialFrame.w + dx,
                        h = self.initialFrame.h + dy
                    }
                    window:setFrame(newFrame)
                    return true -- consume the event
                end
                
            elseif eventType == hs.eventtap.event.types.leftMouseUp then
                log.d("Left mouse up, ending resize")
                self.initialMousePos = nil
                self.initialFrame = nil
                return true -- consume the event
            end
        end
        
        return false -- let the event pass through
    end)
    
    -- Handle window movement with moveModifiers + right click + drag
    self.moveEventTap = hs.eventtap.new({hs.eventtap.event.types.rightMouseDown, hs.eventtap.event.types.rightMouseDragged, hs.eventtap.event.types.rightMouseUp}, function(e)
        local eventType = e:getType()
        local flags = e:getFlags()
        
        -- Check if we have the required modifiers
        local modifiersMatch = true
        for _, modifier in ipairs(self.moveModifiers) do
            if not flags[modifier] then
                modifiersMatch = false
                break
            end
        end
        
        if modifiersMatch then
            -- Get the window under the mouse
            local window = getWindowUnderMouse()
            
            if not window then
                log.d("No window found under mouse for move")
                return false
            end
            
            if eventType == hs.eventtap.event.types.rightMouseDown then
                log.d("Right mouse down with modifiers for move")
                -- Save initial position for calculation
                self.initialMousePos = hs.mouse.absolutePosition()
                self.initialFrame = window:frame()
                return true -- consume the event
                
            elseif eventType == hs.eventtap.event.types.rightMouseDragged then
                log.d("Right mouse drag for move")
                -- Calculate the new position
                local currentPos = hs.mouse.absolutePosition()
                local dx = currentPos.x - self.initialMousePos.x
                local dy = currentPos.y - self.initialMousePos.y
                
                if window then
                    local newFrame = {
                        x = self.initialFrame.x + dx,
                        y = self.initialFrame.y + dy,
                        w = self.initialFrame.w,
                        h = self.initialFrame.h
                    }
                    window:setFrame(newFrame)
                    return true -- consume the event
                end
                
            elseif eventType == hs.eventtap.event.types.rightMouseUp then
                log.d("Right mouse up, ending move")
                self.initialMousePos = nil
                self.initialFrame = nil
                return true -- consume the event
            end
        end
        
        return false -- let the event pass through
    end)
    
    return self
end

--- WindowDragResize:unbindMouseEvents()
--- Method
--- Unbinds the mouse events for window dragging and resizing
---
--- Parameters:
---  * None
---
--- Returns:
---  * The WindowDragResize object
function obj:unbindMouseEvents()
    if self.moveEventTap then
        self.moveEventTap:stop()
        self.moveEventTap = nil
    end
    
    if self.resizeEventTap then
        self.resizeEventTap:stop()
        self.resizeEventTap = nil
    end
    
    return self
end

--- WindowDragResize:start()
--- Method
--- Start listening for mouse events to drag and resize windows
---
--- Parameters:
---  * None
---
--- Returns:
---  * The WindowDragResize object
function obj:start()
    self:bindMouseEvents()
    
    if self.moveEventTap then
        self.moveEventTap:start()
    end
    
    if self.resizeEventTap then
        self.resizeEventTap:start()
    end
    
    log.d("WindowDragResize started")
    return self
end

--- WindowDragResize:stop()
--- Method
--- Stop listening for mouse events
---
--- Parameters:
---  * None
---
--- Returns:
---  * The WindowDragResize object
function obj:stop()
    self:unbindMouseEvents()
    log.d("WindowDragResize stopped")
    return self
end

return obj
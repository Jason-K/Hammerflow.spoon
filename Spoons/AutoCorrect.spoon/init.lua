--- === AutoCorrect ===
---
--- Real-time autocorrection for typing mistakes
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AutoCorrect.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/AutoCorrect.spoon.zip)

-- Store module name
local _MODULE_NAME = ...

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "AutoCorrect"
obj.version = "1.0"
obj.author = "Jason"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license = "MIT - https://opensource.org/licenses/MIT"

-- Module state
obj.patterns = {}
obj.currentWord = ""
obj.wordBuffer = ""
obj.lastBoundary = 0
obj.isProcessing = false
obj.debug = false
obj.logger = hs.logger.new('AutoCorrect', 'debug')

-- Debug logging helper
local function debugLog(fmt, ...)
    if obj.debug then
        local msg = string.format(fmt, ...)
        obj.logger.d(msg)
    end
end

local function processCorrection(word)
    if not obj.isProcessing and word then
        local replacement = obj.patterns[word]
        if replacement and replacement ~= word then
            obj.isProcessing = true
            
            -- Create a single eventtap for the entire correction sequence
            local tap = hs.eventtap.new({}, function() end)
            tap:start()
            
            -- Delete misspelled word
            for _ = 1, #word do
                tap:keyStroke({}, "delete")
            end
            
            -- Type the replacement
            tap:keyStrokes(replacement)
            tap:stop()
            
            obj.isProcessing = false
        end
    end
end

--- AutoCorrect:start()
--- Method
--- Start the autocorrect functionality
---
--- Parameters:
---  * None
---
--- Returns:
---  * The AutoCorrect object
function obj:start()
    debugLog("Starting autocorrect...")
    
    -- Load patterns if they haven't been loaded
    if not self.patternsLoaded then
        self:loadPatterns()
    end
    
    -- Create keyboard watcher with minimal processing
    self.watcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
        local flags = event:getFlags()
        local keyCode = event:getKeyCode()
        local char = hs.keycodes.map[keyCode]
        
        -- Skip if modifier keys are pressed (except shift)
        if flags.cmd or flags.alt or flags.ctrl then
            self.currentWord = ""
            return false
        end
        
        -- Handle character input with zero processing overhead
        if char then
            if #char == 1 then
                -- Check for word boundary
                if char:match("[%s%p]") then
                    if #self.currentWord > 0 then
                        local now = hs.timer.absoluteTime()
                        if now - self.lastBoundary > 100000 then -- 0.1s between corrections
                            self.wordBuffer = self.currentWord
                            -- Process correction in next event loop
                            hs.timer.doAfter(0, function()
                                processCorrection(self.wordBuffer)
                            end)
                            self.lastBoundary = now
                        end
                    end
                    self.currentWord = ""
                else
                    self.currentWord = self.currentWord .. char
                end
            end
        elseif keyCode == hs.keycodes.map["delete"] then
            if #self.currentWord > 0 then
                self.currentWord = self.currentWord:sub(1, -2)
            end
        elseif keyCode == hs.keycodes.map["return"] then
            self.currentWord = ""
        end
        
        return false
    end)

    self.watcher:start()
    debugLog("Autocorrect started!")
    return self
end

--- AutoCorrect:stop()
--- Method
--- Stop the autocorrect functionality
---
--- Parameters:
---  * None
---
--- Returns:
---  * The AutoCorrect object
function obj:stop()
    if self.watcher then
        self.watcher:stop()
        self.watcher = nil
    end
    return self
end

--- AutoCorrect:addPattern(trigger, replacement)
--- Method
--- Add a new autocorrect pattern
---
--- Parameters:
---  * trigger - A string that triggers the autocorrect
---  * replacement - The string to replace the trigger with
---
--- Returns:
---  * The AutoCorrect object
function obj:addPattern(trigger, replacement)
    self.patterns[trigger] = replacement
    return self
end

--- AutoCorrect:loadPatterns()
--- Method
--- Load autocorrect patterns from patterns.lua
---
--- Parameters:
---  * None
function obj:loadPatterns()
    -- Load patterns from separate file
    local patterns = require(string.format("%s.patterns", _MODULE_NAME))
--    local patterns = require(string.format("%s.patterns", (...)))
    for trigger, replacement in pairs(patterns) do
        self:addPattern(trigger, replacement)
    end
    self.patternsLoaded = true
    return self
end

--- AutoCorrect:init()
--- Method
--- Initialize the spoon
---
--- Parameters:
---  * None
---
--- Returns:
---  * The AutoCorrect object
function obj:init()
    return self
end

return obj
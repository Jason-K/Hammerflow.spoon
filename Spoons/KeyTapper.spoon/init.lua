--- === KeyTapper ===
---
--- A Spoon that lets you assign callbacks to keyboard events including multi-taps and key combinations
---
--- Features:
---   * Detect multi-taps (pressing the same key multiple times in a short timeframe)
---   * Detect key combinations (pressing multiple keys together or in sequence)
---   * Customizable timeouts for multi-tap and sequence detection
---
--- Download: [https://github.com/Hammerspoon/Spoons/raw/master/Spoons/KeyTapper.spoon.zip](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/KeyTapper.spoon.zip)

-- Define the module
local KeyTapper = {}

-- Metadata
KeyTapper.name = "KeyTapper"
KeyTapper.version = "1.0"
KeyTapper.author = "Hammerspoon"
KeyTapper.homepage = "https://github.com/Hammerspoon/Spoons"
KeyTapper.license = "MIT - https://opensource.org/licenses/MIT"

-- Settings with default values
KeyTapper.multiTapTimeout = 0.5      -- seconds between taps to be considered a multi-tap
KeyTapper.combinationTimeout = 0.75  -- seconds between keys to be considered a combination
KeyTapper.debugMode = false          -- enable for debug logging
KeyTapper.sequenceResetDelay = 2.0   -- seconds after which a sequence will be reset

-- Internal state
local multiTapHandlers = {}          -- handlers for multi-tap events
local combinationHandlers = {}       -- handlers for key combination events
local sequenceModeHandlers = {}      -- handlers for sequence-mode key presses
local tapWatcher = nil               -- eventtap watcher
local flagsWatcher = nil             -- eventtap for modifier flags
local keyState = {}                  -- track key states
local lastKeyTime = {}               -- track when keys were pressed for multi-tap
local keyCount = {}                  -- track how many times a key has been pressed
local modifiers = {}                 -- track which modifiers are currently pressed
local keySequence = {}               -- track sequence of pressed keys
local lastSequenceTime = 0           -- when the last key in sequence was pressed
local sequenceTimer = nil            -- timer to reset sequence after delay
local lastKeyCode = nil              -- track the last key code to prevent duplicate events
local lastEventTime = 0              -- track the last event time to prevent duplicate events

-- Logger
local log = hs.logger.new('KeyTapper', 'warning')

-- Initialize the module
function KeyTapper:init()
    -- Nothing to do here yet
    return self
end

--- KeyTapper:debugEnable(enable)
--- Method
--- Enable or disable debug logging
---
--- Parameters:
---  * enable - boolean: true to enable debug logging, false to disable
---
--- Returns:
---  * The KeyTapper object
function KeyTapper:debugEnable(enable)
    if enable then
        log.setLogLevel('debug')
        self.debugMode = true
    else
        log.setLogLevel('warning')
        self.debugMode = false
    end
    return self
end

--- KeyTapper:handleMultiTap(key, count, fn)
--- Method
--- Register a callback function for when a key is tapped multiple times
---
--- Parameters:
---  * key - string: the key to watch (from hs.keycodes.map)
---  * count - number: how many taps to watch for (2 for double-tap, 3 for triple-tap, etc.)
---  * fn - function: callback function to execute when the multi-tap is detected
---
--- Returns:
---  * The KeyTapper object
function KeyTapper:handleMultiTap(key, count, fn)
    if type(key) ~= "string" or type(count) ~= "number" or type(fn) ~= "function" then
        log.e("Invalid parameters for handleMultiTap")
        return self
    end
    
    -- Initialize the handlers table for this key if it doesn't exist
    multiTapHandlers[key] = multiTapHandlers[key] or {}
    
    -- Store the callback function
    multiTapHandlers[key][count] = fn
    
    log.d("Registered multi-tap handler for key", key, "with count", count)
    
    return self
end

--- KeyTapper:handleCombination(keys, fn)
--- Method
--- Register a callback function for when a combination of keys is pressed
---
--- Parameters:
---  * keys - table: list of keys that make up the combination (strings from hs.keycodes.map)
---  * fn - function: callback function to execute when the combination is detected
---
--- Returns:
---  * The KeyTapper object
function KeyTapper:handleCombination(keys, fn)
    if type(keys) ~= "table" or type(fn) ~= "function" then
        log.e("Invalid parameters for handleCombination")
        return self
    end
    
    -- Sort the keys to ensure consistent handling regardless of order
    table.sort(keys)
    
    -- Create a key to identify this combination
    local comboKey = table.concat(keys, "+")
    
    -- Store the callback function
    combinationHandlers[comboKey] = fn
    
    log.d("Registered combination handler for", comboKey)
    
    return self
end

--- KeyTapper:handleSequence(keys, fn)
--- Method
--- Register a callback function for when a sequence of keys is pressed in order
---
--- Parameters:
---  * keys - table: ordered list of keys for the sequence (strings from hs.keycodes.map)
---  * fn - function: callback function to execute when the sequence is detected
---
--- Returns:
---  * The KeyTapper object
function KeyTapper:handleSequence(keys, fn)
    if type(keys) ~= "table" or type(fn) ~= "function" then
        log.e("Invalid parameters for handleSequence")
        return self
    end
    
    -- Create a key to identify this sequence
    local seqKey = table.concat(keys, ",")
    
    -- Store the callback function
    sequenceModeHandlers[seqKey] = fn
    
    log.d("Registered sequence handler for", seqKey)
    
    return self
end

-- Private function: Process a key event
local function processKeyEvent(event)
    -- Get event details
    local flags = event:getFlags()
    local keyCode = event:getKeyCode()
    local keyName = hs.keycodes.map[keyCode]
    local eventType = event:getType()
    local now = hs.timer.secondsSinceEpoch()
    
    -- Skip if we can't identify the key
    if not keyName then
        return false
    end
    
    -- Detect and prevent duplicate events
    if lastKeyCode == keyCode and (now - lastEventTime) < 0.01 then
        log.d("Duplicate event detected and skipped for", keyName)
        return false
    end
    
    lastKeyCode = keyCode
    lastEventTime = now
    
    -- Track modifiers for combinations
    if eventType == hs.eventtap.event.types.flagsChanged then
        -- Update modifier state
        local wasDown = modifiers[keyName] or false
        local isDown = flags[keyName] == true
        
        modifiers[keyName] = isDown
        
        log.d("Modifier change:", keyName, isDown and "down" or "up")
        
        -- We don't do further processing for modifier key changes
        return false
    end
    
    -- Process key down events
    if eventType == hs.eventtap.event.types.keyDown then
        -- Reset sequence if too much time has passed
        if now - lastSequenceTime > KeyTapper.sequenceResetDelay and #keySequence > 0 then
            log.d("Sequence reset due to timeout")
            keySequence = {}
        end
        
        -- Process multi-tap detection
        if lastKeyTime[keyName] and (now - lastKeyTime[keyName] <= KeyTapper.multiTapTimeout) then
            -- This is a repeat tap
            keyCount[keyName] = (keyCount[keyName] or 1) + 1
            log.d(keyName, "tapped", keyCount[keyName], "times")
            
            -- Check if we have a handler for this number of taps
            if multiTapHandlers[keyName] and multiTapHandlers[keyName][keyCount[keyName]] then
                -- Execute the callback
                log.d("Executing multi-tap handler for", keyName, "with count", keyCount[keyName])
                hs.timer.doAfter(0.05, function()
                    multiTapHandlers[keyName][keyCount[keyName]]()
                end)
                
                -- Reset state
                keyCount[keyName] = 0
            end
        else
            -- First tap or too much time has passed
            keyCount[keyName] = 1
        end
        
        -- Update last key time
        lastKeyTime[keyName] = now
        
        -- Track key state
        keyState[keyName] = true
        
        -- Add to sequence only if it's not a repeat of the last key or a modifier key
        local isModifier = false
        for mod, _ in pairs(hs.eventtap.event.newKeyEvent({}, "a", true):getFlags()) do
            if keyName == mod then
                isModifier = true
                break
            end
        end
        
        if not isModifier and (not keySequence[#keySequence] or keySequence[#keySequence] ~= keyName) then
            table.insert(keySequence, keyName)
            lastSequenceTime = now
        end
        
        log.d("Current sequence:", table.concat(keySequence, ","))
        
        -- Check for sequence matches
        local currentSequence = table.concat(keySequence, ",")
        
        for seq, handler in pairs(sequenceModeHandlers) do
            if currentSequence:sub(-#seq) == seq then
                -- We found a matching sequence
                log.d("Sequence match found:", seq)
                
                -- Reset sequence after matching
                keySequence = {}
                
                -- Execute the callback
                hs.timer.doAfter(0.05, function()
                    handler()
                end)
                
                break
            end
        end
        
        -- Check active key combinations
        local activeKeys = {}
        for k, v in pairs(keyState) do
            if v == true then
                table.insert(activeKeys, k)
            end
        end
        
        -- Add active modifiers to the list
        for k, v in pairs(modifiers) do
            if v == true then
                table.insert(activeKeys, k)
            end
        end
        
        -- Sort the keys to match our stored combinations
        table.sort(activeKeys)
        
        -- Create a key to check against our handlers
        local comboKey = table.concat(activeKeys, "+")
        
        log.d("Active combination:", comboKey)
        
        -- Check if we have a handler for this combination
        if combinationHandlers[comboKey] then
            -- Execute the callback
            log.d("Executing combination handler for", comboKey)
            hs.timer.doAfter(0.05, function()
                combinationHandlers[comboKey]()
            end)
        end
    elseif eventType == hs.eventtap.event.types.keyUp then
        -- Track key state
        keyState[keyName] = false
    end
    
    -- Allow the event to propagate
    return false
end

--- KeyTapper:start()
--- Method
--- Start monitoring keyboard events
---
--- Parameters:
---  * None
---
--- Returns:
---  * The KeyTapper object
function KeyTapper:start()
    -- Stop any existing watchers
    self:stop()
    
    -- Reset all state
    keyState = {}
    lastKeyTime = {}
    keyCount = {}
    modifiers = {}
    keySequence = {}
    lastSequenceTime = 0
    lastKeyCode = nil
    lastEventTime = 0
    
    -- Create keyboard event watcher
    tapWatcher = hs.eventtap.new({
        hs.eventtap.event.types.keyDown,
        hs.eventtap.event.types.keyUp,
        hs.eventtap.event.types.flagsChanged
    }, processKeyEvent)
    
    -- Start watching
    tapWatcher:start()
    
    -- Create sequence reset timer
    sequenceTimer = hs.timer.new(KeyTapper.sequenceResetDelay, function()
        if #keySequence > 0 and hs.timer.secondsSinceEpoch() - lastSequenceTime > KeyTapper.sequenceResetDelay then
            log.d("Resetting sequence due to inactivity")
            keySequence = {}
        end
    end)
    sequenceTimer:start()
    
    log.d("KeyTapper started")
    
    return self
end

--- KeyTapper:stop()
--- Method
--- Stop monitoring keyboard events
---
--- Parameters:
---  * None
---
--- Returns:
---  * The KeyTapper object
function KeyTapper:stop()
    if tapWatcher then
        tapWatcher:stop()
        tapWatcher = nil
    end
    
    if sequenceTimer then
        sequenceTimer:stop()
        sequenceTimer = nil
    end
    
    log.d("KeyTapper stopped")
    
    return self
end

--- KeyTapper:isRunning()
--- Method
--- Check if KeyTapper is currently running
---
--- Parameters:
---  * None
---
--- Returns:
---  * Boolean indicating whether KeyTapper is running
function KeyTapper:isRunning()
    return tapWatcher ~= nil and tapWatcher:isEnabled()
end

-- Return the module
return KeyTapper
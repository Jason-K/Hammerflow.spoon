--- === jjkHotkeys ===
---
--- A Spoon that unifies multi-tap detection, left/right modifier awareness, layered (recursive) keybindings,
--- and tap-versus-hold logic into a single system. 
--- Users define their actual hotkeys in their master init.lua by calling :bindHotkeys().
---
--- Recognized key names for modifiers:
---   - lshift, rshift
---   - lctrl, rctrl
---   - lcmd, rcmd
---   - lalt, ralt

local obj = {}
obj.__index = obj

----------------------------------------------------------------------
-- METADATA
----------------------------------------------------------------------
obj.name     = "jjkHotkeys"
obj.version  = "0.1"
obj.author   = "YourNameHere"
obj.homepage = "https://github.com/Hammerspoon/Spoons"
obj.license  = "MIT - https://opensource.org/licenses/MIT"

----------------------------------------------------------------------
-- USER-CONFIGURABLE SETTINGS (timeouts, etc.)
----------------------------------------------------------------------
-- Timeout for multi-taps (pressing same key multiple times within this many seconds).
obj.multiTapTimeout = 0.25

-- Timeout for distinguishing tap vs hold (press and release quickly vs. holding down)
obj.tapHoldTimeout = 0.35
obj.holdDelay = 0.35

-- Timeout for waiting between keys in a short combo sequence (e.g., a+b).
obj.combinationTimeout = 0.6

-- Timeout for sequence/layer resets—if too much time passes, we reset the sequence.
obj.sequenceTimeout = 1.0

-- Delay before firing a single-tap action (to allow for double-tap detection)
obj.doubleTapDelay = 0.2

-- Whether or not to log debug output.
obj.debug = false

-- Safe mode - additional error checking
obj.safeMode = true

----------------------------------------------------------------------
-- INTERNAL STATE
----------------------------------------------------------------------
-- We'll store user-supplied definitions in a big table. 
-- The user can add to it by calling :bindHotkeys().
obj.hotkeyDefinitions = {
    taps     = {},
    combos   = {},
    sequences= {},
    layers   = {},
}

-- Below variables support the internal detection logic
local keyState         = {}   -- tracks down vs. up
local pressInProgress  = {}
local holdTimer        = {}
local lastKeyTime      = {}
local keyTapCount      = {}
local masterSequence   = {}
local sequenceTimer    = nil
local activeLayer      = nil
local leftRightModifiers = {} -- tracks which specific left/right modifiers are down
local lastModifierState = {}  -- tracks the previous state of modifiers
local processedSingleTap = {} -- tracks which modifiers have had their single tap processed
local modifierReleaseTimer = {} -- for handling proper single tap timeouts
local keyComboFiredFor = {} -- track which keys have already had combos fired
local modifierPressStartTime = {} -- when modifiers were first pressed
local firedCombos = {} -- track which combos have been fired to prevent duplicates
local regularKeyWasPressed = {} -- track if a regular key was pressed with a modifier
local pendingSingleTaps = {} -- track modifiers with potential single taps
local pendingSingleTapTimers = {} -- timers for delayed single tap processing
local holdFiredFor = {} -- track which modifiers have already fired their hold action

-- watchers
local watchers         = {}
local log = hs.logger.new("jjkHotkeys", "warning")  -- default level "warning"

----------------------------------------------------------------------
-- UTILITY / DEBUG
----------------------------------------------------------------------
local function dbg(fmt, ...)
    if obj.debug then
        log.d(string.format(tostring(fmt), ...))
    end
end

-- Safe function calling with error handling
local function safeCall(func, ...)
    if not func then return nil end
    if type(func) ~= "function" then return nil end
    
    local success, result = pcall(func, ...)
    if not success then
        log.e("Error calling function: " .. tostring(result))
        return nil
    end
    return result
end

-- Retrieve a string name from a numeric keyCode
local function keyNameFromCode(keyCode)
    local nm = hs.keycodes.map[keyCode]
    return nm or ("<unknown:" .. tostring(keyCode) .. ">")
end

-- Get the specific left/right modifier status
local function getLeftRightModifiers(rawFlags)
    if not rawFlags then 
        log.w("getLeftRightModifiers called with nil rawFlags")
        return {} 
    end
    
    local mods = {}
    -- Safely access flag bit masks
    local masks = hs.eventtap.event.rawFlagMasks
    if masks then
        if masks.deviceLeftShift and rawFlags & masks.deviceLeftShift > 0 then mods.lshift = true end
        if masks.deviceRightShift and rawFlags & masks.deviceRightShift > 0 then mods.rshift = true end
        if masks.deviceLeftControl and rawFlags & masks.deviceLeftControl > 0 then mods.lctrl = true end
        if masks.deviceRightControl and rawFlags & masks.deviceRightControl > 0 then mods.rctrl = true end
        if masks.deviceLeftCommand and rawFlags & masks.deviceLeftCommand > 0 then mods.lcmd = true end
        if masks.deviceRightCommand and rawFlags & masks.deviceRightCommand > 0 then mods.rcmd = true end
        if masks.deviceLeftAlternate and rawFlags & masks.deviceLeftAlternate > 0 then mods.lalt = true end
        if masks.deviceRightAlternate and rawFlags & masks.deviceRightAlternate > 0 then mods.ralt = true end
    else
        log.w("hs.eventtap.event.rawFlagMasks not available")
    end
    return mods
end

local function resetSequence(reason)
    masterSequence = {}
    if activeLayer then
        dbg("Leaving layer '%s' (reason: %s)", activeLayer, reason or "")
        activeLayer = nil
    end
end

-- Cancel pending single tap for a modifier
local function cancelPendingSingleTap(mod)
    if not mod then return end
    
    if pendingSingleTapTimers[mod] then
        pendingSingleTapTimers[mod]:stop()
            if keyTapCount[keyName] == 1 then
                definition = tapDefs.single
                if type(definition) == "function" then
                    definition()
                elseif type(definition) == "table" and definition.layer then
                    activeLayer = definition.layer
                    if definition.message then hs.alert.show(definition.message) end
                elseif definition then
                    dbg("Tap: found definition with unrecognized type: " .. type(definition))
                else
                    dbg("No matching tap definition for key=%s taps=%d hold=%s", keyName, nTaps, tostring(isHold))
                end
            end
        end)
    elseif nTaps == 2 then
        definition = isHold and tapDefs.doubleHold or tapDefs.double
        keyTapCount[keyName] = 0 -- Reset tap count after handling double tap
    elseif isHold then
        definition = tapDefs.hold
    end

    if type(definition) == "function" then
        definition()
    elseif type(definition) == "table" and definition.layer then
        activeLayer = definition.layer
        if definition.message then hs.alert.show(definition.message) end
    elseif definition then
        dbg("Tap: found definition with unrecognized type: " .. type(definition))
    else
        dbg("No matching tap definition for key=%s taps=%d hold=%s", keyName, nTaps, tostring(isHold))
    end
end

local function handleCombo(keyName)
    -- Create a string representing currently active modifiers
    local activeModsStr = ""
    for mod, isActive in pairs(leftRightModifiers) do
        if isActive then
            activeModsStr = activeModsStr .. mod .. "+"
        end
    end
    
    -- If no combos defined for this key, bail early
    if not obj.hotkeyDefinitions.combos[keyName] then
        return false
    end
    
    -- Check for exact combo matches first (e.g., "lcmd+lalt+lctrl")
    for comboSpec, action in pairs(obj.hotkeyDefinitions.combos[keyName]) do
        -- Skip patterns with tap number suffixes - they're handled on key down
        local hasTapCount = false
        if type(comboSpec) == "string" then
            hasTapCount = string.match(comboSpec, "%d+$") ~= nil
        end
        
        if not hasTapCount then
            -- Safe string comparison - prevent nil errors
            local comboWithPlus = comboSpec .. "+"
            if activeModsStr == comboWithPlus then
                action()
                return true
            end
        end
    end
    
    return false
end

local function handleSequence(seq)
    local seqStr = table.concat(seq, ",")
    -- 1) Check global sequences
    for _, seqDef in pairs(obj.hotkeyDefinitions.sequences) do
        if seqStr == table.concat(seqDef.sequence, ",") then
            if type(seqDef.action) == "function" then
                seqDef.action()
            end
            resetSequence("global sequence matched")
            return
        end
    end

    -- 2) Check if activeLayer has sequences
    if activeLayer then
        local layerDef = obj.hotkeyDefinitions.layers[activeLayer]
        if layerDef and layerDef.sequences then
            for _, seqDef in pairs(layerDef.sequences) do
                if seqStr == table.concat(seqDef.sequence, ",") then
                    if type(seqDef.action) == "function" then
                        seqDef.action()
                    end
                    resetSequence("layer sequence matched")
                    return
                end
            end
        end
    end
end

----------------------------------------------------------------------
-- EVENT CALLBACK
-- We handle keyDown, keyUp, and flagsChanged. Distinguish tap vs hold, 
-- single vs multi-tap, left vs right modifiers, track sequences, etc.
----------------------------------------------------------------------

local function flagsChangedCallback(evt)
    -- Update our left/right modifier tracking
    local rawFlags = evt:getRawEventData().CGEventData.flags
    local newModifiers = getLeftRightModifiers(rawFlags)
    local modChanges = {}
    local now = hs.timer.secondsSinceEpoch()
    
    -- Find which modifiers were pressed or released
    for mod, _ in pairs(newModifiers) do
        if newModifiers[mod] and not leftRightModifiers[mod] then
            modChanges[mod] = "pressed"
            modifierPressStartTime[mod] = now
        end
    end
    
    for mod, _ in pairs(leftRightModifiers) do
        if not newModifiers[mod] then
            modChanges[mod] = "released"
        end
    end
    
    -- Update our tracking state
    leftRightModifiers = newModifiers
    
    -- Reset tracking when modifiers change
    if next(modChanges) then
        -- Only reset fired combos for modifiers that changed
        for mod, _ in pairs(modChanges) do
            for comboId, _ in pairs(firedCombos or {}) do
                if comboId and comboId:find(mod) then
                    firedCombos[comboId] = nil
                end
            end
        end
    end
    
    -- Handle pressed modifiers
    for mod, change in pairs(modChanges) do
        if change == "pressed" then
            dbg("%s pressed", mod)
            
            -- Reset tracking for this modifier
            regularKeyWasPressed[mod] = false
            holdFiredFor[mod] = false
            
            -- Cancel any pending single tap for this modifier
            cancelPendingSingleTap(mod)
            
            -- Count taps within timeout window
            if lastKeyTime[mod] and (now - lastKeyTime[mod]) <= obj.multiTapTimeout then
                keyTapCount[mod] = (keyTapCount[mod] or 0) + 1
                dbg("%s tapped %d times", mod, keyTapCount[mod])
                
                -- Handle double-tap immediately when detected
                if keyTapCount[mod] == 2 then
                    -- Improved double-tap detection
                    local modTaps = obj.hotkeyDefinitions.modTaps
                    if modTaps and modTaps[mod] and modTaps[mod].double then
                        dbg("Double-tap detected - calling ClipboardFormatter:formatSelection()")
                        modTaps[mod].double()
                        processedSingleTap[mod] = true
                        keyTapCount[mod] = 0 -- Reset count after handling
                    end
                end
            else
                keyTapCount[mod] = 1
                dbg("First tap of %s", mod)
            end
            
            -- Update timing tracking
            lastKeyTime[mod] = now
            pressInProgress[mod] = true
            
            -- Set up hold timer
            if holdTimer[mod] then
                holdTimer[mod]:stop()
                holdTimer[mod] = nil
            end
            
            holdTimer[mod] = hs.timer.doAfter(obj.holdDelay or obj.tapHoldTimeout, function()
                -- Only trigger hold if:
                -- 1. Modifier is still pressed
                -- 2. No regular key was pressed with this modifier
                -- 3. We haven't already fired the hold action for this press
                if pressInProgress[mod] and leftRightModifiers[mod] and 
                   not regularKeyWasPressed[mod] and not holdFiredFor[mod] then
                    local modTaps = obj.hotkeyDefinitions.modTaps
                    if modTaps and modTaps[mod] and modTaps[mod].hold then
                        dbg("Executing hold for %s", mod)
                        modTaps[mod].hold()
                        processedSingleTap[mod] = true
                        holdFiredFor[mod] = true
                    end
                end
            end)
            
        elseif change == "released" then
            dbg("%s released", mod)
            
            -- Cancel hold timer
            if holdTimer[mod] then
                holdTimer[mod]:stop()
                holdTimer[mod] = nil
            end
            
            -- Calculate press duration
            local pressDuration = now - (modifierPressStartTime[mod] or 0)
            dbg("%s was pressed for %.2f seconds", mod, pressDuration)
            
            -- Only consider single tap if:
            -- 1. Press was quick (not a hold)
            -- 2. No regular key was pressed with this modifier
            -- 3. Not already processed as part of double-tap
            -- 4. It's the first tap (tap count is 1)
            if pressDuration < obj.tapHoldTimeout and not regularKeyWasPressed[mod] and 
               not processedSingleTap[mod] and keyTapCount[mod] == 1 then
                
                -- Set up a delayed timer for single tap processing
                -- This gives us time to see if a second tap comes in
                pendingSingleTaps[mod] = true
                
                if pendingSingleTapTimers[mod] then
                    pendingSingleTapTimers[mod]:stop()
                end
                
                pendingSingleTapTimers[mod] = hs.timer.doAfter(obj.doubleTapDelay or obj.multiTapTimeout, function()
                    -- Only execute if still pending and no second tap came in
                    if pendingSingleTaps[mod] then
                        local modTaps = obj.hotkeyDefinitions.modTaps
                        if modTaps and modTaps[mod] and modTaps[mod].single then
                            dbg("Executing delayed single tap for %s", mod)
                            modTaps[mod].single()
                        end
                        pendingSingleTaps[mod] = nil
                    end
                end)
            end
            
            pressInProgress[mod] = false
            processedSingleTap[mod] = false
            regularKeyWasPressed[mod] = false
            holdFiredFor[mod] = false
        end
    end
    
    return false
end

local function keyEventCallback(evt)
    local etype = evt:getType()
    
    if etype == hs.eventtap.event.types.flagsChanged then
        return flagsChangedCallback(evt)
    end
    
    if etype ~= hs.eventtap.event.types.keyDown and etype ~= hs.eventtap.event.types.keyUp then
        return false
    end
    
    local now = hs.timer.secondsSinceEpoch()
    local keyCode = evt:getKeyCode()
    local keyName = keyNameFromCode(keyCode)
    local isDown = (etype == hs.eventtap.event.types.keyDown)
    
    -- Update left/right modifier state for any key event
    local rawFlags = evt:getRawEventData().CGEventData.flags
    leftRightModifiers = getLeftRightModifiers(rawFlags)
    
    if isDown then
        -- Key down logic
        dbg("Key down: %s", keyName)
        
        -- Mark that regular keys are being pressed with modifiers
        -- Also cancel any pending single tap actions and hold timers for these modifiers
        for mod, _ in pairs(leftRightModifiers) do
            cancelHoldTimer(mod) -- This now handles marking regularKeyWasPressed and canceling the timer
            cancelPendingSingleTap(mod)
        end
        
        if lastKeyTime[keyName] and (now - lastKeyTime[keyName]) <= obj.multiTapTimeout then
            keyTapCount[keyName] = (keyTapCount[keyName] or 0) + 1
            dbg("%s tapped %d times", keyName, keyTapCount[keyName])
        else
            keyTapCount[keyName] = 1
        end
        
        lastKeyTime[keyName] = now
        pressInProgress[keyName] = true
        
        -- Set up hold detection
        if holdTimer[keyName] then 
            holdTimer[keyName]:stop() 
        end
        
        holdTimer[keyName] = hs.timer.doAfter(obj.tapHoldTimeout, function()
            if pressInProgress[keyName] then
                handleTap(keyName, keyTapCount[keyName], true)
            end
        end)
        
        -- Check for combo matches that need to be handled on key down
        if next(leftRightModifiers) then
            -- For key down events, only handle certain combos (like double-tapping 'f' with cmd held)
            for comboSpec, action in pairs(obj.hotkeyDefinitions.combos[keyName] or {}) do
                -- Check for tap number suffix (e.g., lcmd2)
                if comboSpec:match("%d+$") then
                    local mod, tapCount = comboSpec:match("(.*)(%d+)$")
                    tapCount = tonumber(tapCount)
                    
                    if leftRightModifiers[mod] and keyTapCount[keyName] == tapCount then
                        dbg("Multi-tap combo matched: %s%d", mod, tapCount)
                        
                        -- Cancel hold and single tap for all modifiers
                        for usedMod, _ in pairs(leftRightModifiers) do
                            cancelHoldTimer(usedMod)
                            cancelPendingSingleTap(usedMod)
                        end
                        
                        -- Create tracking ID and record that it fired
                        local activeModsStr = ""
                        for activeMod, isActive in pairs(leftRightModifiers) do
                            if isActive then
                                activeModsStr = activeModsStr .. activeMod .. "+"
                            end
                        end
                        activeModsStr = activeModsStr .. keyName
                        
                        firedCombos[activeModsStr] = firedCombos[activeModsStr] or {}
                        firedCombos[activeModsStr][tapCount] = true
                        
                        action()
                        return false
                    end
                end
            end
        end
        
        -- Prevent single-tap combo from firing if multi-tap combo is detected
        if keyTapCount[keyName] > 1 then
            return false
        end
        
    else -- Key up
        dbg("Key up: %s", keyName)
        pressInProgress[keyName] = false
        
        -- Stop hold timer
        if holdTimer[keyName] then
            holdTimer[keyName]:stop()
            holdTimer[keyName] = nil
        end
        
        -- Calculate if this was a tap or hold
        local pressDuration = now - (lastKeyTime[keyName] or 0)
        local wasHold = pressDuration >= obj.tapHoldTimeout
        
        if not wasHold then
            -- Regular tap handling
            handleTap(keyName, keyTapCount[keyName], false)
        end
        
        -- Check for combos on key up, but only for single taps (not multi-taps)
        if next(leftRightModifiers) and keyTapCount[keyName] == 1 then
            if handleCombo(keyName) then
                dbg("Combo handled for %s", keyName)
            end
        end
        
        -- Add to sequence tracking
        table.insert(masterSequence, keyName)
        if sequenceTimer then sequenceTimer:stop() end
        sequenceTimer = hs.timer.doAfter(obj.sequenceTimeout, function()
            resetSequence("sequence timeout")
        end)
        
        -- Check for sequence matches
        handleSequence(masterSequence)
    end
    
    return false
end

----------------------------------------------------------------------
-- SPOON INTERFACE
----------------------------------------------------------------------

--- jjkHotkeys:bindHotkeys(userTable)
--- Method
--- Merges user-supplied definitions into `obj.hotkeyDefinitions`.
--- The structure is up to you, but typically:
--- {
---   taps = {
---     ["a"] = {
---       single = function(), double = function(), hold = function() end,
---     },
---   },
---   combos = {
---     ["v"] = {
---       "lcmd+lshift" = function() ... end,  -- Only if left cmd AND left shift are down
---       "rcmd" = function() ... end,         -- Only if right cmd is down
---     },
---     ["f"] = {
---       "lcmd" = function() ... end,         -- Single tap of 'f' with left cmd
---       "lcmd2" = function() ... end,        -- Double tap of 'f' with left cmd
---     },
---   },
---   modTaps = {
---     ["lcmd"] = {
---       double = function() ... end,  -- Double-tap left command
---       single = function() ... end,  -- Single-tap left command
---       hold = function() ... end,    -- Hold left command
---     },
---   },
---   sequences = {
---     myseq = { sequence = {"a","b"}, action = function() ... end }
---   },
---   layers = {
---     myLayer = {
---       sequences = {
---         { sequence={"x","y"}, action=function() ... end }
---       }
---     }
---   },
--- }
function obj:bindHotkeys(userDefs)
  if userDefs.taps then
    for k,v in pairs(userDefs.taps) do
      self.hotkeyDefinitions.taps[k] = v
    end
  end
  if userDefs.combos then
    for k,v in pairs(userDefs.combos) do
      self.hotkeyDefinitions.combos[k] = v
    end
  end
  if userDefs.modTaps then
    self.hotkeyDefinitions.modTaps = userDefs.modTaps
  end
  if userDefs.sequences then
    for name,def in pairs(userDefs.sequences) do
      self.hotkeyDefinitions.sequences[name] = def
    end
  end
  if userDefs.layers then
    for ln,ldef in pairs(userDefs.layers) do
      self.hotkeyDefinitions.layers[ln] = ldef
    end
  end
  return self
end

--- jjkHotkeys:start()
--- Method
--- Start the keyboard eventtap for managing taps, combos, etc.
function obj:start()
    if watchers.keyboard then watchers.keyboard:stop() watchers.keyboard = nil end

    watchers.keyboard = hs.eventtap.new({
        hs.eventtap.event.types.keyDown,
        hs.eventtap.event.types.keyUp,
        hs.eventtap.event.types.flagsChanged  -- Important for left/right modifier detection
    }, keyEventCallback)
    watchers.keyboard:start()

    -- Reset all state variables
    keyState = {}
    pressInProgress = {}
    holdTimer = {}
    lastKeyTime = {}
    keyTapCount = {}
    masterSequence = {}
    leftRightModifiers = {}
    lastModifierState = {}
    processedSingleTap = {}
    modifierReleaseTimer = {}
    keyComboFiredFor = {}
    modifierPressStartTime = {}
    firedCombos = {}
    regularKeyWasPressed = {}
    pendingSingleTaps = {}
    pendingSingleTapTimers = {}
    holdFiredFor = {}
    
    dbg("jjkHotkeys started")
    return self
end

--- jjkHotkeys:stop()
--- Method
--- Stop the watchers/timers. No hotkey logic recognized until restarted.
function obj:stop()
    if watchers.keyboard then
        watchers.keyboard:stop()
        watchers.keyboard = nil
    end
    
    -- Stop all timers
    if sequenceTimer then sequenceTimer:stop() end
    
    for _, timer in pairs(holdTimer) do
        if timer then timer:stop() end
    end
    
    for _, timer in pairs(modifierReleaseTimer) do
        if timer then timer:stop() end
    end
    
    for _, timer in pairs(pendingSingleTapTimers) do
        if timer then timer:stop() end
    end
    
    -- Reset all state
    sequenceTimer = nil
    holdTimer = {}
    modifierReleaseTimer = {}
    masterSequence = {}
    leftRightModifiers = {}
    keyTapCount = {}
    firedCombos = {}
    regularKeyWasPressed = {}
    pendingSingleTaps = {}
    pendingSingleTapTimers = {}
    holdFiredFor = {}
    return self
end

--- jjkHotkeys:toggleDebug(enabled)
--- Method
--- Enable or disable debug logging for this spoon
function obj:toggleDebug(enabled)
    self.debug = enabled and true or false
    log.setLogLevel(self.debug and "debug" or "warning")
    return self
end

-- Add these methods near the top of the file, after the object declaration
function obj:setSafeMode(enabled)
  self.safeMode = enabled
  return self
end

-- Modify the handleKeyEvent function (around line 464) to include nil checks
-- Replace the relevant section with:
function obj:handleKeyEvent(event)
  -- ...existing code...
  
  -- Add safe string pattern matching
  local function safeMatch(str, pattern)
    if not str or type(str) ~= "string" then
      self.log.d("Warning: Attempted to match on nil or non-string value")
      return false
    end
    return string.match(str, pattern)
  end
  
  -- When processing key events, replace any direct calls to match() with safeMatch()
  -- For example, if the code has something like:
  -- if someString:match(pattern) then
  -- Replace with:
  -- if safeMatch(someString, pattern) then
  
  -- ...existing code...
end

return obj
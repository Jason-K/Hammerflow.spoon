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

-- Retrieve a string name from a numeric keyCode
local function keyNameFromCode(keyCode)
    local nm = hs.keycodes.map[keyCode]
    return nm or ("<unknown:" .. tostring(keyCode) .. ">")
end

-- Get the specific left/right modifier status
local function getLeftRightModifiers(rawFlags)
    local mods = {}
    if rawFlags & hs.eventtap.event.rawFlagMasks.deviceLeftShift > 0 then mods.lshift = true end
    if rawFlags & hs.eventtap.event.rawFlagMasks.deviceRightShift > 0 then mods.rshift = true end
    if rawFlags & hs.eventtap.event.rawFlagMasks.deviceLeftControl > 0 then mods.lctrl = true end
    if rawFlags & hs.eventtap.event.rawFlagMasks.deviceRightControl > 0 then mods.rctrl = true end
    if rawFlags & hs.eventtap.event.rawFlagMasks.deviceLeftCommand > 0 then mods.lcmd = true end
    if rawFlags & hs.eventtap.event.rawFlagMasks.deviceRightCommand > 0 then mods.rcmd = true end
    if rawFlags & hs.eventtap.event.rawFlagMasks.deviceLeftAlternate > 0 then mods.lalt = true end
    if rawFlags & hs.eventtap.event.rawFlagMasks.deviceRightAlternate > 0 then mods.ralt = true end
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
    if pendingSingleTapTimers[mod] then
        pendingSingleTapTimers[mod]:stop()
        pendingSingleTapTimers[mod] = nil
    end
    pendingSingleTaps[mod] = nil
end

-- Cancel hold timer for a modifier and mark it as used with a regular key
local function cancelHoldTimer(mod)
    if holdTimer[mod] then
        holdTimer[mod]:stop()
        holdTimer[mod] = nil
    end
    holdFiredFor[mod] = nil
    regularKeyWasPressed[mod] = true
end

----------------------------------------------------------------------
-- LOOKUP AND INVOKE FUNCTIONS
-- These read from obj.hotkeyDefinitions to find an appropriate action
-- for taps, combos, sequences, etc.
----------------------------------------------------------------------

local function handleTap(keyName, nTaps, isHold)
    local tapDefs = obj.hotkeyDefinitions.taps[keyName]
    if not tapDefs then return end

    local definition
    if nTaps == 1 and not isHold then
        -- Add a delay before executing the single-tap action to check for double-tap
        hs.timer.doAfter(obj.multiTapTimeout, function()
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
  local comboDefs = obj.hotkeyDefinitions.combos[keyName]
  if not comboDefs then return false end

  -- Collect active left/right modifiers into a string (e.g. "lcmd+rctrl")
  local activeMods = {}
  for mod, isActive in pairs(leftRightModifiers) do
    if isActive then table.insert(activeMods, mod) end
  end
  local comboKey = table.concat(activeMods, "+")

  if keyTapCount[keyName] == 1 then
    -- Wait multiTapTimeout before firing a single press
    hs.timer.doAfter(obj.multiTapTimeout, function()
      if keyTapCount[keyName] == 1 then
        local singleAction = comboDefs[comboKey]
        if type(singleAction) == "function" then
          singleAction()
        end
        keyTapCount[keyName] = 0
      end
    end)
  elseif keyTapCount[keyName] == 2 then
    -- Double pressed within multiTapTimeout
    local doubleAction = comboDefs[comboKey .. "2"]
    if type(doubleAction) == "function" then
      doubleAction()
    end
    keyTapCount[keyName] = 0
  end

  return true
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

return obj
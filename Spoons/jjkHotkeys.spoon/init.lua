--- === jjkHotkeys ===
---
--- A Spoon that unifies multi-tap detection, left/right modifier awareness, layered (recursive) keybindings,
--- and tap-versus-hold logic into a single system. 
--- Users define their actual hotkeys in their master init.lua by calling :bindHotkeys().

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
obj.multiTapTimeout = 0.4

-- Timeout for distinguishing tap vs hold (press and release quickly vs. holding down)
obj.tapHoldTimeout = 0.35

-- Timeout for waiting between keys in a short combo sequence (e.g., a+b).
obj.combinationTimeout = 0.6

-- Timeout for sequence/layer resets—if too much time passes, we reset the sequence.
obj.sequenceTimeout = 1.0

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
        definition = tapDefs.single
    elseif nTaps == 2 then
        definition = isHold and tapDefs.doubleHold or tapDefs.double
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
    -- This function now uses leftRightModifiers to check for specific left/right modifiers
    local combo = obj.hotkeyDefinitions.combos[keyName]
    if not combo then return end
    
    -- Look for patterns like "lcmd+v", "rshift+a", etc.
    for comboSpec, action in pairs(combo) do
        local requiredMods = {}
        for mod in comboSpec:gmatch("[^+]+") do
            requiredMods[mod] = true
        end
        
        -- Check if all required modifiers are active and no extra ones
        local allMatch = true
        for mod, _ in pairs(requiredMods) do
            if not leftRightModifiers[mod] then
                allMatch = false
                break
            end
        end
        
        if allMatch then
            if type(action) == "function" then
                action()
                return
            end
        end
    end
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
    leftRightModifiers = getLeftRightModifiers(rawFlags)
    
    -- If there's a key in the combo definitions that matches just these modifiers,
    -- handle it (e.g., for double-tap of cmd key alone)
    local activeModCount = 0
    local lastActiveMod = nil
    for mod, active in pairs(leftRightModifiers) do
        if active then
            activeModCount = activeModCount + 1
            lastActiveMod = mod
        end
    end
    
    -- If there's exactly one modifier, check for double-taps of that modifier
    if activeModCount == 1 and lastActiveMod then
        local dt = hs.timer.secondsSinceEpoch() - (lastKeyTime[lastActiveMod] or 0)
        if dt <= obj.multiTapTimeout then
            keyTapCount[lastActiveMod] = (keyTapCount[lastActiveMod] or 0) + 1
            if keyTapCount[lastActiveMod] == 2 then
                -- Double-tap of a modifier key alone
                local modTaps = obj.hotkeyDefinitions.modTaps
                if modTaps and modTaps[lastActiveMod] and modTaps[lastActiveMod].double then
                    modTaps[lastActiveMod].double()
                end
            end
        else
            keyTapCount[lastActiveMod] = 1
        end
        lastKeyTime[lastActiveMod] = hs.timer.secondsSinceEpoch()
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

    local now     = hs.timer.secondsSinceEpoch()
    local keyCode = evt:getKeyCode()
    local keyName = keyNameFromCode(keyCode)
    local isDown  = (etype == hs.eventtap.event.types.keyDown)
    
    -- Update left/right modifier state for any key event too
    local rawFlags = evt:getRawEventData().CGEventData.flags
    leftRightModifiers = getLeftRightModifiers(rawFlags)

    if isDown then
        local dt = now - (lastKeyTime[keyName] or 0)
        if dt > obj.multiTapTimeout then
            keyTapCount[keyName] = 1
        else
            keyTapCount[keyName] = (keyTapCount[keyName] or 0) + 1
        end

        pressInProgress[keyName] = true
        lastKeyTime[keyName]     = now

        if holdTimer[keyName] then holdTimer[keyName]:stop() end
        holdTimer[keyName] = hs.timer.doAfter(obj.tapHoldTimeout, function()
            if pressInProgress[keyName] then
                -- The user held the key
                handleTap(keyName, keyTapCount[keyName], true)
            end
        end)
    else
        -- keyUp
        pressInProgress[keyName] = false
        if holdTimer[keyName] then
            holdTimer[keyName]:stop()
            holdTimer[keyName] = nil
        end

        local downTime = lastKeyTime[keyName] or 0
        local pressedDuration = (now - downTime)

        local wasHold = (pressedDuration >= obj.tapHoldTimeout)
        if not wasHold then
            -- treat as a quick tap
            handleTap(keyName, keyTapCount[keyName], false)
        end

        -- Check for combos (e.g., lcmd+v)
        if next(leftRightModifiers) ~= nil then
            handleCombo(keyName)
        end

        -- Add to sequence
        table.insert(masterSequence, keyName)
        if sequenceTimer then sequenceTimer:stop() end
        sequenceTimer = hs.timer.doAfter(obj.sequenceTimeout, function()
            resetSequence("sequence timeout")
        end)
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
---   },
---   modTaps = {
---     ["lcmd"] = {
---       double = function() ... end,  -- Double-tap left command
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
    if sequenceTimer then sequenceTimer:stop() end
    sequenceTimer = nil
    masterSequence = {}
    leftRightModifiers = {}
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
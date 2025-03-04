local M = {}

-- Create a logger instance for this module
M.logger = hs.logger.new('menuHelper', 'debug')

-- Debug state
M.debug = false

-- Debug logging helper
local function debugLog(fmt, ...)
    if M.debug then
        local msg = string.format(fmt, ...)
        M.logger.d(msg)
        print(msg)  -- Print to console
        hs.alert(msg, 1)  -- Show brief overlay alert
    end
end

-- Table to store menu items
M.menuItems = {
    ["aas\\"] = {"Applicant's Attorney's", "Applicant's attorneys", "applicants' attorneys", "applicants' attorneys'"},
    ["aa\\"] = {"Applicant's Attorney", "applicants' attorney"},
    ["ames\\"] = {"Agreed Medical Evaluator's", "agreed medical evaluators", "agreed medical evaluator's", "agreed medical evaluators'"},
    ["ame\\"] = {"Agreed Medical Evaluator", "agreed medical evaluator"},
    -- Port your existing menu items here
}

function M.init()
    debugLog("Initializing menuHelper...")
    
    M.keyWatcher = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
        local flags = event:getFlags()
        local keyCode = event:getKeyCode()
        local char = hs.keycodes.map[keyCode]
        
        if char == "\\" then
            debugLog("Backslash detected, checking for menu trigger")
            local lastWord = M.getLastWord()
            debugLog("Last word before backslash: [%s]", lastWord or "nil")
            
            if lastWord and M.menuItems[lastWord .. "\\"] then
                debugLog("Found menu trigger: [%s]", lastWord)
                M.showTextMenu()
                return true
            end
        end
        
        return false
    end)

    debugLog("Starting key watcher")
    M.keyWatcher:start()
    debugLog("MenuHelper initialization complete!")
end

function M.getLastWord()
    debugLog("Getting last word")
    -- Save current clipboard
    local oldClipboard = hs.pasteboard.getContents()
    
    -- Select last word
    hs.eventtap.keyStroke({'ctrl'}, 'left')
    hs.eventtap.keyStroke({'ctrl', 'shift'}, 'right')
    
    -- Copy selection
    hs.eventtap.keyStroke({'cmd'}, 'c')
    hs.timer.usleep(100000) -- Wait 100ms for clipboard
    
    local selectedText = hs.pasteboard.getContents()
    debugLog("Selected text: [%s]", selectedText or "nil")
    
    -- Restore clipboard
    if oldClipboard then
        hs.pasteboard.setContents(oldClipboard)
    end
    
    return selectedText
end

function M.replaceText(trigger, replacement)
    debugLog("Replacing [%s] with [%s]", trigger, replacement)
    -- Delete the trigger text
    for i = 1, #trigger do
        hs.eventtap.keyStroke({}, 'delete')
    end
    
    -- Type the replacement text
    hs.eventtap.keyStrokes(replacement)
    debugLog("Replacement complete")
end

function M.showTextMenu()
    local lastWord = M.getLastWord()
    if not lastWord then 
        debugLog("No word selected")
        return 
    end
    
    debugLog("Showing menu for word: [%s]", lastWord)
    lastWord = lastWord .. "\\"
    
    if M.menuItems[lastWord] then
        debugLog("Found menu items for [%s]", lastWord)
        local items = {}
        for i, text in ipairs(M.menuItems[lastWord]) do
            table.insert(items, {
                title = string.format("%d %s", i, text),
                fn = function() 
                    debugLog("Selected menu item: [%s]", text)
                    M.replaceText(lastWord, text)
                    -- Add a space after replacement if it doesn't end with one
                    if not text:match("%s$") then
                        hs.eventtap.keyStrokes(" ")
                    end
                end
            })
        end
        
        local screen = hs.screen.mainScreen()
        local frame = screen:frame()
        local mousePoint = hs.mouse.getAbsolutePosition()
        
        -- Show menu at mouse position
        local menu = hs.menu.new(items):popupMenu(mousePoint)
    else
        debugLog("No menu items found for [%s]", lastWord)
    end
end

return M
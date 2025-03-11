--- === jjkUserScripts ===
---
--- A collection of user scripts for Hammerspoon
---
--- Download: [https://github.com/yourusername/jjkUserScripts.spoon](https://github.com/yourusername/jjkUserScripts.spoon)
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "jjkUserScripts"
obj.version = "1.0"
obj.author = "jjk"
obj.homepage = "https://github.com/yourusername/jjkUserScripts.spoon"
obj.license = "MIT - https://opensource.org/licenses/MIT"

--- jjkUserScripts:init()
--- Method
--- Initialize the spoon
function obj:init()
    self.logger = hs.logger.new('jjkUserScripts', 'info')
    return self
end

--- jjkUserScripts:start()
--- Method
--- Start the spoon functionality
function obj:start()
    return self
end

--- jjkUserScripts:stop()
--- Method
--- Stop the spoon functionality
function obj:stop()
    return self
end

--- jjkUserScripts:bindHotkeys(mapping)
--- Method
--- Binds hotkeys for jjkUserScripts
---
--- Parameters:
---  * mapping - A table containing hotkey assignments
function obj:bindHotkeys(mapping)
    local spec = {
        search_or_open = hs.fnutils.partial(self.doSearchOrOpen, self)
    }

    hs.spoons.bindHotkeysToSpec(spec, mapping)
    return self
end

--- jjkUserScripts:getSelectedText()
--- Method
--- Gets the currently selected text using a sequential approach that ensures reliable capture
function obj:getSelectedText()
    -- Save original clipboard
    local originalClipboard = hs.pasteboard.getContents()
    local originalChangeCount = hs.pasteboard.changeCount()

    -- First, ensure we have a clean state for the clipboard operation
    hs.pasteboard.clearContents()
    
    -- We'll try multiple methods in sequence to ensure text is captured
    local selectedText = nil
    
    -- Method 1: Direct key event approach with precise timing
    local function tryCopyViaKeyEvents()
        -- Release any modifiers that might be down
        hs.eventtap.keyStroke({}, "escape", 0) -- Press escape to clear any partial states
        hs.timer.usleep(50000) -- 50ms pause
        
        -- Force all modifiers to be released
        local modifiers = {"cmd", "alt", "ctrl", "shift"}
        for _, mod in ipairs(modifiers) do
            hs.eventtap.event.newKeyEvent(mod, false):post()
        end
        hs.timer.usleep(50000) -- 50ms pause
        
        -- Execute cmd+c using key stroke with proper timing
        hs.eventtap.keyStroke({"cmd"}, "c", 100000) -- 100ms delay in keystroke
        
        -- Wait for clipboard to update
        local startTime = hs.timer.secondsSinceEpoch()
        while (hs.pasteboard.changeCount() == originalChangeCount) and 
              (hs.timer.secondsSinceEpoch() - startTime < 0.5) do
            hs.timer.usleep(10000) -- 10ms pause
        end
        
        return hs.pasteboard.getContents()
    end
    
    -- Method 2: AppleScript approach which can sometimes work better
    local function tryCopyViaAppleScript()
        hs.pasteboard.clearContents() -- Start with a clear clipboard
        
        local success = hs.osascript.applescript([[
            tell application "System Events"
                keystroke "c" using {command down}
                delay 0.1
            end tell
            return true
        ]])
        
        -- Wait for clipboard to update
        local startTime = hs.timer.secondsSinceEpoch()
        while (hs.pasteboard.changeCount() == originalChangeCount) and 
              (hs.timer.secondsSinceEpoch() - startTime < 0.5) do
            hs.timer.usleep(10000) -- 10ms pause
        end
        
        return hs.pasteboard.getContents()
    end
    
    -- Method 3: Low-level event approach with careful sequencing
    local function tryCopyViaLowLevelEvents()
        hs.pasteboard.clearContents() -- Start with a clear clipboard
        
        -- Sequence of events with proper timing
        local cmdDown = hs.eventtap.event.newKeyEvent("cmd", true)
        cmdDown:post()
        hs.timer.usleep(100000) -- 100ms pause
        
        local cDown = hs.eventtap.event.newKeyEvent("c", true)
        cDown:post()
        hs.timer.usleep(100000) -- 100ms pause
        
        local cUp = hs.eventtap.event.newKeyEvent("c", false)
        cUp:post()
        hs.timer.usleep(100000) -- 100ms pause
        
        local cmdUp = hs.eventtap.event.newKeyEvent("cmd", false)
        cmdUp:post()
        hs.timer.usleep(100000) -- 100ms pause
        
        -- Wait for clipboard to update
        local startTime = hs.timer.secondsSinceEpoch()
        while (hs.pasteboard.changeCount() == originalChangeCount) and 
              (hs.timer.secondsSinceEpoch() - startTime < 0.5) do
            hs.timer.usleep(10000) -- 10ms pause
        end
        
        return hs.pasteboard.getContents()
    end
    
    -- Try all methods in sequence until one succeeds
    selectedText = tryCopyViaKeyEvents() or tryCopyViaAppleScript() or tryCopyViaLowLevelEvents()
    
    -- Restore original clipboard regardless of success
    if originalClipboard then
        hs.pasteboard.setContents(originalClipboard)
    end
    
    -- Validate we got something useful
    if selectedText and selectedText ~= "" then
        return selectedText
    else
        return nil
    end
end

--- jjkUserScripts:searchOrOpen()
--- Method
--- Gets the currently selected text and decides whether to open it as URL, file path, or search term
function obj:searchOrOpen()
    -- Get selected text (no permission check needed)
    local query = self:getSelectedText()
    
    if not query or query == "" then
        hs.alert.show("No text selected")
        return
    end
    
    -- Trim whitespace
    query = string.gsub(query, "^%s*(.-)%s*$", "%1")
    
    -- Check if it's a URL - more comprehensive pattern matching
    local isUrl = string.match(query, "^https?://") or 
                  string.match(query, "^ftp://") or
                  string.match(query, "^www%..*%.%w%w%w?%w?") or
                  string.match(query, "^%w+%.%w+%.%w%w%w?%w?")
    
    -- Check if it's a file path - try to expand ~ if present
    if string.sub(query, 1, 1) == "~" then
        query = os.getenv("HOME") .. string.sub(query, 2)
    end
    
    local isFilePath = false
    if hs.fs.attributes(query) then
        isFilePath = true
    end
    
    if isUrl then
        -- Ensure URL has http:// prefix if needed
        if not string.match(query, "^https?://") and not string.match(query, "^ftp://") then
            query = "https://" .. query
        end
        
        -- Open URL in default browser
        hs.urlevent.openURL(query)
        hs.alert.show("Opening URL: " .. query:sub(1, 30) .. (query:len() > 30 and "..." or ""))
    elseif isFilePath then
        -- Show file in Finder
        -- Use a more reliable method to show in Finder
        if hs.fs.attributes(query, "mode") == "directory" then
            hs.execute(string.format('open "%s"', query:gsub('"', '\\"')))
        else
            hs.execute(string.format('open -R "%s"', query:gsub('"', '\\"')))
        end
        hs.alert.show("Showing in Finder: " .. query:sub(1, 30) .. (query:len() > 30 and "..." or ""))
    else
        -- Search with Kagi
        local encodedQuery = hs.http.encodeForQuery(query)
        local searchUrl = "https://kagi.com/search?token=OQAAbI3-hQc.kA0S3yiqeGqlCRp-6J3QiSQ3dY_npYD4drMpe4Q0-gs&q=" .. encodedQuery
        
        -- Try to open search in Zen browser first
        local success = hs.urlevent.openURLWithBundle(searchUrl, "app.zen-browser.zen")
        if not success then
            -- Fall back to default browser if Zen isn't available
            hs.urlevent.openURL(searchUrl)
        end
        hs.alert.show("Searching: " .. query:sub(1, 30) .. (query:len() > 30 and "..." or ""))
    end
end

--- jjkUserScripts:doSearchOrOpen()
--- Method
--- Ensures modifiers are properly cleared before initiating text selection and processing
function obj:doSearchOrOpen()
    -- Small delay to allow any pending event processing to complete
    hs.timer.doAfter(0.1, function()
        -- hs.alert.show("Processing selection...")
        self:searchOrOpen()
    end)
    
    return true
end

return obj
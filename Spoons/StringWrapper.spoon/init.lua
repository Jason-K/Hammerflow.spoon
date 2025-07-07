-- Wrap Selected Text with Next Key Press

local obj = {}
obj.__index = obj

-- Add a logger
obj.logger = hs.logger.new("StringWrapper", "debug")

-- Define directional wrapper pairs
obj.wrapperPairs = {
  ["("] = ")",
  [")"] = ")",
  ["["] = "]",
  ["]"] = "]",
  ["{"] = "}",
  ["}"] = "}",
  ["<"] = ">",
  [">"] = ">",
  ['"'] = '"',
  ["'"] = "'",
  ["`"] = "`"
}

function obj:init()
  self.logger.i("StringWrapper initialized")
  return self
end

function obj:getWrapperPair(char)
  -- Check if it's a directional wrapper
  if self.wrapperPairs[char] then
    return char, self.wrapperPairs[char]
  else
    -- For non-directional wrappers, use the same character for both sides
    return char, char
  end
end

function obj:wrapSelection()
  self.logger.i("wrapSelection called")
  
  -- Store the current clipboard content to restore later
  local originalClipboard = hs.pasteboard.getContents()
  self.logger.i("Original clipboard saved")

  -- CRITICAL FIX: For some applications, need to specifically focus the window first
  local currentApp = hs.application.frontmostApplication()
  if currentApp then
    local win = currentApp:focusedWindow()
    if win then
      win:focus()
    end
  end

  -- Use applescript for more reliable copying
  hs.osascript.applescript([[tell application "System Events" 
      keystroke "c" using {command down}
  end tell]])
  
  -- Wait for clipboard to update
  hs.timer.usleep(300000) -- 300ms
  
  -- Get the copied text from the clipboard 
  local selectedText = hs.pasteboard.getContents()
  
  -- If that didn't work, try with eventtap as fallback (with protection)
  if not selectedText or selectedText == "" or selectedText == originalClipboard then
    -- Try once more with safe keyboard events
    local function safeKeyStroke()
      pcall(function()
        -- Manually generate the key events in sequence with pauses
        local cmdDown = hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, true)
        cmdDown:post()
        hs.timer.usleep(50000) -- 50ms pause
        local cDown = hs.eventtap.event.newKeyEvent("c", true)
        cDown:post()
        hs.timer.usleep(50000) -- 50ms pause
        local cUp = hs.eventtap.event.newKeyEvent("c", false)
        cUp:post()
        hs.timer.usleep(50000) -- 50ms pause
        local cmdUp = hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, false)
        cmdUp:post()
      end)
    end
    safeKeyStroke()
    hs.timer.usleep(300000) -- 300ms
    selectedText = hs.pasteboard.getContents()
  end

  self.logger.i("Got text from clipboard: " .. (selectedText and #selectedText > 0 and "text length: " .. #selectedText or "empty"))
  
  -- Check if clipboard actually changed (something was selected)
  if originalClipboard == selectedText or not selectedText or #selectedText == 0 then
    self.logger.w("No text was selected/copied")
    hs.alert.show("No text selected")
    return
  end

  -- Create a one-time eventtap to listen for the next key press
  local wrapperTap
  wrapperTap = hs.eventtap.new({hs.eventtap.event.types.keyDown}, function(event)
      -- Get the pressed character (respecting shift, etc.)
      local c = event:getCharacters(true)
      self.logger.i("Key pressed: " .. c)
      if #c == 1 then
          -- Get the appropriate wrapper pair
          local openChar, closeChar = self:getWrapperPair(c)
          -- Wrap the selected text
          local wrapped = openChar .. selectedText .. closeChar
          self.logger.i("Wrapped text created with '" .. openChar .. "' and '" .. closeChar .. "': " .. wrapped:sub(1, 20) .. (wrapped:len() > 20 and "..." or ""))
          -- Put the wrapped text on clipboard, then paste
          hs.pasteboard.setContents(wrapped)
          self.logger.i("Wrapped text placed on clipboard")
          -- Add slight delay before paste
          hs.timer.doAfter(0.1, function()
              hs.eventtap.keyStroke({"cmd"}, "v", 0)
              self.logger.i("Paste command sent")
              -- Restore original clipboard after a short delay
              hs.timer.doAfter(0.3, function()
                  if originalClipboard then
                      hs.pasteboard.setContents(originalClipboard)
                      self.logger.i("Original clipboard restored")
                  end
              end)
          end)
      end
      -- Stop listening since we only want the very next key
      wrapperTap:stop()
      self.logger.i("Eventtap stopped")
      return true  -- consume the event so it doesn't also type
  end)
  hs.alert.show("Type a character to wrap with")
  self.logger.i("Starting eventtap to listen for next key press")
  wrapperTap:start()
end

function obj:wrapSelectionWithQuotes()
  -- Step 1 - Store original clipboard content
  local originalClipboard = hs.pasteboard.getContents()
  -- Step 2: Copy whatever is currently selected
  hs.eventtap.keyStroke({"cmd"}, "c")
  -- Step 3: Small delay to allow copy operation to complete
      
  hs.timer.usleep(100000) -- 100ms
  -- Step 4: Check if clipboard changed
  local newClipboard = hs.pasteboard.getContents()
  if originalClipboard ~= newClipboard and newClipboard and newClipboard ~= "" then
    local quotedText = '"' .. newClipboard .. '"'
    hs.pasteboard.setContents(quotedText)
    -- Step 5: Paste new text
    hs.eventtap.keyStroke({"cmd"}, "v")
    
    -- Step 6: Restore original clipboard content
    hs.timer.doAfter(0.1, function()
      if originalClipboard then
        hs.pasteboard.setContents(originalClipboard)
      end
    end)
  else
    -- if not text was copied, show an error and end
    hs.alert.show("No text selected to wrap with quotes")
    return
  end
end

function obj:wrapSelectionWithParam(param)
  self.logger.i("wrapSelectionWithParam called with param: " .. tostring(param))
  local originalClipboard = hs.pasteboard.getContents()
  -- Focus window
  local currentApp = hs.application.frontmostApplication()
  if currentApp then
    local win = currentApp:focusedWindow()
    if win then win:focus() end
  end
  -- AppleScript copy
  hs.osascript.applescript([[tell application "System Events" 
      keystroke "c" using {command down}
  end tell]])
  hs.timer.usleep(300000)
  local selectedText = hs.pasteboard.getContents()
  if not selectedText or selectedText == "" or selectedText == originalClipboard then
    -- Fallback eventtap
    local function safeKeyStroke()
      pcall(function()
        local cmdDown = hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, true)
        cmdDown:post()
        hs.timer.usleep(50000)
        local cDown = hs.eventtap.event.newKeyEvent("c", true)
        cDown:post()
        hs.timer.usleep(50000)
        local cUp = hs.eventtap.event.newKeyEvent("c", false)
        cUp:post()
        hs.timer.usleep(50000)
        local cmdUp = hs.eventtap.event.newKeyEvent(hs.keycodes.map.cmd, false)
        cmdUp:post()
      end)
    end
    safeKeyStroke()
    hs.timer.usleep(300000)
    selectedText = hs.pasteboard.getContents()
  end
  self.logger.i("Got text from clipboard: " .. (selectedText and #selectedText > 0 and "text length: " .. #selectedText or "empty"))
  if originalClipboard == selectedText or not selectedText or #selectedText == 0 then
    self.logger.w("No text was selected/copied")
    hs.alert.show("No text selected")
    return
  end
  -- Use getWrapperPair logic
  local openChar, closeChar = self:getWrapperPair(param)
  local wrapped = openChar .. selectedText .. closeChar
  hs.pasteboard.setContents(wrapped)
  hs.timer.doAfter(0.1, function()
    hs.eventtap.keyStroke({"cmd"}, "v", 0)
    self.logger.i("Paste command sent")
    hs.timer.doAfter(0.3, function()
      if originalClipboard then
        hs.pasteboard.setContents(originalClipboard)
        self.logger.i("Original clipboard restored")
      end
    end)
  end)
end

return obj
-- Wrap Selected Text with Next Key Press

local obj = {}
obj.__index = obj

-- Add a logger
obj.logger = hs.logger.new("StringWrapper", "debug")

function obj:init()
  self.logger.i("StringWrapper initialized")
  return self
end

function obj:wrapSelection()
  self.logger.i("wrapSelection called")
  hs.alert.show("Wrap selection called.")
  
  -- Store the current clipboard content to restore later
  local originalClipboard = hs.pasteboard.getContents()
  self.logger.i("Original clipboard saved")
  
  -- Send Cmd+C to copy selected text - explicitly wait for it to complete
  hs.eventtap.keyStroke({"cmd"}, "c", 0)
  
  -- Use a slightly longer delay to ensure copy completes
  hs.timer.doAfter(0.3, function()
    -- Get the copied text from the clipboard 
    local selectedText = hs.pasteboard.getContents()
    self.logger.i("Got text from clipboard: " .. (selectedText and #selectedText > 0 and "text length: " .. #selectedText or "empty"))
    
    if not selectedText or #selectedText == 0 then
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
            -- Wrap the selected text
            local wrapped = c .. selectedText .. c
            self.logger.i("Wrapped text created: " .. wrapped:sub(1, 20) .. (wrapped:len() > 20 and "..." or ""))

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
  end)
end

return obj


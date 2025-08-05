--------------------------------------------------------------------
-- CleanShot X quick-launcher (fast menu bound to ⇧⌃⌥⌘-S)
--------------------------------------------------------------------
local actions = {
  { text = "Capture Area → Annotate",        subText = "Area + editor",   url = "cleanshot://capture-area?action=annotate" },
  { text = "Capture Area → Pin",             subText = "Area pinned",     url = "cleanshot://capture-area?action=pin"      },
  { text = "Capture Area → Save to File",    subText = "Area to disk",    url = "cleanshot://capture-area?action=save"     },
  { text = "Capture Area → Copy (Clipboard)",subText = "Area to clipboard",url="cleanshot://capture-area?action=copy"      },
  { text = "Capture Text (no line-breaks)",  subText = "OCR",             url = "cleanshot://capture-text?linebreaks=false"},
  { text = "Repeat Previous Area",           subText = "Same coords",     url = "cleanshot://capture-previous-area"        },
  { text = "Capture Window",                 subText = "Pick window",     url = "cleanshot://capture-window"               },
  { text = "Capture Fullscreen",             subText = "Whole display",   url = "cleanshot://capture-fullscreen"           },
  { text = "Scrolling Capture",              subText = "Long content",    url = "cleanshot://scrolling-capture"            },
}

local chooser = hs.chooser
  .new(function(choice)
        if choice then
          -- use macOS URL handler; avoids spawning full browser
          hs.execute('open "' .. choice.url .. '"', true, false)
        end
      end)
  :choices(actions)
  :searchSubText(true)  -- allows ⌘F-style filtering
  :bgDark(true)         -- dark UI; comment out if you prefer light
  :rows(8)              -- height tuning; 0 = auto

-- ⇧⌃⌘-S brings up the menu (change modifiers to taste)
hs.hotkey.bind({"shift","ctrl","cmd"}, "S", function() chooser:show() end)
-------------------------------
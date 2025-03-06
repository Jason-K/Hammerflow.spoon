# KeyTapper Spoon

A Hammerspoon Spoon that lets you assign callbacks to keyboard events including multi-taps and key combinations.

## Features

- **Multi-tap detection**: Detect when a user presses the same key multiple times in quick succession
- **Key combination detection**: Detect specific key combinations pressed simultaneously
- **Sequential key presses**: Detect specific sequences of keys pressed in order
- **Customizable timeouts**: Configure timing thresholds for all detection mechanisms

## Installation

1. Download the zip file from [GitHub](https://github.com/Hammerspoon/Spoons/raw/master/Spoons/KeyTapper.spoon.zip)
2. Unzip and place in your `~/.hammerspoon/Spoons` directory
3. Load in your Hammerspoon configuration:
   ```lua
   hs.loadSpoon("KeyTapper")
   ```

## Usage

### Basic Setup

```lua
-- Load the spoon
hs.loadSpoon("KeyTapper")

-- Initialize and start
local keyTapper = spoon.KeyTapper:init():start()
```

### Multi-tap Detection

Detect multiple taps of the same key in quick succession:

```lua
-- Double-tap the 'escape' key to hide all windows
keyTapper:handleMultiTap("escape", 2, function()
    hs.alert.show("Double-tapped escape!")
    hs.application.frontmostApplication():hide()
end)

-- Triple-tap the 'f' key to make the current window fullscreen
keyTapper:handleMultiTap("f", 3, function()
    local win = hs.window.focusedWindow()
    if win then
        win:toggleFullScreen()
    end
end)
```

### Key Combinations

Detect when specific keys are pressed at the same time:

```lua
-- Press 'a' and 's' together to show an alert
keyTapper:handleCombination({"a", "s"}, function()
    hs.alert.show("A+S pressed together")
end)

-- Press 'ctrl', 'shift', and 'x' together for a different action
keyTapper:handleCombination({"ctrl", "shift", "x"}, function()
    hs.alert.show("Ctrl+Shift+X pressed")
    -- Do something useful
end)
```

### Key Sequences

Detect when keys are pressed in a specific sequence:

```lua
-- Type 'hello' in sequence to trigger action
keyTapper:handleSequence({"h", "e", "l", "l", "o"}, function()
    hs.alert.show("You typed 'hello'!")
end)

-- Arrow key sequence: up, up, down, down, left, right, left, right
keyTapper:handleSequence({"up", "up", "down", "down", "left", "right", "left", "right"}, function()
    hs.alert.show("Konami code! (almost)")
end)
```

## Configuration

You can customize the timing parameters:

```lua
-- Set multi-tap timeout to 0.4 seconds (default is 0.5)
keyTapper.multiTapTimeout = 0.4

-- Set combination timeout to 0.8 seconds (default is 0.75)
keyTapper.combinationTimeout = 0.8

-- Set sequence reset timeout to 1.5 seconds (default is 2.0)
keyTapper.sequenceResetDelay = 1.5

-- Enable debug logging
keyTapper:debugEnable(true)
```

## API

- `init()`: Initialize the KeyTapper object
- `start()`: Start monitoring keyboard events
- `stop()`: Stop monitoring keyboard events
- `isRunning()`: Check if KeyTapper is currently running
- `debugEnable(enable)`: Enable or disable debug logging
- `handleMultiTap(key, count, fn)`: Register a callback for multi-taps
- `handleCombination(keys, fn)`: Register a callback for key combinations
- `handleSequence(keys, fn)`: Register a callback for key sequences

## License

MIT - https://opensource.org/licenses/MIT
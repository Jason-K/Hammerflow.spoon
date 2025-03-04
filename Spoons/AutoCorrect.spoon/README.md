# AutoCorrect Spoon

A Hammerspoon spoon that provides real-time autocorrection of typing mistakes.

## Features

- Real-time autocorrection as you type
- Extensive built-in dictionary of common corrections
- Support for custom corrections
- Minimal performance impact
- Debug logging capability

## Installation

Copy the AutoCorrect.spoon directory to your Hammerspoon Spoons directory (`~/.hammerspoon/Spoons`).

## Usage

1. Load the spoon in your Hammerspoon config:
```lua
hs.loadSpoon("AutoCorrect")
```

2. Start the autocorrect functionality:
```lua
spoon.AutoCorrect:start()
```

3. (Optional) Add custom patterns:
```lua
spoon.AutoCorrect:addPattern("teh", "the")
```

## Methods

- `start()` - Start the autocorrect functionality
- `stop()` - Stop the autocorrect functionality
- `addPattern(trigger, replacement)` - Add a new autocorrect pattern
- `loadPatterns()` - Reload patterns from patterns.lua

## Configuration

Debug logging can be enabled:
```lua
spoon.AutoCorrect.debug = true
```
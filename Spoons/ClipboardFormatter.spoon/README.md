# ClipboardFormatter Spoon for Hammerspoon

A Hammerspoon Spoon that provides advanced clipboard text formatting capabilities, including:

- Rating string formatting
- Phone number formatting
- Arithmetic expression evaluation
- Currency formatting
- Number formatting with commas
- Percentage combinations

## Installation

1. Download the Spoon
2. Copy to `~/.hammerspoon/Spoons/`
3. Load in your Hammerspoon configuration:

```lua
hs.loadSpoon("ClipboardFormatter")
spoon.ClipboardFormatter:bindHotkeys({
    format = {{"alt"}, "v"}
})
```

## Features

### Rating String Formatting
Handles two types of rating string formats:

1. With apportionment:
   - Input: `0.9 (15.03.01.00 - 8 - [1.4]11 - 311G - 13 = 12) = 12.38% = 12%`
   - Output: `0.9 (15.03.01.00 - 8 - [1.4]11 - 311G - 13 - 12) = 12%`

2. Without apportionment:
   - Input: `15.03.01.00 - 8 - [1.4]11 - 311G - 13 = 12`
   - Output: `1.0 (15.03.01.00 - 8 - [1.4]11 - 311G - 13 - 12) = 12%`

### Other Features
- Phone number formatting with extensions
- Currency formatting
- Basic arithmetic evaluation
- Number formatting with commas
- Percentage combinations

## API

### Methods

#### `bindHotkeys(mapping)`
Binds hotkeys for the Spoon's actions. The mapping table should contain:
- `format` - Format the current clipboard content

#### `formatClipboard()`
Formats the current clipboard content based on recognized patterns

#### `processClipboard()`
Internal function that processes clipboard content and applies formatting rules

## License

MIT License - See LICENSE file for details
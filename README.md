# Hammerspoon Configuration

This is my personal Hammerspoon configuration for macOS automation and window management.

## What is Hammerspoon?

[Hammerspoon](https://www.hammerspoon.org/) is a powerful automation tool for macOS which allows you to programmatically control your Mac using Lua scripts.

## Features

This configuration includes:

- **Auto-reload**: Configuration automatically reloads when any Lua file is changed
- **Debugging Helpers**: Error handling and logging for safe execution
- **Text Formatting**: Format clipboard or selection via ClipboardFormatter spoon
- **String Wrapping**: Wrap selected text via StringWrapper spoon
- **Custom Hotkeys**: Tap/double-tap/hold support for dynamic key actions via jjkHotkeys

## Spoons Included

This configuration uses the following Spoons:

[ClipboardFormatter](https://github.com/search?q=ClipboardFormatter+hammerspoon) - Advanced clipboard and selection formatting
[jjkHotkeys](https://github.com/search?q=jjkHotkeys+hammerspoon) - Central hotkey manager with tap/double-tap/hold support
[StringWrapper](https://github.com/search?q=StringWrapper+hammerspoon) - Wrap selection with custom delimiters

## Keyboard Shortcuts

### Clipboard Management
- `Ctrl + Alt + Cmd + Shift + V`: Format clipboard contents
- `Ctrl + Alt + Cmd + V`: Format selected text
- Double-tap Right Command key: Format selected text
- Hold Right Command key: Format clipboard contents

## Clipboard Formatter Features

The ClipboardFormatter spoon can automatically format:
- **Arithmetic Expressions**: Evaluates simple calculations
- **Date Ranges**: Calculates days between dates
- **Phone Numbers**: Formats phone numbers with proper punctuation
- **Rating Strings**: Special formatting for rating strings
- **Combinations**: Calculates percentage combinations (using "c" notation)
- **PD Conversions**: Converts PD percentages to weeks and dollars

## Installation

1. Install Hammerspoon if you don't have it already:
   ```
   brew install --cask hammerspoon
   ```

2. Clone this repository to your Hammerspoon configuration folder:
   ```
   git clone https://github.com/yourusername/hammerspoon-config.git ~/.hammerspoon
   ```

3. Launch or reload Hammerspoon

## Custom Configuration

You can add custom or private configurations in the `private/` directory which is excluded from version control.

## License

This configuration is provided as-is under the MIT License unless otherwise noted. Individual Spoons may have their own licensing.
# Hammerspoon Configuration

This is my personal Hammerspoon configuration for macOS automation and window management.

## What is Hammerspoon?

[Hammerspoon](https://www.hammerspoon.org/) is a powerful automation tool for macOS which allows you to programmatically control your Mac using Lua scripts.

## Features

This configuration includes:

- **Auto-reload**: Configuration automatically reloads when any Lua file is changed
- **Window Management**: Using MiroWindowsManager for easy window snapping and organization
- **Clipboard Formatting**: Advanced clipboard management with ClipboardFormatter spoon
- **Hammerspoon Log Formatting**: Automatically strips timestamps from Hammerspoon logs
- **Advanced Input Processing**: Handle date ranges, arithmetic expressions, and more
- **Custom Key Handling**: Support for tap, double-tap and hold key actions

## Spoons Included

This configuration uses the following Spoons:

- [ClipboardFormatter](https://github.com/search?q=ClipboardFormatter+hammerspoon) - Advanced clipboard text manipulation
- [MiroWindowsManager](https://github.com/mirowindows/miro-windows-manager) - Window management and organization
- [jjkHotkeys](https://github.com/search?q=jjkHotkeys+hammerspoon) - Advanced hotkey handling with tap/double-tap/hold support
- [HeadphoneAutoPause](https://www.hammerspoon.org/Spoons/) - Auto-pause on headphone disconnect
- [AutoMuteOnSleep](https://www.hammerspoon.org/Spoons/) - Automatically mute on system sleep
- [WindowGrid](https://www.hammerspoon.org/Spoons/WindowGrid.html) - Grid-based window management
- [SpoonInstall](https://www.hammerspoon.org/Spoons/SpoonInstall.html) - For easy installation of Spoons

## Keyboard Shortcuts

### Window Management
- `Ctrl + Alt + Cmd + Up`: Move window to top half of screen
- `Ctrl + Alt + Cmd + Right`: Move window to right half of screen 
- `Ctrl + Alt + Cmd + Down`: Move window to bottom half of screen
- `Ctrl + Alt + Cmd + Left`: Move window to left half of screen
- `Ctrl + Alt + Cmd + F`: Make window fullscreen
- `Ctrl + Alt + Cmd + N`: Move window to next screen
- `Ctrl + Alt + Cmd + G`: Show window grid

### Clipboard Management
- `Ctrl + Alt + Cmd + Shift + V`: Format clipboard contents
- `Ctrl + Alt + Cmd + V`: Format selected text
- Double-tap Right Command key: Format selected text
- Hold Right Command key: Format clipboard contents

## Clipboard Formatter Features

The ClipboardFormatter spoon can automatically format:
- **Hammerspoon Logs**: Strips date and timestamps for cleaner output
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
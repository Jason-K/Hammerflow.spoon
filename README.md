# Hammerspoon Configuration

This is my personal Hammerspoon configuration for macOS automation and window management.

## What is Hammerspoon?

[Hammerspoon](https://www.hammerspoon.org/) is a powerful automation tool for macOS which allows you to programmatically control your Mac using Lua scripts.

## Features

This configuration includes:

- **Auto-reload**: Configuration automatically reloads when any Lua file is changed
- **Window Management**: Using MiroWindowsManager for easy window snapping and organization
- **Clipboard Formatting**: Advanced clipboard management with ClipboardFormatter spoon
- **Auto-correction**: Text auto-correction with AutoCorrect spoon

## Spoons Included

This configuration uses the following Spoons:

- [ClipboardFormatter](https://github.com/search?q=ClipboardFormatter+hammerspoon) - Advanced clipboard text manipulation
- [MiroWindowsManager](https://github.com/mirowindows/miro-windows-manager) - Window management and organization
- [AutoCorrect](https://github.com/search?q=AutoCorrect+hammerspoon) - Text auto-correction functionality
- [SpoonInstall](https://www.hammerspoon.org/Spoons/SpoonInstall.html) - For easy installation of Spoons

## Keyboard Shortcuts

### Window Management
- `Ctrl + Alt + Cmd + Up`: Move window to top half of screen
- `Ctrl + Alt + Cmd + Right`: Move window to right half of screen 
- `Ctrl + Alt + Cmd + Down`: Move window to bottom half of screen
- `Ctrl + Alt + Cmd + Left`: Move window to left half of screen
- `Ctrl + Alt + Cmd + F`: Make window fullscreen
- `Ctrl + Alt + Cmd + N`: Move window to next screen

### Clipboard Management
- `Ctrl + Alt + Cmd + Shift + V`: Format clipboard contents
- `Ctrl + Alt + Cmd + V`: Format selected text
- Double-tap Right Command key: Format selected text

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
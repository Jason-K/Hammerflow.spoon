local Actions = require('hsLauncher.main.core.actions')
local logger = require('hsLauncher.main.core.logger')
local urlevent = require('hs.urlevent')

local function invokeClipboardFormatter()
	local formatter = rawget(_G, 'FormatClip')
	if type(formatter) ~= 'function' then
		logger.warn('external_hotkeys: FormatClip handler unavailable')
		return
	end
	local ok, err = pcall(formatter)
	if not ok then
		logger.error('external_hotkeys: FormatClip failed -> ' .. tostring(err))
	end
end

local function triggerKeyboardMaestro(url)
	return Actions.call(function ()
		urlevent.openURL(url)
	end)
end

return {
	{
		name = 'external.global.clipboardFormatter',
		actions = {
			Actions.call(invokeClipboardFormatter),
		},
		menuDetails = {
			description = 'Format clipboard via external tool',
			defaultShortcut = 'c',
			inMenu = { 'externalHotkeysGlobal' },
		},
		tags = { 'hotkeys.external', 'hotkeys.external.global' },
	},
	{
		name = 'external.app.finder.openDownloads',
		actions = {
			triggerKeyboardMaestro('kmtrigger://macro=Finder%20-%20Go%20to%20Downloads'),
		},
		menuDetails = {
			description = 'Finder Downloads Shortcut',
			defaultShortcut = 'd',
			inMenu = { 'externalHotkeysApps' },
			perMenu = {
				externalHotkeysApps = {
					description = 'Finder: Open Downloads',
					defaultShortcut = 'd',
				},
			},
		},
		tags = {
			'hotkeys.external',
			'hotkeys.external.app',
			'hotkeys.external.app.com.apple.finder',
		},
	},
}

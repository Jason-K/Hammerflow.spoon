--- @diagnostic disable: undefined-global

local ModuleActions = require('hsLauncher.main.core.module_actions')

local M = {
	id = 'utilities',
	section = 'Utilities',
}

M.actions = {
	-- Screenshot actions
	screenshot_annotate = ModuleActions.url('Annotate', 'cleanshot://capture-area?action=annotate'),
	screenshot_ocr = ModuleActions.url('O(C)R', 'cleanshot://capture-text?linebreaks=false'),
	screenshot_pin = ModuleActions.url('Pin', 'cleanshot://capture-area?action=pin'),
	screenshot_save = ModuleActions.url('Save', 'cleanshot://capture-area?action=save'),
	screenshot_copy = ModuleActions.url('Copy to clipboard', 'cleanshot://capture-area'),
	-- Rectangle actions
	rectangle_reflow_pin = ModuleActions.shell('Reflow (P)inned app',
		'open -g "rectangle-pro://execute-action?name=reflow-pin"'),
	rectangle_toggle_pin = ModuleActions.shell('Toggle (P)in mode', 'open -g "rectangle-pro://execute-action?name=pin"'),
	-- Misc scripts
	scripts_merus_scan = ModuleActions.python('Name scan in Merus',
		'~/Scripts/Application_Specific/Meruscase/jjk_Rename_MerusScans.py', { args = '--source clipboard --dest paste' }),
	scripts_raycast = ModuleActions.url('Raycast text extension',
		'raycast://extensions/koinzhang/text-shortcuts/shortcut-library'),
}

M.leader = {
	section = 'Utilities',
	root = {
		key = 'u',
		label = 'Utilities',
		description = 'Capture screenshots and toggle helpers',
		order = 70,
	},
	groups = {
		{
			key = 'S',
			label = 'Screenshots',
			entries = {
				{ ref = 'utilities.screenshot_annotate', key = 'a' },
				{ ref = 'utilities.screenshot_ocr',      key = 'c', label = 'O(C)R' },
				{ ref = 'utilities.screenshot_pin',      key = 'p' },
				{ ref = 'utilities.screenshot_save',     key = 's' },
				{ ref = 'utilities.screenshot_copy',     key = 'C' },
			},
		},
		{
			key = 'R',
			label = 'Rectangle',
			entries = {
				{ ref = 'utilities.rectangle_reflow_pin', key = 'r', label = 'r' },
				{ ref = 'utilities.rectangle_toggle_pin', key = 't', label = 't' },
			},
		},
		{
			key = 'M',
			label = 'Misc. Scripts',
			entries = {
				{ ref = 'utilities.scripts_merus_scan', key = 'n' },
				{ ref = 'utilities.scripts_raycast',    key = 'r' },
			},
		},
	},
}

return M

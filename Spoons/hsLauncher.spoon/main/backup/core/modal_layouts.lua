-- Layout presets for modal GUI
local M = {}

local function deepCopy(value)
	if type(value) ~= 'table' then return value end
	local out = {}
	for k, v in pairs(value) do out[k] = deepCopy(v) end
	return out
end

local BASE = {
	width = 500,
	padding = 12,
	margin = { x = 20, y = 20 },
	fontName = "Menlo",
	fontSize = 14,
	titleExtra = 8,
	showTitle = true,
	titleColor = { red = 0.9, green = 0.9, blue = 0.9, alpha = 1.0 },
	rowSpacing = 6,
	lineSpacing = 4,
	keyColumnWidth = 110,
	descColumnGap = 12,
	sectionGap = 12,
	sectionFontSize = 12,
	sectionHeaderSpacing = 4,
	showSectionHeaders = true,
	sectionColor = { red = 0.8, green = 0.8, blue = 0.8, alpha = 0.9 },
	defaultSection = 'Shortcuts',
	exitSection = 'Exit',
	wrapDescriptions = true,
	descAlignment = 'left',
	chordBrackets = { '⟨', '⟩' },
	backgroundColor = { white = 0.1, alpha = 1 },
	keyColor = { red = 0.9, green = 0.9, blue = 0.9, alpha = 1.0 },
	chordKeyColor = { red = 1.0, green = 0.85, blue = 0.6, alpha = 1.0 },
	descColor = { red = 0.7, green = 0.7, blue = 0.7, alpha = 1.0 },
	exitKeyColor = { red = 0.7, green = 0.7, blue = 0.7, alpha = 1.0 },
	exitDescColor = { red = 0.6, green = 0.6, blue = 0.6, alpha = 1.0 },
	noteColor = { red = 0.6, green = 0.6, blue = 0.75, alpha = 1.0 },
	noteFontSize = 12,
	noteSpacing = 2,
	anchor = 'bottom-right',
	offset = { x = 0, y = 0 },
	sectionOrder = nil,
	sectionGroups = nil,
	groupGap = 18,
	showGroupHeaders = true,
	groupHeaderFontSize = 13,
	groupHeaderColor = { red = 0.75, green = 0.75, blue = 0.75, alpha = 1.0 },
	groupHeaderSpacing = 6,
	footerText = nil,
	footerAlignment = 'right',
	footerFontSize = 12,
	footerColor = { red = 0.6, green = 0.6, blue = 0.6, alpha = 1.0 },
	footerSpacing = 12,
	showNotes = false,
}

local PRESETS = {
	default = {},
	compact = {
		width = 320,
		fontSize = 13,
		noteFontSize = 11,
		keyColumnWidth = 60,
		descColumnGap = 10,
		rowSpacing = 4,
		sectionGap = 10,
		groupGap = 12,
		margin = { x = 18, y = 18 },
	},
	spacious = {
		width = 420,
		fontSize = 15,
		noteFontSize = 13,
		keyColumnWidth = 74,
		descColumnGap = 14,
		rowSpacing = 8,
		sectionGap = 16,
		groupGap = 22,
		margin = { x = 26, y = 26 },
		footerFontSize = 13,
		footerSpacing = 16,
	},
	inspector = {
		width = 400,
		anchor = 'middle-right',
		showTitle = false,
		showGroupHeaders = true,
		margin = { x = 32, y = 32 },
		footerAlignment = 'left',
		footerSpacing = 10,
		footerFontSize = 11,
	},
	centered = {
		anchor = 'middle-center',
		width = 360,
		margin = { x = 0, y = 0 },
	},
}

local function sanitizePresetName(name)
	if type(name) ~= 'string' then return nil end
	local trimmed = name:match('^%s*(.-)%s*$')
	if trimmed == '' then return nil end
	return trimmed:lower()
end

function M.base()
	return deepCopy(BASE)
end

function M.getPreset(name)
	local preset = PRESETS[sanitizePresetName(name)]
	if not preset then return nil end
	return deepCopy(preset)
end

function M.applyPreset(cfg, name)
	local preset = M.getPreset(name)
	if not preset then return false end
	for k, v in pairs(preset) do
		cfg[k] = deepCopy(v)
	end
	return true
end

function M.extract(layout)
	local preset
	local overrides = {}
	if type(layout) == 'string' then
		preset = sanitizePresetName(layout)
	elseif type(layout) == 'table' then
		preset = sanitizePresetName(layout.preset or layout.presetName)
		for k, v in pairs(layout) do
			if k ~= 'preset' and k ~= 'presetName' then overrides[k] = v end
		end
	end
	return preset, overrides
end

function M.list()
	local names = {}
	for name in pairs(PRESETS) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function M.describe(name)
	local preset = M.getPreset(name)
	if not preset then return nil end
	return {
		name = name,
		overrides = preset,
	}
end

return M

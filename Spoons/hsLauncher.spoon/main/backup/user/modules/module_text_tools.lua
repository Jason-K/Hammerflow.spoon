--- @diagnostic disable: undefined-global

local Actions = require('hsLauncher.main.core.actions')
local ModuleActions = require('hsLauncher.main.core.module_actions')

local M = {
	id = 'text_tools',
	section = 'Text Tools',
}

local textAction = ModuleActions.textProcessorFactory('~/Scripts/Text_Manipulation/text_processor/interfaces/cli.py')

local actionSpecs = {
	td_to_aww = textAction('AWW from TTD', 'td_to_aww'),
	aww_to_td = textAction('TTD from AWW', 'aww_to_td'),

	lowercase = textAction('lower', 'lowercase'),
	sentence_case = textAction('Sentence', 'sentence_case'),
	title_case = textAction('Title', 'title_case'),
	uppercase = textAction('UPPER', 'uppercase'),

	date_alpha = textAction('Alpha - MMMM D, YYYY', 'date_alpha'),
	date_diff = textAction('Date diff', 'date_diff'),
	date_file = textAction('File - YYYY.MM.DD', 'date_file'),
	date_iso = textAction('ISO - YYYY-MM-DD', 'date_iso'),
	date_long = textAction('Long - MM/DD/YYYY', 'date_long'),
	date_medium = textAction('Medium - M/D/YYYY', 'date_medium'),
	date_pad = textAction('Padded medium - MM/DD/YYYY', 'date_pad'),
	date_relative = textAction('Relative date', 'format_relative_date'),

	markdown_heading_1 = textAction('Heading 1', 'markdown_heading', '--level 1'),
	markdown_heading_2 = textAction('Heading 2', 'markdown_heading', '--level 2'),
	markdown_heading_3 = textAction('Heading 3', 'markdown_heading', '--level 3'),
	markdown_ordered = textAction('Ordered list', 'markdown_ordered_list'),
	markdown_unordered = textAction('Unordered list', 'markdown_unordered_list'),
	markdown_bold = textAction('Bold', 'markdown_bold'),
	markdown_italic = textAction('Italics', 'markdown_italic'),
	markdown_link = textAction('Link', 'markdown_link'),
	markdown_remove = textAction('Remove markdown', 'remove_markdown'),
	markdown_strike = textAction('Strikethrough', 'markdown_strikethrough'),
	markdown_underline = textAction('Underline', 'markdown_underline'),
	markdown_rule = textAction('Horizontal rule', 'markdown_horizontal_rule'),

	wrap_brackets = textAction('Wrap []', 'wrap_brackets'),
	wrap_curly = textAction('Wrap {}', 'wrap_curly_braces'),
	wrap_quotes = textAction('Wrap ""', 'wrap_quotes'),
	wrap_single_quotes = textAction("Wrap ''", 'wrap_single_quotes'),
	wrap_parentheses = textAction('Wrap ()', 'wrap_parentheses'),
}

local categories = {
	{
		id = 'benefit_rates',
		label = 'Benefit Rates',
		description = 'Benefit rate converters',
		key = 'b',
		order = 60,
		mode = 'text_tools.benefit_rates',
		entries = {
			{ action = 'td_to_aww', key = 'a', label = 'AWW from TTD', order = 10 },
			{ action = 'aww_to_td', key = 't', label = 'TTD from AWW', order = 20 },
		},
	},
	{
		id = 'case_changers',
		label = 'Case Changers',
		description = 'Change letter casing',
		key = 'c',
		order = 70,
		mode = 'text_tools.case_changers',
		entries = {
			{ action = 'lowercase', key = 'l', order = 10, label = 'lowercase' },
			{ action = 'sentence_case', key = 's', order = 20, label = 'Sentence case' },
			{ action = 'title_case', key = 't', order = 30, label = 'Title case' },
			{ action = 'uppercase', key = 'u', order = 40, label = 'UPPERCASE' },
		},
	},
	{
		id = 'date_scripts',
		label = 'Date Scripts',
		description = 'Generate date strings',
		key = 'd',
		order = 80,
		mode = 'text_tools.date_scripts',
		entries = {
			{ action = 'date_alpha', key = 'a', order = 10, label = 'Alpha - MMMM D, YYYY' },
			{ action = 'date_diff', key = 'd', order = 20, label = 'Date diff' },
			{ action = 'date_file', key = 'f', order = 30, label = 'File - YYYY.MM.DD' },
			{ action = 'date_iso', key = 'i', order = 40, label = 'ISO - YYYY-MM-DD' },
			{ action = 'date_long', key = 'l', order = 50, label = 'Long - MM/DD/YYYY' },
			{ action = 'date_medium', key = 'm', order = 60, label = 'Medium - M/D/YYYY' },
			{ action = 'date_pad', key = 'p', order = 70, label = 'Padded medium - MM/DD/YYYY' },
			{ action = 'date_relative', key = 'r', order = 80, label = 'Relative date' },
		},
	},
	{
		id = 'markdown',
		label = 'Markdown',
		description = 'Markdown helpers',
		key = 'm',
		order = 90,
		mode = 'text_tools.markdown',
		entries = {
			{ action = 'markdown_heading_1', key = '1', order = 10, section = 'Headings', label = 'Heading 1' },
			{ action = 'markdown_heading_2', key = '2', order = 20, section = 'Headings', label = 'Heading 2' },
			{ action = 'markdown_heading_3', key = '3', order = 30, section = 'Headings', label = 'Heading 3' },
			{ action = 'markdown_ordered', key = 'o', order = 40, section = 'Lists', label = 'Ordered list' },
			{ action = 'markdown_unordered', key = 'u', order = 50, section = 'Lists', label = 'Unordered list' },
			{ action = 'markdown_bold', key = 'b', order = 60, section = 'Formatting', label = 'Bold' },
			{ action = 'markdown_italic', key = 'i', order = 70, section = 'Formatting', label = 'Italics' },
			{ action = 'markdown_link', key = 'l', order = 80, section = 'Formatting', label = 'Link' },
			{ action = 'markdown_remove', key = 'r', order = 90, section = 'Formatting', label = 'Remove markdown' },
			{ action = 'markdown_strike', key = 's', order = 100, section = 'Formatting', label = 'Strikethrough' },
			{ action = 'markdown_underline', key = 'u', order = 110, section = 'Formatting', label = 'Underline' },
			{ action = 'markdown_rule', key = 'h', order = 120, section = 'Formatting', label = 'Horizontal rule' },
		},
	},
	{
		id = 'wrappers',
		label = 'Wrappers',
		description = 'Wrap text with punctuation',
		key = 'w',
		order = 100,
		mode = 'text_tools.wrappers',
		entries = {
			{ action = 'wrap_brackets', key = 'b', order = 10, label = 'Wrap with []' },
			{ action = 'wrap_brackets', key = '[', order = 11, label = 'Wrap with []' },
			{ action = 'wrap_curly', key = 'c', order = 20, label = 'Wrap with {}' },
			{ action = 'wrap_curly', key = '{', order = 21, label = 'Wrap with {}' },
			{ action = 'wrap_quotes', key = 'q', order = 30, label = 'Wrap with ""' },
			{ action = 'wrap_single_quotes', key = "'", order = 40, label = "Wrap with ''" },
			{ action = 'wrap_parentheses', key = '9', order = 50, label = 'Wrap with ()' },
		},
	},
}

local function buildCategoryMode(category)
	local layout = {
		width = 420,
		defaultSection = category.defaultSection or category.label,
		exitSection = 'Exit',
		sectionOrder = category.sectionOrder or { category.label, 'Exit' },
	}
	local mode = {
		consume = true,
		layout = layout,
		entries = {},
	}
	for _, entry in ipairs(category.entries) do
		local spec = actionSpecs[entry.action]
		if spec then
			mode.entries[#mode.entries + 1] = {
				key = entry.key,
				description = entry.description or spec.description or spec.label,
				label = entry.label or spec.label,
				section = entry.section or category.label,
				order = entry.order,
				exitAfter = spec.exitAfter ~= false,
				action = { kind = 'userAction', id = 'text_tools.' .. entry.action },
			}
		end
	end
	return mode
end

local categoryModes = {}
for _, category in ipairs(categories) do
	categoryModes[category.mode] = buildCategoryMode(category)
end

local textToolsMode = {
	consume = true,
	layout = {
		width = 360,
		defaultSection = 'Categories',
		exitSection = 'Exit',
		sectionOrder = { 'Categories', 'Exit' },
	},
	entries = {},
}

for _, category in ipairs(categories) do
	textToolsMode.entries[#textToolsMode.entries + 1] = {
		key = category.key,
		description = category.description or ('Enter ' .. category.label),
		label = category.label,
		section = 'Categories',
		order = category.order,
		exitAfter = false,
		action = { kind = 'userAction', id = 'text_tools.enter_' .. category.id },
	}
end

local function rootEntries()
	local entries = {
		{
			ref = 'text_tools.enter_mode',
			key = 't',
			label = 'Text Tools',
			description = 'Format and transform text snippets',
			order = 50,
			exitAfter = false,
			section = 'Text Tools',
			metadata = { module = 'text_tools', enterMode = true },
		},
	}
	for _, category in ipairs(categories) do
		entries[#entries + 1] = {
			ref = 'text_tools.enter_' .. category.id,
			key = category.key,
			label = category.label,
			description = category.description or ('Enter ' .. category.label),
			order = category.order,
			exitAfter = false,
			section = 'Text Tools',
			metadata = { module = 'text_tools', category = category.id },
		}
	end
	return entries
end

local actions = {
	enter_mode = {
		label = 'Text Tools',
		description = 'Enter text tools modal',
		actionSpec = Actions.enterMode('text_tools'),
		defaultKey = 't',
		exitAfter = false,
	},
}

for _, category in ipairs(categories) do
	actions['enter_' .. category.id] = {
		label = category.label,
		description = category.description or ('Enter ' .. category.label),
		actionSpec = Actions.enterMode(category.mode),
		exitAfter = false,
	}
end

for id, spec in pairs(actionSpecs) do
	actions[id] = spec
end

M.actions = actions

M.leader = {
	section = 'Text Tools',
	rootEntries = rootEntries,
}

function M.hotkeys()
	local modes = {
		text_tools = textToolsMode,
	}
	for modeName, mode in pairs(categoryModes) do
		modes[modeName] = mode
	end

	local sequences = {
		{
			keys = { 't' },
			description = 'Enter text tools modal',
			action = { kind = 'handler', name = 'enterMode', args = { mode = 'text_tools' } },
			metadata = { module = 'text_tools' },
		},
	}
	for _, category in ipairs(categories) do
		sequences[#sequences + 1] = {
			keys = { 't', category.key },
			description = 'Enter ' .. category.label .. ' text tools',
			action = { kind = 'handler', name = 'enterMode', args = { mode = category.mode } },
			metadata = { module = 'text_tools', category = category.id },
		}
	end

	return {
		modes = modes,
		sequences = sequences,
	}
end

return M

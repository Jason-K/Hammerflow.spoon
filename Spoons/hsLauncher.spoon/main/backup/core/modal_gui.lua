-- hsLauncher/main/core/modal_gui.lua
local canvas = require('hs.canvas')
local screen = require('hs.screen')
local logger = require('hsLauncher.main.core.logger')
local ExitKeys = require('hsLauncher.main.backup.core.exit_keys')
local Layouts = require('hsLauncher.main.backup.core.modal_layouts')
local M = {}

local function logInfo(message)
	if type(logger) == 'table' and type(logger.info) == 'function' then
		logger.info(message)
	end
end

local function logWarn(message)
	if type(logger) == 'table' and type(logger.warn) == 'function' then
		logger.warn(message)
	end
end

local function logError(message)
	if type(logger) == 'table' and type(logger.error) == 'function' then
		logger.error(message)
	end
end

local gui_canvas = nil
local last_mode_name = nil

local COLOR_KEYS = {
	backgroundColor = true,
	keyColor = true,
	chordKeyColor = true,
	descColor = true,
	exitKeyColor = true,
	exitDescColor = true,
	sectionColor = true,
	titleColor = true,
	noteColor = true,
	groupHeaderColor = true,
	footerColor = true,
}

local ARRAY_KEYS = {
	chordBrackets = true,
	sectionOrder = true,
}

local function copyArray(arr)
	if type(arr) ~= 'table' then return nil end
	local out = {}
	for i, v in ipairs(arr) do out[i] = v end
	return out
end

local function copyTable(tbl)
	if type(tbl) ~= 'table' then return nil end
	local out = {}
	for k, v in pairs(tbl) do
		if type(v) == 'table' then out[k] = copyTable(v) else out[k] = v end
	end
	return out
end

local function copyGroups(list)
	if type(list) ~= 'table' then return nil end
	local groups = {}
	for index, group in ipairs(list) do
		if type(group) == 'table' then
			groups[index] = {
				label = group.label,
				sections = copyArray(group.sections) or {},
			}
		end
	end
	return groups
end

local function normalizeMargin(value, fallback)
	fallback = fallback or { x = 20, y = 20 }
	if type(value) == 'number' then
		return { x = value, y = value }
	elseif type(value) == 'table' then
		if value.x or value.y then
			return { x = value.x or fallback.x, y = value.y or fallback.y }
		elseif value[1] or value[2] then
			return { x = value[1] or fallback.x, y = value[2] or value[1] or fallback.y }
		end
	end
	return { x = fallback.x, y = fallback.y }
end

local function mergeConfig(layout)
	local presetName, overrides = Layouts.extract(layout)
	local cfg = Layouts.base()
	local meta = { preset = presetName }

	if presetName ~= nil then
		local applied = Layouts.applyPreset(cfg, presetName)
		if not applied then
			meta.presetMissing = true
		end
	end

	overrides = overrides or {}
	for k, v in pairs(overrides) do
		if v ~= nil then
			if COLOR_KEYS[k] ~= nil then
				cfg[k] = copyTable(v)
			elseif ARRAY_KEYS[k] ~= nil then
				cfg[k] = copyArray(v)
			elseif k == 'margin' then
				cfg.margin = normalizeMargin(v, cfg.margin)
			elseif k == 'offset' then
				cfg.offset = normalizeMargin(v, { x = 0, y = 0 })
			elseif k == 'sectionGroups' or k == 'groups' then
				cfg.sectionGroups = copyGroups(v)
			elseif k == 'footer' or k == 'footerText' then
				cfg.footerText = v
			else
				cfg[k] = v
			end
		end
	end

	cfg.margin = normalizeMargin(cfg.margin, { x = 20, y = 20 })
	cfg.offset = normalizeMargin(cfg.offset or { x = 0, y = 0 }, { x = 0, y = 0 })
	if cfg.sectionOrder then cfg.sectionOrder = copyArray(cfg.sectionOrder) end
	if cfg.sectionGroups then cfg.sectionGroups = copyGroups(cfg.sectionGroups) end
	if not cfg.noteFontSize then cfg.noteFontSize = cfg.fontSize - 2 end
	if cfg.noteFontSize > cfg.fontSize then cfg.noteFontSize = math.max(cfg.fontSize - 2, 8) end
	if cfg.noteFontSize < 8 then cfg.noteFontSize = 8 end
	if cfg.sectionFontSize > cfg.fontSize then cfg.sectionFontSize = math.max(cfg.fontSize - 2, 10) end
	cfg.groupGap = cfg.groupGap or cfg.sectionGap
	cfg.footerSpacing = cfg.footerSpacing or cfg.sectionGap
	return cfg, meta
end

local function normalizeBindings(mode_name, bindings, config)
	local normalized = {}

	if bindings then
		for key, value in pairs(bindings) do
			if type(value) == 'table' then
				normalized[key] = copyTable(value)
				normalized[key].key = normalized[key].key or key
			elseif type(value) == 'string' then
				normalized[key] = { description = value, key = key }
			end
		end
	end

	local exit_desc = string.format('Exit %s mode', tostring(mode_name))
	ExitKeys.ensure(normalized, {
		modeName = mode_name,
		description = exit_desc,
		exitSection = config.exitSection,
	})

	for key, entry in pairs(normalized) do
		entry.key = entry.key or key
		entry.displayKey = entry.displayKey or entry.key
		if entry.label == nil or entry.label == '' then
			entry.label = entry.key
		end
		if not entry.section then
			entry.section = entry.isExit and config.exitSection or config.defaultSection
		end
		if entry.lines and entry.lines < 1 then entry.lines = 1 end
	end

	return normalized
end

local function sortKeys(bindings)
	local keys = {}
	for key, binding in pairs(bindings) do
		if binding and type(binding) == 'table' and binding.description and binding.description ~= '' then
			table.insert(keys, key)
		end
	end

	table.sort(keys, function (a, b)
		local A, B = bindings[a], bindings[b]
		local exitA = A and A.isExit or false
		local exitB = B and B.isExit or false
		if exitA ~= exitB then
			return not exitA
		end
		local orderA = A and A.order or math.huge
		local orderB = B and B.order or math.huge
		if orderA ~= orderB then return orderA < orderB end
		return a < b
	end)

	return keys
end

local function buildSections(bindings, config)
	local sections = {}
	local seenOrder = {}
	local orderList = {}
	for _, key in ipairs(sortKeys(bindings)) do
		local binding = bindings[key]
		if binding then
			local section = binding.section or config.defaultSection
			sections[section] = sections[section] or {}
			table.insert(sections[section], key)
			if not seenOrder[section] then
				seenOrder[section] = true
				table.insert(orderList, section)
			end
		end
	end

	if config.sectionOrder and #config.sectionOrder > 0 then
		local merged = {}
		local added = {}
		for _, section in ipairs(config.sectionOrder) do
			if sections[section] and not added[section] then
				table.insert(merged, section)
				added[section] = true
			end
		end
		for _, section in ipairs(orderList) do
			if not added[section] then
				table.insert(merged, section)
				added[section] = true
			end
		end
		orderList = merged
	end

	return orderList, sections
end

local function computeRowMetrics(binding, config)
	local description = binding.description or ''
	local explicitLines = select(2, description:gsub('\n', '\n')) + 1
	local wrap = (config.wrapDescriptions and binding.wrap ~= false) or binding.wrap == true
	local lines = binding.lines or explicitLines
	if lines < explicitLines then lines = explicitLines end
	if not wrap and binding.lines == nil then
		lines = explicitLines
	end
	if binding.multiline == false then lines = 1 end
	if lines < 1 then lines = 1 end

	local descHeight = config.fontSize * lines + config.lineSpacing * (lines - 1)
	if descHeight < config.fontSize then descHeight = config.fontSize end

	local includeNotes = config.showNotes ~= false
	local hasNote = includeNotes and binding.note and binding.note ~= ''
	local noteHeight = 0
	if hasNote then
		local noteLines = select(2, binding.note:gsub('\n', '\n')) + 1
		local noteHeightValue = (config.noteFontSize * noteLines) + config.lineSpacing * (noteLines - 1)
		noteHeight = math.floor(noteHeightValue + 0.5)
	end

	local contentHeight = descHeight + (hasNote and (config.noteSpacing + noteHeight) or 0)
	local rowHeight = contentHeight + config.rowSpacing
	local lineBreak = (wrap and 'wordWrap') or 'truncateTail'

	return {
		lines = lines,
		wrap = wrap,
		descHeight = descHeight,
		noteHeight = noteHeight,
		hasNote = hasNote,
		contentHeight = contentHeight,
		rowHeight = rowHeight,
		lineBreak = lineBreak,
	}
end

local function chooseColor(binding, config, keyType)
	if binding and binding.color then
		return copyTable(binding.color)
	end
	if keyType == 'key' then
		if binding.isExit then return copyTable(config.exitKeyColor) end
		if binding.isChord then return copyTable(config.chordKeyColor) end
		return copyTable(config.keyColor)
	end
	if keyType == 'desc' then
		if binding.isExit then return copyTable(config.exitDescColor) end
		return copyTable(config.descColor)
	end
	if keyType == 'note' then
		return copyTable(config.noteColor)
	end
	return { white = 1.0, alpha = 1.0 }
end

local function appendRowElements(elements, binding, key, config, y, descWidth)
	local metrics = computeRowMetrics(binding, config)
	local keyLabel = binding.displayKey or binding.keyLabel or binding.label or binding.key or key
	local keyText
	if binding.isChord then
		local brackets = config.chordBrackets or { '⟨', '⟩' }
		keyText = string.format('%s%s%s', brackets[1] or '⟨', keyLabel, brackets[2] or '⟩')
	else
		keyText = string.format('[%s]', keyLabel)
	end

	local keyColor = chooseColor(binding, config, 'key')
	local descColor = chooseColor(binding, config, 'desc')

	local contentHeight = metrics.contentHeight
	local keyElement = {
		type = 'text',
		text = keyText,
		textFont = config.fontName,
		textSize = config.fontSize,
		textColor = keyColor,
		textAlignment = 'left',
		frame = {
			x = config.padding,
			y = y,
			w = config.keyColumnWidth,
			h = contentHeight,
		}
	}
	table.insert(elements, keyElement)

	local descElement = {
		type = 'text',
		text = binding.description or '',
		textFont = config.fontName,
		textSize = config.fontSize,
		textColor = descColor,
		textAlignment = binding.descAlignment or config.descAlignment,
		textLineBreak = metrics.lineBreak,
		frame = {
			x = config.padding + config.keyColumnWidth + config.descColumnGap,
			y = y,
			w = descWidth,
			h = metrics.descHeight,
		}
	}
	table.insert(elements, descElement)

	if metrics.hasNote then
		local noteElement = {
			type = 'text',
			text = binding.note,
			textFont = config.fontName,
			textSize = config.noteFontSize,
			textColor = chooseColor(binding, config, 'note'),
			textAlignment = binding.descAlignment or config.descAlignment,
			textLineBreak = 'wordWrap',
			frame = {
				x = config.padding + config.keyColumnWidth + config.descColumnGap,
				y = y + metrics.descHeight + config.noteSpacing,
				w = descWidth,
				h = metrics.noteHeight,
			}
		}
		table.insert(elements, noteElement)
	end

	return metrics.rowHeight
end

local function appendSectionHeader(elements, section, config, current_y, canvas_width)
	local headerHeight = config.sectionFontSize + config.sectionHeaderSpacing
	local element = {
		type = 'text',
		text = section,
		textFont = config.fontName,
		textSize = config.sectionFontSize,
		textColor = copyTable(config.sectionColor),
		textAlignment = 'left',
		frame = {
			x = config.padding,
			y = current_y,
			w = canvas_width - (2 * config.padding),
			h = config.sectionFontSize + config.sectionHeaderSpacing,
		}
	}
	table.insert(elements, element)
	return headerHeight
end

local function appendGroupHeader(elements, label, config, current_y, canvas_width)
	if not label or label == '' then return 0 end
	local height = config.groupHeaderFontSize
	local element = {
		type = 'text',
		text = label,
		textFont = config.fontName,
		textSize = config.groupHeaderFontSize,
		textColor = copyTable(config.groupHeaderColor),
		textAlignment = 'left',
		frame = {
			x = config.padding,
			y = current_y,
			w = canvas_width - (2 * config.padding),
			h = height,
		}
	}
	table.insert(elements, element)
	return height + config.groupHeaderSpacing
end

local function buildGroupPlan(sectionOrder, sections, config)
	local plan = {}
	local assigned = {}
	local diagnostics = {}

	if type(config.sectionGroups) == 'table' then
		for _, group in ipairs(config.sectionGroups) do
			if type(group) == 'table' then
				local label = group.label
				local groupSections = {}
				for _, sectionName in ipairs(group.sections or {}) do
					if sections[sectionName] then
						if not assigned[sectionName] then
							assigned[sectionName] = true
							table.insert(groupSections, sectionName)
						else
							diagnostics.duplicateGroupSections = diagnostics.duplicateGroupSections or {}
							table.insert(diagnostics.duplicateGroupSections, { group = label, section = sectionName })
						end
					else
						diagnostics.missingGroupSections = diagnostics.missingGroupSections or {}
						table.insert(diagnostics.missingGroupSections, { group = label, section = sectionName })
					end
				end
				if #groupSections > 0 then
					table.insert(plan, {
						type = 'group',
						label = label,
						sections = groupSections,
					})
				elseif group.sections and #group.sections > 0 then
					diagnostics.emptyGroups = diagnostics.emptyGroups or {}
					table.insert(diagnostics.emptyGroups, label or '')
				end
			end
		end
	end

	for _, section in ipairs(sectionOrder) do
		if sections[section] then
			if not assigned[section] then
				assigned[section] = true
				table.insert(plan, { type = 'section', section = section })
			end
		else
			diagnostics.unresolvedSectionOrder = diagnostics.unresolvedSectionOrder or {}
			table.insert(diagnostics.unresolvedSectionOrder, section)
		end
	end

	for sectionName in pairs(sections) do
		if not assigned[sectionName] then
			assigned[sectionName] = true
			table.insert(plan, { type = 'section', section = sectionName })
		end
	end

	local hasDiagnostics = false
	for _, list in pairs(diagnostics) do
		if list and #list > 0 then
			hasDiagnostics = true
		end
	end
	local resultDiagnostics = nil
	if hasDiagnostics then resultDiagnostics = diagnostics end

	return plan, resultDiagnostics
end

local function summarizeSections(sectionOrder, sections, normalized)
	local summaries = {}
	local index = {}
	for _, name in ipairs(sectionOrder) do
		local keys = sections[name]
		if keys and #keys > 0 then
			local entries = {}
			for _, key in ipairs(keys) do
				local binding = normalized[key] or {}
				entries[#entries + 1] = {
					key = key,
					displayKey = binding.displayKey or binding.keyLabel or binding.label or binding.key or key,
					description = binding.description or '',
					section = binding.section or name,
					order = binding.order,
					isExit = binding.isExit,
					isChord = binding.isChord,
					passive = binding.passive,
					note = binding.note,
				}
			end
			local summary = { name = name, count = #entries, entries = entries }
			summaries[#summaries + 1] = summary
			index[name] = summary
		end
	end
	return summaries, index
end

local function summarizePlan(plan, sectionIndex)
	local out = {}
	for _, entry in ipairs(plan or {}) do
		if entry.type == 'group' then
			local sections = {}
			for _, name in ipairs(entry.sections or {}) do
				if sectionIndex[name] then sections[#sections + 1] = sectionIndex[name] end
			end
			out[#out + 1] = { type = 'group', label = entry.label, sections = sections, count = #sections }
		elseif entry.type == 'section' then
			if sectionIndex[entry.section] then
				out[#out + 1] = { type = 'section', section = sectionIndex[entry.section] }
			end
		end
	end
	return out
end

local function prepareGuiSpec(mode_name, bindings, layout)
	local config, meta = mergeConfig(layout)
	local normalized = normalizeBindings(mode_name, bindings, config)
	local sectionOrder, sections = buildSections(normalized, config)
	local plan, diagnostics = buildGroupPlan(sectionOrder, sections, config)
	local sectionSummaries, sectionIndex = summarizeSections(sectionOrder, sections, normalized)
	local bindingCount = 0
	for _, summary in ipairs(sectionSummaries) do bindingCount = bindingCount + (summary.count or 0) end
	return {
		modeName = mode_name,
		config = config,
		normalized = normalized,
		sectionOrder = sectionOrder,
		sections = sections,
		plan = plan,
		diagnostics = diagnostics,
		meta = meta,
		sectionSummaries = sectionSummaries,
		sectionIndex = sectionIndex,
		bindingCount = bindingCount,
	}
end

local function computePosition(config, width, height)
	local scr = screen.mainScreen()
	local frame = scr:frame()
	local anchor = string.lower(config.anchor or 'bottom-right')
	local margin = config.margin or { x = 20, y = 20 }
	local offset = config.offset or { x = 0, y = 0 }

	local x
	if anchor:find('left', 1, true) then
		x = frame.x + margin.x
	elseif anchor:find('center', 1, true) and not anchor:find('right', 1, true) then
		x = frame.x + (frame.w - width) / 2
	else
		x = frame.x + frame.w - width - margin.x
	end

	local y
	if anchor:find('top', 1, true) then
		y = frame.y + margin.y
	elseif anchor:find('middle', 1, true) or (anchor:find('center', 1, true) and not anchor:find('top', 1, true) and not anchor:find('bottom', 1, true)) then
		y = frame.y + (frame.h - height) / 2
	else
		y = frame.y + frame.h - height - margin.y
	end

	return x + offset.x, y + offset.y
end

function M.show(mode_name, bindings, layout)
	M.hide()

	local spec = prepareGuiSpec(mode_name, bindings, layout)
	if not spec then
		logError('modal_gui: Failed to prepare GUI spec for mode: ' .. tostring(mode_name))
		return
	end

	if spec.meta.presetMissing ~= nil then
		logWarn(string.format('modal_gui: layout preset "%s" not found; using base defaults', tostring(spec.meta.preset)))
	end

	local bindingCount = spec.bindingCount or 0
	if bindingCount == 0 or #spec.sectionOrder == 0 then
		logInfo('modal_gui: No bindings to show for mode: ' .. tostring(mode_name))
		return
	end

	if not spec.plan or #spec.plan == 0 then
		logInfo('modal_gui: No layout plan for mode: ' .. tostring(mode_name))
		return
	end

	local diagnostics = spec.diagnostics
	if diagnostics ~= nil then
		local missing = diagnostics.missingGroupSections
		if missing and #missing > 0 then
			for _, entry in ipairs(missing) do
				logWarn(string.format('modal_gui: group "%s" references missing section "%s"', tostring(entry.group), tostring(entry.section)))
			end
		end
		local duplicates = diagnostics.duplicateGroupSections
		if duplicates and #duplicates > 0 then
			for _, entry in ipairs(duplicates) do
				logWarn(string.format('modal_gui: section "%s" claimed multiple times (group="%s")', tostring(entry.section), tostring(entry.group)))
			end
		end
		local unresolved = diagnostics.unresolvedSectionOrder
		if unresolved and #unresolved > 0 then
			logWarn('modal_gui: sectionOrder entries with no bindings -> ' .. table.concat(unresolved, ', '))
		end
		local emptyGroups = diagnostics.emptyGroups
		if emptyGroups and #emptyGroups > 0 then
			logWarn('modal_gui: configured empty section groups -> ' .. table.concat(emptyGroups, ', '))
		end
	end

	last_mode_name = mode_name
	local config = spec.config
	local normalized = spec.normalized
	local sections = spec.sections
	local plan = spec.plan
	local elements = {}
	local current_y = config.padding
	local canvas_width = config.width

	if config.showTitle then
		local title
		if type(layout) == 'table' and layout.title then
			title = layout.title
		elseif config.title then
			title = config.title
		else
			title = mode_name
		end
		table.insert(elements, {
			type = 'text',
			text = title,
			textFont = config.fontName,
			textSize = config.fontSize + 4,
			textColor = copyTable(config.titleColor),
			textAlignment = 'left',
			frame = { x = config.padding, y = current_y, w = canvas_width - (2 * config.padding), h = config.fontSize + config.titleExtra }
		})
		current_y = current_y + config.fontSize + config.titleExtra + config.rowSpacing
	end

	local descWidth = canvas_width - (2 * config.padding) - config.keyColumnWidth - config.descColumnGap
	if descWidth < 40 then descWidth = 40 end

	local function renderSection(sectionName, skipGapBefore)
		local keys = sections[sectionName]
		if not keys or #keys == 0 then return end
		if not skipGapBefore then
			current_y = current_y + config.sectionGap
		end
		if config.showSectionHeaders and sectionName ~= '' then
			current_y = current_y + appendSectionHeader(elements, sectionName, config, current_y, canvas_width)
		end
		for _, key in ipairs(keys) do
			local binding = normalized[key]
			if binding ~= nil then
				local rowHeight = appendRowElements(elements, binding, key, config, current_y, descWidth)
				current_y = current_y + rowHeight
			end
		end
	end

	for index, entry in ipairs(plan) do
		if entry.type == 'group' then
			if index > 1 then
				current_y = current_y + (config.groupGap or config.sectionGap or 12)
			end
			if config.showGroupHeaders and entry.label and entry.label ~= '' then
				current_y = current_y + appendGroupHeader(elements, entry.label, config, current_y, canvas_width)
			end
			for sectionIndex, sectionName in ipairs(entry.sections) do
				renderSection(sectionName, sectionIndex == 1)
			end
		elseif entry.type == 'section' then
			renderSection(entry.section, index == 1)
		end
	end

	if config.footerText and config.footerText ~= '' then
		current_y = current_y + config.footerSpacing
		table.insert(elements, {
			type = 'text',
			text = config.footerText,
			textFont = config.fontName,
			textSize = config.footerFontSize,
			textColor = copyTable(config.footerColor),
			textAlignment = config.footerAlignment or 'right',
			frame = {
				x = config.padding,
				y = current_y,
				w = canvas_width - (2 * config.padding),
				h = config.footerFontSize + config.sectionHeaderSpacing,
			}
		})
		current_y = current_y + config.footerFontSize + config.sectionHeaderSpacing
	end

	if #elements == 0 then
		if logger and logger.info then
			logger.info('modal_gui: No elements to display for mode: ' .. tostring(mode_name))
		end
		return
	end

	local canvas_height = current_y + config.padding - config.rowSpacing
	if canvas_height < (config.padding * 2 + config.fontSize) then
		canvas_height = config.padding * 2 + config.fontSize
	end

	local canvas_x, canvas_y = computePosition(config, canvas_width, canvas_height)

	gui_canvas = canvas.new({ x = canvas_x, y = canvas_y, w = canvas_width, h = canvas_height })
	if not gui_canvas then
		if logger and logger.error then
			logger.error('modal_gui: Failed to create canvas.')
		end
		return
	end

	gui_canvas:level(canvas.windowLevels.modalPanel)
	gui_canvas:behavior(canvas.windowBehaviors.canJoinAllSpaces)

	table.insert(elements, 1, {
		type = 'rectangle',
		fillColor = copyTable(config.backgroundColor),
		strokeColor = { alpha = 0 },
		roundedRectRadii = { xRadius = 8, yRadius = 8 },
		frame = { x = 0, y = 0, w = canvas_width, h = canvas_height }
	})

	gui_canvas:replaceElements(elements)
	gui_canvas:show()
end

function M.hide(mode_name)
	if gui_canvas == nil then return end
	if mode_name ~= nil and mode_name ~= last_mode_name then return end
	gui_canvas:delete()
	gui_canvas = nil
	last_mode_name = nil
end

function M.compile(mode_name, bindings, layout)
	return prepareGuiSpec(mode_name, bindings, layout)
end

local function collectWarnings(spec)
	local warnings = {}
	if spec.meta and spec.meta.presetMissing then
		warnings[#warnings + 1] = string.format('Layout preset "%s" was not found; base defaults applied.', tostring(spec.meta.preset))
	end
	local diagnostics = spec.diagnostics or {}
	for _, entry in ipairs(diagnostics.missingGroupSections or {}) do
		warnings[#warnings + 1] = string.format('Group "%s" references missing section "%s".', tostring(entry.group), tostring(entry.section))
	end
	for _, entry in ipairs(diagnostics.duplicateGroupSections or {}) do
		warnings[#warnings + 1] = string.format('Section "%s" is assigned multiple times (group "%s").', tostring(entry.section), tostring(entry.group))
	end
	if diagnostics.unresolvedSectionOrder and #diagnostics.unresolvedSectionOrder > 0 then
		warnings[#warnings + 1] = 'sectionOrder entries without bindings: ' .. table.concat(diagnostics.unresolvedSectionOrder, ', ')
	end
	if diagnostics.emptyGroups and #diagnostics.emptyGroups > 0 then
		warnings[#warnings + 1] = 'Empty section groups configured: ' .. table.concat(diagnostics.emptyGroups, ', ')
	end
	return warnings
end

function M.inspect(mode_name, bindings, layout, opts)
	local spec = prepareGuiSpec(mode_name, bindings, layout)
	if not spec then return nil end

	local sections = spec.sectionSummaries or {}
	local planSummary = summarizePlan(spec.plan, spec.sectionIndex)
	local groupCount = 0
	for _, entry in ipairs(planSummary) do
		if entry.type == 'group' then groupCount = groupCount + 1 end
	end

	local summary = {
		modeName = mode_name,
		preset = spec.meta and spec.meta.preset or nil,
		bindingCount = spec.bindingCount or 0,
		sectionCount = #sections,
		groupCount = groupCount,
		sections = sections,
		plan = planSummary,
		diagnostics = spec.diagnostics,
		warnings = collectWarnings(spec),
		config = copyTable(spec.config),
	}

	if opts and opts.includeNormalized then
		summary.normalized = copyTable(spec.normalized)
	end

	if opts and opts.log then
		logInfo(string.format('modal_gui.inspect: mode "%s" (%d bindings, %d sections, preset=%s)', mode_name, summary.bindingCount, summary.sectionCount, summary.preset or 'default'))
		for _, section in ipairs(sections) do
			logInfo(string.format('  section %s (%d)', section.name, section.count))
			for _, entry in ipairs(section.entries or {}) do
				local tags = {}
				if entry.isChord then tags[#tags + 1] = 'chord' end
				if entry.isExit then tags[#tags + 1] = 'exit' end
				if entry.passive then tags[#tags + 1] = 'passive' end
				local suffix = (#tags > 0) and (' [' .. table.concat(tags, ',') .. ']') or ''
				logInfo(string.format('    %s -> %s%s', entry.displayKey or entry.key, entry.description or '', suffix))
			end
		end
		for _, warning in ipairs(summary.warnings) do
			logWarn('  warning: ' .. warning)
		end
	end

	return summary
end

function M.listPresets()
	return Layouts.list()
end

function M.describePreset(name)
	return Layouts.describe(name)
end

return M

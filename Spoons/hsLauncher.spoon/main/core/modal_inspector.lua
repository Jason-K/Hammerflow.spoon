local HyperModal = require('hsLauncher.main.core.hyper_modal')
local ModalGUI = require('hsLauncher.main.core.modal_gui')
local logger = require('hsLauncher.main.core.logger')

local M = {}

local function buildBindings(entries)
	local result = {}
	for _, entry in ipairs(entries or {}) do
		if entry.key then
			result[entry.key] = {
				key = entry.key,
				displayKey = entry.displayKey,
				keyLabel = entry.displayKey,
				label = entry.displayKey,
				description = entry.description,
				section = entry.section,
				order = entry.order,
				isExit = entry.isExit,
				isChord = entry.isChord,
				passive = entry.passive,
				note = entry.note,
			}
		end
	end
	return result
end

local function inspectMode(name, modeInfo, opts)
	local bindings = buildBindings(modeInfo.entries)
	return ModalGUI.inspect(name, bindings, modeInfo.layout, opts)
end

function M.inspect(name, opts)
	if type(name) ~= 'string' or name == '' then
		if logger then logger.warn('modal_inspector: mode name required for inspect()') end
		return nil
	end
	local modeInfo = HyperModal.describeMode(name)
	if not modeInfo then
		if not (opts and opts.silent) and logger then
			logger.warn('modal_inspector: unknown mode ' .. tostring(name))
		end
		return nil
	end
	return inspectMode(name, modeInfo, opts)
end

function M.inspectActive(opts)
	local name = HyperModal.currentMode
	if not name or name == '' then
		if not (opts and opts.silent) and logger then
			logger.info('modal_inspector: no active mode to inspect')
		end
		return nil
	end
	return M.inspect(name, opts)
end

function M.inspectAll(opts)
	local modes = HyperModal.listModes()
	local out = {}
	for name, info in pairs(modes or {}) do
		out[name] = inspectMode(name, info, opts)
	end
	return out
end

function M.list()
	local modes = HyperModal.listModes()
	local names = {}
	for name in pairs(modes or {}) do table.insert(names, name) end
	table.sort(names)
	return names
end

function M.log(name)
	return M.inspect(name, { log = true })
end

return M

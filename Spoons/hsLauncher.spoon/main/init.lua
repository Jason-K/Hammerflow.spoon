-- hsLauncher entrypoint with leader Window mode and chord bindings

local logger = require('hsLauncher.main.core.logger')
local hyper = require('hsLauncher.main.core.hyper_modal')
local win = require('hsLauncher.main.core.windows_native')
local assignHK = require('hsLauncher.main.modules.hotkeys.assign_hotkey')
local assignGlobal = require('hsLauncher.main.modules.hotkeys.assign_global')
local globalShortcuts = require('hsLauncher.main.modules.hotkeys.global_shortcuts')
local hsWindow = require('hs.window')
local Actions = require('hsLauncher.main.core.actions')
local leaderConfig = require('hsLauncher.main.core.leader_config')
local userRegistry = require('hsLauncher.main.user.registry')
local HotkeyManifest = require('hsLauncher.main.core.hotkey_manifest')

local M = {}

local function userAction(id)
	local spec = userRegistry.resolveAction(id)
	if spec then return spec end
	logger.error(string.format('hsLauncher: missing user action %s', tostring(id)))
	return Actions.noop()
end

local function applyUserHotkeys()
	local ok, config = pcall(require, 'hsLauncher.main.user.hotkeys')
	if not ok then
		local reason = tostring(config)
		if not reason:match('module .+ not found') then
			logger.error('hsLauncher: unable to load user hotkeys -> ' .. reason)
		end
		return
	end

	local fn = config
	if type(config) == 'table' then
		fn = config.configure or config.apply or config[1]
	end

	if type(fn) ~= 'function' then
		logger.error('hsLauncher: user hotkeys module must return a function or table.configure')
		return
	end

	local context = {
		hyper = hyper,
		win = win,
		hsWindow = hsWindow,
		logger = logger,
		Actions = Actions,
		userAction = userAction,
		assignHotkey = assignHK,
		assignGlobal = assignGlobal,
		userRegistry = userRegistry,
	}

	local okConfig, err = pcall(fn, context)
	if not okConfig then
		logger.error('hsLauncher: user hotkeys configuration failed -> ' .. tostring(err))
	end
end

local function reportManifestValidation()
	local result = HotkeyManifest.validate()
	if not result then return end
	for _, issue in ipairs(result.warnings or {}) do
		logger.warn(string.format('[hotkey-manifest] %s', issue.message or 'Warning emitted without message'))
	end
	if result.ok then return end
	for _, issue in ipairs(result.errors or {}) do
		logger.error(string.format('[hotkey-manifest] %s', issue.message or 'Validation error without message'))
	end
	logger.error(
	'hsLauncher: hotkey manifest validation failed; resolve the errors above to ensure reliable hotkey behavior.')
end

function M.start()
	logger.info('hsLauncher start')
	HotkeyManifest.clear()
	hyper.start()
	local cfg = require('hsLauncher.main.core.config')
	win.init(cfg.windows)
	globalShortcuts.start()

	userRegistry.load()
	leaderConfig.registerFromModules()
	local contrib = userRegistry.contributions()
	local addSequence = hyper.addSequenceSpec and function (spec)
		hyper.addSequenceSpec(spec)
	end or function (spec)
		hyper.addSequence(spec.keys, spec.fn)
	end
	for index, seq in ipairs(contrib.sequences or {}) do
		if seq.mode then
			addSequence({
				keys = seq.keys,
				fn = function ()
					hyper.enterMode(seq.mode)
				end,
				description = seq.description or string.format('Enter contributed mode %s', seq.mode),
				label = seq.label,
				note = seq.note,
				metadata = {
					mode = seq.mode,
					contributor = seq.contributor,
					module = seq.module,
				},
				tags = seq.tags,
				source = seq.source or string.format('user.registry:sequence[%d]', index),
			})
		elseif seq.actionId then
			local spec = userRegistry.resolveAction(seq.actionId)
			if spec then
				addSequence({
					keys = seq.keys,
					fn = function ()
						local fn = Actions.resolve(spec)
						if fn then fn() end
					end,
					description = seq.description or string.format('Trigger contributed action %s', seq.actionId),
					label = seq.label,
					note = seq.note,
					metadata = {
						actionId = seq.actionId,
						contributor = seq.contributor,
						module = seq.module,
					},
					tags = seq.tags,
					source = seq.source or string.format('user.registry:sequence[%d]', index),
				})
			end
		end
	end

	applyUserHotkeys()
	reportManifestValidation()
end

function M.stop()
	globalShortcuts.stop()
	hyper.stop()
	logger.info('hsLauncher stop')
end

return M

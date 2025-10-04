-- hsLauncher entrypoint with support for declarative runtime feature flag

local logger = require('hsLauncher.main.core.logger')
local userRegistry = require('hsLauncher.main.user.registry')

local runtimeModule
local runtimeMode
local legacyDeps

local M = {}

local function declarativeRuntime()
	if runtimeModule == nil then
		runtimeModule = require('hsLauncher.main.runtime.init')
	end
	return runtimeModule
end

local function ensureLegacyDeps()
	if legacyDeps ~= nil then return legacyDeps end
	legacyDeps = {
		hyper = require('hsLauncher.main.core.hyper_modal'),
		win = require('hsLauncher.main.core.windows_native'),
		assignHotkey = require('hsLauncher.main.modules.hotkeys.assign_hotkey'),
		assignGlobal = require('hsLauncher.main.modules.hotkeys.assign_global'),
		globalShortcuts = require('hsLauncher.main.modules.hotkeys.global_shortcuts'),
		hsWindow = require('hs.window'),
		Actions = require('hsLauncher.main.core.actions'),
		leaderConfig = require('hsLauncher.main.core.leader_config'),
		HotkeyManifest = require('hsLauncher.main.core.hotkey_manifest'),
	}
	return legacyDeps
end

local function legacyUserAction(id)
	local deps = ensureLegacyDeps()
	local spec = userRegistry.resolveAction(id)
	if spec then return spec end
	logger.error(string.format('hsLauncher: missing user action %s', tostring(id)))
	return deps.Actions.noop()
end

local function applyLegacyUserHotkeys()
	local deps = ensureLegacyDeps()
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
		hyper = deps.hyper,
		win = deps.win,
		hsWindow = deps.hsWindow,
		logger = logger,
		Actions = deps.Actions,
		userAction = legacyUserAction,
		assignHotkey = deps.assignHotkey,
		assignGlobal = deps.assignGlobal,
		userRegistry = userRegistry,
	}

	local okConfig, err = pcall(fn, context)
	if not okConfig then
		logger.error('hsLauncher: user hotkeys configuration failed -> ' .. tostring(err))
	end
end

local function reportLegacyManifestValidation()
	local deps = ensureLegacyDeps()
	local result = deps.HotkeyManifest.validate()
	if not result then return end
	for _, issue in ipairs(result.warnings or {}) do
		logger.warn(string.format('[hotkey-manifest] %s', issue.message or 'Warning emitted without message'))
	end
	if result.ok then return end
	for _, issue in ipairs(result.errors or {}) do
		logger.error(string.format('[hotkey-manifest] %s', issue.message or 'Validation error without message'))
	end
	logger.error('hsLauncher: hotkey manifest validation failed; resolve the errors above to ensure reliable hotkey behavior.')
end

local function startLegacy(options)
	local deps = ensureLegacyDeps()
	deps.HotkeyManifest.clear()
	deps.hyper.start()
	local cfg = require('hsLauncher.main.core.config')
	deps.win.init(cfg.windows)
	deps.globalShortcuts.start(options)

	userRegistry.load()
	deps.leaderConfig.registerFromModules()
	local contrib = userRegistry.contributions()
	local addSequence = deps.hyper.addSequenceSpec and function(spec)
		deps.hyper.addSequenceSpec(spec)
	end or function(spec)
		deps.hyper.addSequence(spec.keys, spec.fn)
	end
	for index, seq in ipairs(contrib.sequences or {}) do
		if seq.mode then
			addSequence({
				keys = seq.keys,
				fn = function()
					deps.hyper.enterMode(seq.mode)
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
					fn = function()
						local fn = deps.Actions.resolve(spec)
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

	applyLegacyUserHotkeys()
	reportLegacyManifestValidation()
	runtimeMode = 'legacy'
end

local function stopLegacy()
	if runtimeMode ~= 'legacy' then return end
	local deps = ensureLegacyDeps()
	deps.globalShortcuts.stop()
	deps.hyper.stop()
	runtimeMode = nil
end

local function startDeclarative(options)
	local runtime = declarativeRuntime()
	if not runtime or type(runtime.start) ~= 'function' then
		return nil, 'declarative runtime module missing start()'
	end
	local instance, err = runtime.start(options)
	if not instance then
		return nil, err
	end
	runtimeMode = 'declarative'
	return instance
end

local function stopDeclarative()
	if runtimeMode ~= 'declarative' then return end
	local runtime = declarativeRuntime()
	if type(runtime) ~= 'table' or type(runtime.stop) ~= 'function' then
		runtimeMode = nil
		return
	end
	runtime.stop()
	runtimeMode = nil
end

function M.start(options)
	logger.info('hsLauncher start')
	local state = userRegistry.load()
	local features = (state and state.features) or {}
	local envFlag = os.getenv('HSLAUNCHER_DECLARATIVE_RUNTIME')
	local envEnabled = envFlag == '1' or envFlag == 'true' or envFlag == 'yes' or envFlag == 'on'

	if features.declarativeRuntime or envEnabled then
		local instance, err = startDeclarative(options)
		if instance then
			return M
		end
		logger.error('hsLauncher: declarative runtime failed -> ' .. tostring(err))
		logger.warn('hsLauncher: falling back to legacy runtime')
	end

	startLegacy(options)
	return M
end

function M.stop()
	if runtimeMode == 'declarative' then
		stopDeclarative()
	elseif runtimeMode == 'legacy' then
		stopLegacy()
	end
	logger.info('hsLauncher stop')
end

return M

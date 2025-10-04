--- @diagnostic disable: undefined-global

local Actions = require('hsLauncher.main.core.actions')

return function (context)
	local hyper = context.hyper
	local win = context.win
	local hsWindow = context.hsWindow
	local assignHotkey = context.assignHotkey or {}
	local assignGlobal = context.assignGlobal or {}
	local logger = context.logger or require('hsLauncher.main.core.logger')
	local userRegistry = context.userRegistry

	local function extractArg(args, key, index, default)
		if not args then return default end
		if type(args) == 'table' then
			if args[key] ~= nil then return args[key] end
			if args[index] ~= nil then return args[index] end
		end
		return default
	end

	local handlers = {}

	function handlers.moveScreen(args)
		local direction = extractArg(args, 'direction', 1, 'west')
		return Actions.call(function ()
			local window = hsWindow and hsWindow.focusedWindow()
			if not window then return end
			if direction == 'west' then
				window:moveOneScreenWest(false, true)
			elseif direction == 'east' then
				window:moveOneScreenEast(false, true)
			elseif direction == 'north' then
				window:moveOneScreenNorth(false, true)
			elseif direction == 'south' then
				window:moveOneScreenSouth(false, true)
			end
		end)
	end

	function handlers.enterMode(args)
		local mode = extractArg(args, 'mode', 1)
		if not mode or not hyper then return Actions.noop() end
		return Actions.call(function ()
			hyper.enterMode(mode)
		end)
	end

	function handlers.showDisplayNumbers()
		if not win or not win.showDisplayNumbers then return Actions.noop() end
		return Actions.call(function ()
			win.showDisplayNumbers()
		end)
	end

	function handlers.hideDisplayNumbers()
		if not win or not win.hideDisplayNumbers then return Actions.noop() end
		return Actions.call(function ()
			win.hideDisplayNumbers()
		end)
	end

	function handlers.assignHotkey()
		if not assignHotkey or not assignHotkey.assign then return Actions.noop() end
		return Actions.call(function ()
			assignHotkey.assign()
		end)
	end

	function handlers.assignGlobal()
		if not assignGlobal or not assignGlobal.assignForFrontmost then return Actions.noop() end
		return Actions.call(function ()
			assignGlobal.assignForFrontmost()
		end)
	end

	function handlers.removeGlobal()
		if not assignGlobal or not assignGlobal.removeForFrontmost then return Actions.noop() end
		return Actions.call(function ()
			assignGlobal.removeForFrontmost()
		end)
	end

	function handlers.listGlobals()
		if not assignGlobal or not assignGlobal.listForFrontmost then return Actions.noop() end
		return Actions.call(function ()
			assignGlobal.listForFrontmost()
		end)
	end

	function handlers.revealLatestDownload()
		return Actions.shell(
		[[latest=$(ls -t "$HOME/Downloads" | head -n1); [ -n "$latest" ] && open -R "$HOME/Downloads/$latest"]])
	end

	function handlers.openDownloadsFolder()
		return Actions.open({ path = os.getenv('HOME') .. '/Downloads' })
	end

	function handlers.log(args)
		local level = extractArg(args, 'level', 1, 'info')
		local message = extractArg(args, 'message', 2, '')
		return Actions.call(function ()
			if logger and type(logger[level]) == 'function' then
				logger[level](message)
			end
		end)
	end

	function handlers.reloadUserAction(args)
		if not userRegistry or not userRegistry.reload then return Actions.noop() end
		local moduleId = extractArg(args, 'module', 1)
		return Actions.call(function ()
			userRegistry.reload(moduleId)
		end)
	end

	return handlers
end

--- safeLoadSpoon.spoon
---
--- Safely loads a Spoon with error handling.
---

local obj = {}
obj.name = "SafeLoad"
obj.version = "1.1"
obj.author = "Jason-K"
obj.license = "MIT"
obj.homepage = "https://github.com/Jason-K/.hammerspoon"
obj.logger = hs.logger.new(obj.name, "debug")
-- obj.spoonInstaller = hs.loadSpoon("SpoonInstall")

-- if not obj.spoonInstaller then
--     obj.logger:e("SpoonInstall is not available. Please install it.")
--     hs.alert.show("SpoonInstall not found!")
--     return obj
-- end

-- -- Update SpoonInstall repos
-- obj.spoonInstaller:asyncUpdateAllRepos()

--- SafeLoad.load(spoonName, [arg]) -> spoonObject | nil
--- Method
--- Safely loads a Spoon with error handling. If the Spoon is not found,
--- it offers to install it using SpoonInstall.
---
--- Parameters:
---  * spoonName - The name of the Spoon to load.
---  * arg - An optional table of arguments for SpoonInstall:andUse.
---
--- Returns:
---  * The Spoon object if successful, otherwise nil.
function obj:load(spoonName, arg)
	arg = arg or {}
	obj.logger:d("Safely loading Spoon: " .. spoonName)

	-- Try to load the spoon and see if it works.
	local status, spoonOrError = pcall(function () return hs.loadSpoon(spoonName) end)

	if status then
		obj.logger:d("Successfully loaded Spoon: " .. spoonName)
		local spoon = spoonOrError
		-- apply configuration if any
		if arg.config then
			for k, v in pairs(arg.config) do
				spoon[k] = v
			end
		end
		if arg.hotkeys then
			spoon:bindHotkeys(arg.hotkeys)
		end
		if arg.start then
			spoon:start()
		end
		return spoon
	else
		-- If loading failed, check if it's because the spoon is not found.
		-- This is a bit of a heuristic.
		local errorString = tostring(spoonOrError)
		if string.find(errorString, "Spoon not found") then
			obj.logger:w("Spoon '" .. spoonName .. "' not found.")
			-- local choice = hs.dialog.buttonPanel("Spoon Not Found", "Spoon '" .. spoonName .. "' is not installed.", {"Install", "Cancel"}, "Install")
			-- if choice == "Install" then
			--   obj.logger:d("User chose to install '" .. spoonName .. "'.")
			--   obj.spoonInstaller:andUse(spoonName, arg)
			--   -- andUse is async, so we can't immediately return the spoon object.
			--   -- The user will need to reload config after installation.
			--   hs.alert.show("Spoon '" .. spoonName .. "' is being installed. Please reload your Hammerspoon configuration to use it.")
			--   return nil
			-- else
			--   obj.logger:d("User chose not to install '" .. spoonName .. "'.")
			--   return nil
			-- end
			return nil
		else
			-- The spoon exists, but there was an error loading it.
			local errorMsg = "Error loading " .. spoonName .. ": " .. errorString
			obj.logger:e(errorMsg)
			hs.alert.show("Error loading " .. spoonName .. " Spoon")
			return nil
		end
	end
end

-- For backward compatibility
function obj:SafeLoad(spoonName)
	return self:load(spoonName)
end

function obj:SafeCall(description, func)
	obj.logger:d("Attempting: " .. description)
	local success, result = pcall(func)
	if not success then
		obj.logger:e("ERROR in " .. description .. ": " .. tostring(result))
		hs.alert.show("Error: " .. description)
	else
		obj.logger:d("Success: " .. description)
	end
	return success, result
end

return obj

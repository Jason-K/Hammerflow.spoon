-- hsLauncher/main/modules/hotkeys/nsuser_equivalents.lua
-- Apply NSUserKeyEquivalents for Cocoa apps
-- Modifiers: @ = Cmd, ~ = Opt, ^ = Ctrl, $ = Shift
local M = {}
local log = require('hsLauncher.main.core.logger')

local sym = { cmd = '@', opt = '~', option = '~', ctrl = '^', control = '^', shift = '$' }

local function modsToString(mods)
	local out = {}
	for _, m in ipairs(mods or {}) do
		table.insert(out, sym[m] or '')
	end
	return table.concat(out, '')
end

local function escapeTitle(t)
	-- Quote for defaults; handle embedded quotes
	return string.gsub(t or '', '"', '\\"')
end

function M.apply(bundleID, menuTitle, mods, key)
	if not bundleID or not menuTitle or not key then
		return false, 'missing parameters'
	end
	local keyStr = modsToString(mods) .. string.lower(key)
	local cmd = string.format('defaults write %s NSUserKeyEquivalents -dict-add "%s" "%s"', bundleID,
		escapeTitle(menuTitle), keyStr)
	local ok, out, _, rc = hs.execute(cmd, true)
	if not ok or rc ~= 0 then
		log.error('NSUserKeyEquivalents write failed: ' .. tostring(out))
		return false, out
	end
	log.info(string.format('NSUserKeyEq applied: %s => %s (%s+%s)', bundleID, menuTitle, keyStr, key))
	return true
end

function M.remove(bundleID, menuTitle)
	if not bundleID or not menuTitle then return false, 'missing parameters' end
	local read = string.format('defaults read %s NSUserKeyEquivalents', bundleID)
	local ok, out = hs.execute(read, true)
	if not ok then return false, 'read failed' end
	-- No straightforward remove-one; rewrite dict without target would be needed. Skipping for now.
	return false, 'not implemented'
end

return M

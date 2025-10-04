local application = require('hs.application')

return function (context)
	local predicates = {}

	local function frontmostApp()
		return application.frontmostApplication()
	end

	function predicates.always()
		return true
	end

	function predicates.frontmostBundle(args)
		local app = frontmostApp()
		if not app then return false end
		local bundleId = args and (args.bundle or args[1])
		if not bundleId then return false end
		return app:bundleID() == bundleId
	end

	function predicates.frontmostNotBundle(args)
		local app = frontmostApp()
		if not app then return true end
		local bundleId = args and (args.bundle or args[1])
		if not bundleId then return true end
		return app:bundleID() ~= bundleId
	end

	function predicates.frontmostName(args)
		local app = frontmostApp()
		if not app then return false end
		local name = args and (args.name or args[1])
		if not name then return false end
		return app:name() == name
	end

	function predicates.frontmostNotName(args)
		local app = frontmostApp()
		if not app then return true end
		local name = args and (args.name or args[1])
		if not name then return true end
		return app:name() ~= name
	end

	return predicates
end

local ACTIONS_MODULE = 'hsLauncher.main.user.actions'
local EXTERNAL_ACTIONS_MODULE = 'hsLauncher.main.user.external_hotkeys'
local MENUS_MODULE = 'hsLauncher.main.user.menus'

local ConfigLoader = {}

local function push(list, code, message, context)
  list[#list + 1] = {
    code = code,
    message = message,
    context = context or {},
  }
end

local function deepCopy(value, seen)
  if type(value) ~= 'table' then
    return value
  end

  seen = seen or {}
  if seen[value] then
    return seen[value]
  end

  local copy = {}
  seen[value] = copy

  for k, v in pairs(value) do
    copy[deepCopy(k, seen)] = deepCopy(v, seen)
  end

  return copy
end

local function isArray(value)
  if type(value) ~= 'table' then
    return false
  end

  local count = 0
  for k in pairs(value) do
    if type(k) ~= 'number' or k <= 0 or math.floor(k) ~= k then
      return false
    end
    count = count + 1
  end

  return count == #value
end

local function normalizeModuleExport(export)
  local exportType = type(export)

  if exportType == 'table' then
    if export.default ~= nil and type(export.default) == 'table' then
      return export.default
    end
    return export
  end

  if exportType == 'function' then
    local ok, result = pcall(export)
    if not ok then
      return nil, result
    end
    if type(result) ~= 'table' then
      return nil, 'module factory must return a table'
    end
    return result
  end

  if export == nil then
    return {}
  end

  return nil, 'module must return a table or function returning a table'
end

local function requireFresh(moduleName)
  local previous = package.loaded[moduleName]
  package.loaded[moduleName] = nil

  local ok, result = pcall(require, moduleName)
  if not ok then
    package.loaded[moduleName] = previous
    return nil, result
  end

  return result, nil
end

local function validateString(value)
  return type(value) == 'string' and value ~= ''
end

local function validateStringArray(value)
  if not isArray(value) then
    return false
  end
  for _, entry in ipairs(value) do
    if not validateString(entry) then
      return false
    end
  end
  return true
end

local function validateHotkey(hotkey, errors, source)
  if type(hotkey) ~= 'table' then
    push(errors, 'action.hotkey.invalid', 'action hotkey must be a table', source)
    return
  end

  local trigger = hotkey.trigger
  if type(trigger) ~= 'table' then
    push(errors, 'action.hotkey.trigger.missing', 'action hotkey.trigger must be a table', source)
    return
  end

  local keys = trigger.keys
  if not isArray(keys) or #keys == 0 then
    push(errors, 'action.hotkey.keys.invalid', 'action hotkey.trigger.keys must be a non-empty array', source)
    return
  end

  for idx, key in ipairs(keys) do
    if type(key) ~= 'table' then
      push(errors, 'action.hotkey.key.invalid', string.format('action hotkey key entry %d must be a table', idx), source)
    else
      if not validateString(key.key) then
        push(errors, 'action.hotkey.key.missing', string.format('action hotkey key entry %d must include key string', idx), source)
      end
      if key.mods ~= nil then
        if not validateStringArray(key.mods) then
          push(errors, 'action.hotkey.mods.invalid', string.format('action hotkey key entry %d mods must be array of strings', idx), source)
        end
      end
    end
  end

  if #keys > 1 then
    if trigger.multikeyType ~= 'chord' and trigger.multikeyType ~= 'sequence' then
      push(errors, 'action.hotkey.multikeyType.missing', 'action hotkey requires multikeyType when multiple keys defined', source)
    end
  end

  if hotkey.context ~= nil then
    if not isArray(hotkey.context) then
      push(errors, 'action.hotkey.context.invalid', 'action hotkey context must be an array of tables', source)
    else
      for idx, ctx in ipairs(hotkey.context) do
        if type(ctx) ~= 'table' or not validateString(ctx.context) then
          push(errors, 'action.hotkey.context.entry.invalid', string.format('action hotkey context entry %d must include context id', idx), source)
        end
      end
    end
  end
end

local function validateMenuDetails(details, errors, warnings, source)
  if type(details) ~= 'table' then
    push(errors, 'action.menuDetails.invalid', 'action menuDetails must be a table', source)
    return
  end

  if details.inMenu ~= nil and not validateStringArray(details.inMenu) then
    push(errors, 'action.menuDetails.inMenu.invalid', 'action menuDetails.inMenu must be array of menu titles', source)
  end

  if details.perMenu ~= nil then
    if type(details.perMenu) ~= 'table' then
      push(errors, 'action.menuDetails.perMenu.invalid', 'action menuDetails.perMenu must be table keyed by menu title', source)
    else
      for menuName, override in pairs(details.perMenu) do
        if not validateString(menuName) then
          push(errors, 'action.menuDetails.perMenu.key.invalid', 'action menuDetails.perMenu keys must be non-empty strings', source)
        elseif type(override) ~= 'table' then
          push(errors, 'action.menuDetails.perMenu.value.invalid', string.format('action menuDetails.perMenu[%s] must be a table', menuName), source)
        else
          if override.defaultShortcut ~= nil and not validateString(override.defaultShortcut) then
            push(errors, 'action.menuDetails.perMenu.defaultShortcut.invalid', string.format('action menuDetails perMenu[%s] defaultShortcut must be non-empty string', menuName), source)
          end
          if override.fallbackShortcut ~= nil and not validateString(override.fallbackShortcut) then
            push(errors, 'action.menuDetails.perMenu.fallbackShortcut.invalid', string.format('action menuDetails perMenu[%s] fallbackShortcut must be non-empty string', menuName), source)
          end
          if override.description ~= nil and not validateString(override.description) then
            push(warnings, 'action.menuDetails.perMenu.description.invalid', string.format('action menuDetails perMenu[%s] description should be non-empty string', menuName), source)
          end
        end
      end
    end
  end
end

local function validateOnError(onError, errors, source)
  if type(onError) ~= 'table' then
    push(errors, 'action.onError.invalid', 'action onError must be a table', source)
    return
  end

  if onError.strategy ~= nil then
    local strategy = onError.strategy
    if strategy ~= 'silent' and strategy ~= 'notify' and strategy ~= 'raise' then
      push(errors, 'action.onError.strategy.invalid', 'action onError.strategy must be silent|notify|raise', source)
    end
  end

  if onError.retries ~= nil and type(onError.retries) ~= 'number' then
    push(errors, 'action.onError.retries.invalid', 'action onError.retries must be number', source)
  end

  if onError.backoffMs ~= nil and type(onError.backoffMs) ~= 'number' then
    push(errors, 'action.onError.backoffMs.invalid', 'action onError.backoffMs must be number', source)
  end
end

local function validateActions(raw, errors, warnings, moduleId, seenNames)
  local records = {}
  local index = {}
  local seen = seenNames or {}
  moduleId = moduleId or 'actions'

  if not isArray(raw) then
    push(errors, moduleId .. '.invalidType', 'actions module must return an array of action tables', { module = moduleId })
    return records, index, seen
  end

  for idx, spec in ipairs(raw) do
    if type(spec) ~= 'table' then
      push(errors, 'action.invalidType', 'each action entry must be a table', { module = moduleId, index = idx })
      goto continue
    end

    local action = deepCopy(spec)
    local name = action.name
    if not validateString(name) then
      push(errors, 'action.name.missing', 'action must include non-empty string "name"', { module = moduleId, index = idx })
      goto continue
    end

    local existing = seen[name]
    if existing then
      push(errors, 'action.name.duplicate', string.format('duplicate action name "%s"', name), {
        module = moduleId,
        index = idx,
        name = name,
        previousModule = existing.module,
        previousIndex = existing.index,
      })
    else
      seen[name] = { module = moduleId, index = idx }
    end

    if not isArray(action.actions) or #action.actions == 0 then
      push(errors, 'action.actions.invalid', string.format('action "%s" must define non-empty actions array', name), { module = moduleId, index = idx, name = name })
    end

    for stepIndex, step in ipairs(action.actions or {}) do
      local stepType = type(step)
      if stepType ~= 'string' and stepType ~= 'table' and stepType ~= 'function' then
        push(errors, 'action.actions.step.invalid', string.format('action "%s" step %d must be string, table, or function', name, stepIndex), { module = moduleId, index = idx, name = name, stepIndex = stepIndex })
      end
    end

    if action.hotkey ~= nil then
      validateHotkey(action.hotkey, errors, { module = moduleId, index = idx, name = name })
    end

    if action.menuDetails ~= nil then
      validateMenuDetails(action.menuDetails, errors, warnings, { module = moduleId, index = idx, name = name })
    end

    if action.tags ~= nil and not validateStringArray(action.tags) then
      push(errors, 'action.tags.invalid', string.format('action "%s" tags must be array of strings', name), { module = moduleId, index = idx, name = name })
    end

    if action.enabled ~= nil and type(action.enabled) ~= 'boolean' then
      push(errors, 'action.enabled.invalid', string.format('action "%s" enabled must be boolean', name), { module = moduleId, index = idx, name = name })
    end

    if action.guard ~= nil then
      local guardType = type(action.guard)
      if guardType ~= 'string' and guardType ~= 'function' then
        push(errors, 'action.guard.invalid', string.format('action "%s" guard must be function or string', name), { module = moduleId, index = idx, name = name })
      end
    end

    if action.onError ~= nil then
      validateOnError(action.onError, errors, { module = moduleId, index = idx, name = name })
    end

    if action.variables ~= nil and type(action.variables) ~= 'table' then
      push(errors, 'action.variables.invalid', string.format('action "%s" variables must be table', name), { module = moduleId, index = idx, name = name })
    end

    local record = {
      action = action,
      source = {
        module = moduleId,
        index = idx,
      },
    }
    records[#records + 1] = record
    index[name] = record

    ::continue::
  end

  return records, index, seen
end

local function validateMenus(raw, errors, warnings)
  local records = {}
  local index = {}

  if raw == nil then
    return records, index
  end

  if not isArray(raw) then
    push(errors, 'menus.invalidType', 'menus module must return an array of menu tables', { module = 'menus' })
    return records, index
  end

  local seenTitles = {}

  for idx, spec in ipairs(raw) do
    if type(spec) ~= 'table' then
      push(errors, 'menu.invalidType', 'each menu entry must be a table', { module = 'menus', index = idx })
      goto continue
    end

    local menu = deepCopy(spec)
    local title = menu.title
    if not validateString(title) then
      push(errors, 'menu.title.missing', 'menu must include non-empty string "title"', { module = 'menus', index = idx })
      goto continue
    end

    if seenTitles[title] then
      push(errors, 'menu.title.duplicate', string.format('duplicate menu title "%s"', title), { module = 'menus', index = idx, title = title })
    else
      seenTitles[title] = true
    end

    if menu.description ~= nil and not validateString(menu.description) then
      push(errors, 'menu.description.invalid', string.format('menu "%s" description must be non-empty string', title), { module = 'menus', index = idx, title = title })
    end

    if menu.defaultShortcut ~= nil and not validateString(menu.defaultShortcut) then
      push(errors, 'menu.defaultShortcut.invalid', string.format('menu "%s" defaultShortcut must be non-empty string', title), { module = 'menus', index = idx, title = title })
    end

    if menu.fallbackShortcut ~= nil and not validateString(menu.fallbackShortcut) then
      push(errors, 'menu.fallbackShortcut.invalid', string.format('menu "%s" fallbackShortcut must be non-empty string', title), { module = 'menus', index = idx, title = title })
    end

    if menu.subMenus ~= nil and not validateStringArray(menu.subMenus) then
      push(errors, 'menu.subMenus.invalid', string.format('menu "%s" subMenus must be array of menu titles', title), { module = 'menus', index = idx, title = title })
    end

    if menu.excludeMenu ~= nil and not validateStringArray(menu.excludeMenu) then
      push(errors, 'menu.excludeMenu.invalid', string.format('menu "%s" excludeMenu must be array of menu titles', title), { module = 'menus', index = idx, title = title })
    end

    if menu.memberRoot ~= nil and type(menu.memberRoot) ~= 'boolean' then
      push(errors, 'menu.memberRoot.invalid', string.format('menu "%s" memberRoot must be boolean', title), { module = 'menus', index = idx, title = title })
    end

    if menu.policy ~= nil then
      if type(menu.policy) ~= 'table' then
        push(errors, 'menu.policy.invalid', string.format('menu "%s" policy must be table', title), { module = 'menus', index = idx, title = title })
      else
        if menu.policy.autoPopulateFromActions ~= nil and type(menu.policy.autoPopulateFromActions) ~= 'boolean' then
          push(errors, 'menu.policy.autoPopulateFromActions.invalid', string.format('menu "%s" policy.autoPopulateFromActions must be boolean', title), { module = 'menus', index = idx, title = title })
        end
        if menu.policy.includeSubMenus ~= nil and type(menu.policy.includeSubMenus) ~= 'boolean' then
          push(errors, 'menu.policy.includeSubMenus.invalid', string.format('menu "%s" policy.includeSubMenus must be boolean', title), { module = 'menus', index = idx, title = title })
        end
        if menu.policy.includeTags ~= nil and not validateStringArray(menu.policy.includeTags) then
          push(errors, 'menu.policy.includeTags.invalid', string.format('menu "%s" policy.includeTags must be array of strings', title), { module = 'menus', index = idx, title = title })
        end
        if menu.policy.excludeTags ~= nil and not validateStringArray(menu.policy.excludeTags) then
          push(errors, 'menu.policy.excludeTags.invalid', string.format('menu "%s" policy.excludeTags must be array of strings', title), { module = 'menus', index = idx, title = title })
        end
      end
    end

    if menu.sort ~= nil and type(menu.sort) ~= 'table' then
      push(errors, 'menu.sort.invalid', string.format('menu "%s" sort must be table', title), { module = 'menus', index = idx, title = title })
    end

    local record = {
      menu = menu,
      source = {
        module = 'menus',
        index = idx,
      },
    }
    records[#records + 1] = record
    index[title] = record

    ::continue::
  end

  return records, index
end

local function crossValidateActions(actionRecords, menuIndex, errors)
  for _, record in ipairs(actionRecords) do
    local action = record.action
    local source = record.source
    local details = action.menuDetails

    if type(details) == 'table' then
      if isArray(details.inMenu) then
        for idx, menuName in ipairs(details.inMenu) do
          if menuIndex[menuName] == nil then
            push(errors, 'action.menuDetails.inMenu.unknown', string.format('action "%s" references unknown menu "%s"', action.name, menuName), {
              module = source.module,
              index = source.index,
              name = action.name,
              menu = menuName,
              menuIndex = idx,
            })
          end
        end
      end

      if type(details.perMenu) == 'table' then
        for menuName in pairs(details.perMenu) do
          if validateString(menuName) and menuIndex[menuName] == nil then
            push(errors, 'action.menuDetails.perMenu.unknown', string.format('action "%s" perMenu override references unknown menu "%s"', action.name, menuName), {
              module = source.module,
              index = source.index,
              name = action.name,
              menu = menuName,
            })
          end
        end
      end
    end
  end
end

local function crossValidateMenus(menuRecords, menuIndex, errors)
  for _, record in ipairs(menuRecords) do
    local menu = record.menu
    local source = record.source

    if isArray(menu.subMenus) then
      for idx, child in ipairs(menu.subMenus) do
        if menuIndex[child] == nil then
          push(errors, 'menu.subMenus.unknown', string.format('menu "%s" subMenus entry references unknown menu "%s"', menu.title, child), {
            module = source.module,
            index = source.index,
            title = menu.title,
            subMenuIndex = idx,
            subMenu = child,
          })
        end
      end
    end

    if isArray(menu.excludeMenu) then
      for idx, child in ipairs(menu.excludeMenu) do
        if menuIndex[child] == nil then
          push(errors, 'menu.excludeMenu.unknown', string.format('menu "%s" excludeMenu entry references unknown menu "%s"', menu.title, child), {
            module = source.module,
            index = source.index,
            title = menu.title,
            excludeIndex = idx,
            subMenu = child,
          })
        end
      end
    end
  end
end

local function recordsToList(records, field)
  local list = {}
  for idx, record in ipairs(records) do
    list[idx] = record[field]
  end
  return list
end

function ConfigLoader.load(opts)
  opts = opts or {}

  local diagnostics = {
    errors = {},
    warnings = {},
  }

  local actionsModule = opts.actionsModule or ACTIONS_MODULE
  local externalModule = opts.externalActionsModule or EXTERNAL_ACTIONS_MODULE
  local menusModule = opts.menusModule or MENUS_MODULE

  local actionsExport, actionsErr = requireFresh(actionsModule)
  if not actionsExport then
    push(diagnostics.errors, 'actions.load.failed', 'failed to load actions module', { module = actionsModule, error = tostring(actionsErr) })
    actionsExport = {}
  else
    local normalized, normalizeErr = normalizeModuleExport(actionsExport)
    if not normalized then
      push(diagnostics.errors, 'actions.load.invalidExport', normalizeErr or 'actions module must return a table', { module = actionsModule })
      actionsExport = {}
    else
      actionsExport = normalized
    end
  end

  local externalExport, externalErr = requireFresh(externalModule)
  if not externalExport then
    push(diagnostics.warnings, 'externalActions.load.failed', 'external actions module not loaded; continuing without external actions', { module = externalModule, error = tostring(externalErr) })
    externalExport = {}
  else
    local normalized, normalizeErr = normalizeModuleExport(externalExport)
    if not normalized then
      push(diagnostics.errors, 'externalActions.load.invalidExport', normalizeErr or 'external actions module must return a table', { module = externalModule })
      externalExport = {}
    else
      externalExport = normalized
    end
  end

  local menusExport, menusErr = requireFresh(menusModule)
  if not menusExport then
    push(diagnostics.errors, 'menus.load.failed', 'failed to load menus module', { module = menusModule, error = tostring(menusErr) })
    menusExport = {}
  else
    local normalized, normalizeErr = normalizeModuleExport(menusExport)
    if not normalized then
      push(diagnostics.errors, 'menus.load.invalidExport', normalizeErr or 'menus module must return a table', { module = menusModule })
      menusExport = {}
    else
      menusExport = normalized
    end
  end

  local actionRecords, primaryIndex, seen = validateActions(actionsExport, diagnostics.errors, diagnostics.warnings, 'actions', nil)
  local externalRecords, externalIndex = validateActions(externalExport, diagnostics.errors, diagnostics.warnings, 'externalHotkeys', seen)
  local menuRecords, menuIndex = validateMenus(menusExport, diagnostics.errors, diagnostics.warnings)

  local mergedRecords = {}
  local actionIndex = {}

  local function append(records)
    for _, record in ipairs(records) do
      mergedRecords[#mergedRecords + 1] = record
      actionIndex[record.action.name] = record
    end
  end

  append(actionRecords)
  append(externalRecords)

  crossValidateActions(mergedRecords, menuIndex, diagnostics.errors)
  crossValidateMenus(menuRecords, menuIndex, diagnostics.errors)

  local ok = #diagnostics.errors == 0

  return {
    ok = ok,
    actions = recordsToList(mergedRecords, 'action'),
    actionIndex = actionIndex,
    menus = recordsToList(menuRecords, 'menu'),
    menuIndex = menuIndex,
    diagnostics = diagnostics,
    modules = {
      actions = actionsModule,
      externalActions = externalModule,
      menus = menusModule,
    },
  }
end

return ConfigLoader
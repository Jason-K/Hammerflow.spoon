local json = require('hs.json')

local fs = require('hsLauncher.main.core.fs')
local logger = require('hsLauncher.main.core.logger')
local BasePaths = require('hsLauncher.main.core.base_paths')

local defaultPath = BasePaths.runtimeFile('logs', 'hotkey_manifest.json')
local NO_TRIGGER = '__none__'

local state = {
    entries = {},
    indexByScope = {},
    indexByTrigger = {},
    indexBySource = {},
    indexByTriggerType = {},
    nextId = 1,
    path = defaultPath,
}

local function shallowCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local out = {}
    for k, v in pairs(tbl) do out[k] = v end
    return out
end

local function deepCopy(value)
    if type(value) ~= 'table' then return value end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end

local function copyArray(list)
    if type(list) ~= 'table' then return nil end
    local out = {}
    for index, value in ipairs(list) do
        out[index] = value
    end
    return out
end

local function normalizeScope(scope)
    if type(scope) ~= 'string' or scope == '' then return 'unknown' end
    return scope
end

local function normalizeSource(source)
    if source == nil or source == '' then return 'unknown' end
    return tostring(source)
end

local function normalizeTriggerType(triggerType)
    if triggerType == nil or triggerType == '' then return 'unknown' end
    return tostring(triggerType)
end

local function normalizeTrigger(trigger)
    if trigger == nil then return nil end
    if type(trigger) == 'table' then
        local ok, encoded = pcall(json.encode, trigger)
        if ok then return encoded end
    end
    return tostring(trigger)
end

local function ensureArrayIndex(container, key)
    container[key] = container[key] or {}
    return container[key]
end

local function nextId()
    local id = state.nextId
    state.nextId = state.nextId + 1
    return id
end

local function coalesce(source)
    if type(source) == 'table' then
        if source.module and source.key then
            return string.format('%s:%s', tostring(source.module), tostring(source.key))
        end
        local ok, encoded = pcall(json.encode, source)
        if ok then return encoded end
    end
    return source
end

local function canonicalize(entry)
    local scope = normalizeScope(entry.scope)
    local trigger = normalizeTrigger(entry.trigger)
    local canonical = {
        id = entry.id or nextId(),
        scope = scope,
        trigger = trigger,
        triggerType = normalizeTriggerType(entry.triggerType or entry.type),
        description = entry.description,
        action = entry.action,
        source = normalizeSource(coalesce(entry.source)),
        metadata = entry.metadata and deepCopy(entry.metadata) or nil,
        tags = entry.tags and deepCopy(entry.tags) or nil,
        registeredAt = entry.registeredAt or os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    return canonical
end

local M = {}

function M.configure(opts)
    opts = opts or {}
    if opts.path and opts.path ~= '' then
        state.path = fs.expandUser(opts.path)
    end
end

function M.path()
    return state.path
end

function M.clear()
    state.entries = {}
    state.indexByScope = {}
    state.indexByTrigger = {}
    state.indexBySource = {}
    state.indexByTriggerType = {}
    state.nextId = 1
end

function M.record(entry)
    if type(entry) ~= 'table' then
        logger.warn('hotkey_manifest record called without table entry')
        return nil
    end
    local canonical = canonicalize(entry)
    local scopeBucket = ensureArrayIndex(state.indexByScope, canonical.scope)
    local triggerBucket = ensureArrayIndex(state.indexByTrigger, canonical.trigger or NO_TRIGGER)
    local sourceBucket = ensureArrayIndex(state.indexBySource, canonical.source)
    local typeBucket = ensureArrayIndex(state.indexByTriggerType, canonical.triggerType)

    table.insert(state.entries, canonical)
    table.insert(scopeBucket, canonical)
    table.insert(triggerBucket, canonical)
    table.insert(sourceBucket, canonical)
    table.insert(typeBucket, canonical)
    return canonical.id
end

function M.recordBinding(opts)
    opts = opts or {}
    opts.scope = opts.scope or 'hyper.binding'
    opts.triggerType = opts.triggerType or 'binding'
    return M.record(opts)
end

function M.recordSequence(opts)
    opts = opts or {}
    opts.scope = opts.scope or 'hyper.sequence'
    opts.triggerType = opts.triggerType or 'sequence'
    return M.record(opts)
end

function M.recordMode(opts)
    opts = opts or {}
    opts.scope = opts.scope or 'hyper.mode'
    opts.triggerType = opts.triggerType or 'mode'
    return M.record(opts)
end

function M.recordGlobal(opts)
    opts = opts or {}
    opts.scope = opts.scope or 'global.shortcut'
    opts.triggerType = opts.triggerType or 'global'
    return M.record(opts)
end

local function copyEntries(list)
    local out = {}
    for idx, entry in ipairs(list or {}) do
        out[idx] = deepCopy(entry)
    end
    return out
end

local function uniqueKeys(map)
    local keys = {}
    for key in pairs(map or {}) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function buildSet(value)
    if value == nil then return nil end
    if type(value) ~= 'table' then return { [value] = true } end
    local set = {}
    local inserted = false
    for key, v in pairs(value) do
        local candidate
        if type(key) == 'number' then
            candidate = v
        elseif v then
            candidate = key
        end
        if candidate ~= nil then
            set[candidate] = true
            inserted = true
        end
    end
    if not inserted then return nil end
    return set
end

local function hasText(value, needleLower)
    if not needleLower then return true end
    if value == nil then return false end
    return tostring(value):lower():find(needleLower, 1, true) ~= nil
end

local function entryHasTag(entryTags, tag)
    if type(entryTags) ~= 'table' then return false end
    for key, value in pairs(entryTags) do
        local candidate
        if type(key) == 'number' then
            candidate = value
        elseif value then
            candidate = key
        end
        if candidate == tag then return true end
    end
    return false
end

local function entryHasAnyTag(entryTags, tagSet)
    if not tagSet then return false end
    for tag in pairs(tagSet) do
        if entryHasTag(entryTags, tag) then return true end
    end
    return false
end

local function entryMatchesTags(entryTags, tagSet, requireAll)
    if not tagSet then return true end
    if type(entryTags) ~= 'table' then return false end
    if requireAll then
        for tag in pairs(tagSet) do
            if not entryHasTag(entryTags, tag) then
                return false
            end
        end
        return true
    end
    return entryHasAnyTag(entryTags, tagSet)
end

function M.snapshot()
    return {
        entries = copyEntries(state.entries),
    }
end

function M.list()
    return copyEntries(state.entries)
end

function M.listByScope(scope)
    scope = normalizeScope(scope)
    return copyEntries(state.indexByScope[scope] or {})
end

function M.findByTrigger(trigger)
    local key = normalizeTrigger(trigger) or NO_TRIGGER
    return copyEntries(state.indexByTrigger[key] or {})
end

function M.listBySource(source)
    local key = normalizeSource(coalesce(source))
    return copyEntries(state.indexBySource[key] or {})
end

function M.listByTriggerType(triggerType)
    local key = normalizeTriggerType(triggerType)
    return copyEntries(state.indexByTriggerType[key] or {})
end

function M.listScopes()
    return uniqueKeys(state.indexByScope)
end

function M.listSources()
    return uniqueKeys(state.indexBySource)
end

function M.listTriggerTypes()
    return uniqueKeys(state.indexByTriggerType)
end

function M.count(entries)
    entries = entries or state.entries
    return #entries
end

function M.groupByScope(entries)
    entries = entries or state.entries
    local groups = {}
    for _, entry in ipairs(entries or {}) do
        local scope = entry.scope or 'unknown'
        local bucket = groups[scope]
        if not bucket then
            bucket = {}
            groups[scope] = bucket
        end
        bucket[#bucket + 1] = deepCopy(entry)
    end
    return groups
end

function M.groupBy(entries, keyFn)
    assert(type(keyFn) == 'function', 'groupBy expects key function')
    local groups = {}
    for _, entry in ipairs(entries or state.entries) do
        local key = keyFn(entry)
        if key ~= nil then
            local bucket = groups[key]
            if not bucket then
                bucket = {}
                groups[key] = bucket
            end
            bucket[#bucket + 1] = deepCopy(entry)
        end
    end
    return groups
end

function M.summaryByScope(entries)
    entries = entries or state.entries
    local summary = {}
    for _, entry in ipairs(entries or {}) do
        local scope = entry.scope or 'unknown'
        local bucket = summary[scope]
        if not bucket then
            bucket = { count = 0 }
            summary[scope] = bucket
        end
        bucket.count = bucket.count + 1
    end
    return summary
end

local function matchesMetadata(entry, filters)
    if not filters then return true end
    local metadata = entry.metadata
    if filters.metadataKey and (metadata == nil or metadata[filters.metadataKey] == nil) then
        return false
    end
    if filters.metadataValue then
        if metadata == nil then return false end
        local expected = filters.metadataValue
        local matched = false
        for key, value in pairs(metadata) do
            if key == expected or value == expected then
                matched = true
                break
            end
        end
        if not matched then return false end
    end
    if filters.metadataContains then
        if metadata == nil then return false end
        local needle = tostring(filters.metadataContains):lower()
        local matched = false
        for key, value in pairs(metadata) do
            if hasText(key, needle) or hasText(value, needle) then
                matched = true
                break
            end
        end
        if not matched then return false end
    end
    if filters.metadataWhere then
        if type(filters.metadataWhere) == 'function' then
            local ok, result = pcall(filters.metadataWhere, metadata, entry)
            if not ok or result == false then
                return false
            end
        end
    end
    return true
end

function M.search(filters)
    filters = filters or {}

    local scopeSet = buildSet(filters.scope or filters.scopes)
    local excludeScopeSet = buildSet(filters.excludeScope or filters.excludeScopes)
    local triggerTypeSet = buildSet(filters.triggerType or filters.triggerTypes or filters.type or filters.types)
    local triggerSet = buildSet(filters.trigger or filters.triggers)
    local sourceSet = buildSet(filters.source or filters.sources)
    local tagSet = buildSet(filters.tag or filters.tags)
    local excludeTagSet = buildSet(filters.excludeTag or filters.excludeTags)

    local requireAllTags = filters.requireAllTags == true
    local includeUntagged = filters.includeUntagged == true
    local onlyUntagged = filters.onlyUntagged == true
    local requireTags = filters.requireTags == true
    local predicate = filters.predicate or filters.matchFn or filters.filter

    local text = filters.text or filters.query or filters.match
    local textLower = text and text:lower() or nil
    local sourceContains = filters.sourceContains and filters.sourceContains:lower() or nil
    local triggerContains = filters.triggerContains and filters.triggerContains:lower() or nil

    local results = {}
    for _, entry in ipairs(state.entries) do
        local scope = entry.scope or 'unknown'
        if scopeSet and not scopeSet[scope] then goto continue end
        if excludeScopeSet and excludeScopeSet[scope] then goto continue end

        local triggerValue = entry.trigger or ''
        if triggerSet and not triggerSet[triggerValue] then goto continue end

        if triggerContains and not hasText(triggerValue, triggerContains) then goto continue end

        local triggerType = entry.triggerType or 'unknown'
        if triggerTypeSet and not triggerTypeSet[triggerType] then goto continue end

        local source = entry.source or 'unknown'
        if sourceSet and not sourceSet[source] then goto continue end

        if sourceContains and not hasText(source, sourceContains) then goto continue end

        if textLower then
            local matched = hasText(entry.description, textLower)
                or hasText(entry.action, textLower)
                or hasText(triggerValue, textLower)
                or hasText(source, textLower)
            if not matched and entry.metadata then
                for key, value in pairs(entry.metadata) do
                    if hasText(key, textLower) or hasText(value, textLower) then
                        matched = true
                        break
                    end
                end
            end
            if not matched and entry.tags then
                for key, value in pairs(entry.tags) do
                    local candidate
                    if type(key) == 'number' then
                        candidate = value
                    elseif value then
                        candidate = key
                    end
                    if hasText(candidate, textLower) then
                        matched = true
                        break
                    end
                end
            end
            if not matched then goto continue end
        end

        local tags = entry.tags
        local hasTags = type(tags) == 'table' and next(tags) ~= nil

        if tagSet then
            if hasTags then
                if not entryMatchesTags(tags, tagSet, requireAllTags) then goto continue end
            elseif not includeUntagged then
                goto continue
            end
        end

        if excludeTagSet and hasTags and entryHasAnyTag(tags, excludeTagSet) then goto continue end
        if onlyUntagged and hasTags then goto continue end
        if requireTags and not hasTags then goto continue end

        if not matchesMetadata(entry, filters) then goto continue end

        if predicate then
            local ok, keep = pcall(predicate, entry)
            if not ok or keep == false then goto continue end
        end

        results[#results + 1] = deepCopy(entry)
        ::continue::
    end

    if filters.sort then
        table.sort(results, filters.sort)
    elseif filters.sortBy then
        local key = filters.sortBy
        table.sort(results, function(a, b)
            local av = a[key]
            local bv = b[key]
            if av == bv then
                return tostring(a.trigger or '') < tostring(b.trigger or '')
            end
            return tostring(av or '') < tostring(bv or '')
        end)
    elseif filters.sortScopeFirst then
        table.sort(results, function(a, b)
            if (a.scope or '') == (b.scope or '') then
                return tostring(a.trigger or '') < tostring(b.trigger or '')
            end
            return tostring(a.scope or '') < tostring(b.scope or '')
        end)
    end

    return results
end

function M.iter(fn)
    for _, entry in ipairs(state.entries) do
        fn(entry)
    end
end

local function describeTriggerValue(trigger)
    if trigger == nil or trigger == NO_TRIGGER then return '∅ (no trigger)' end
    return trigger
end

local function entrySummary(entry)
    return {
        id = entry.id,
        scope = entry.scope,
        trigger = entry.trigger,
        triggerType = entry.triggerType,
        description = entry.description,
        action = entry.action,
        source = entry.source,
    }
end

local function summarizeEntries(list)
    local summaries = {}
    for index, value in ipairs(list or {}) do
        summaries[index] = entrySummary(value)
    end
    return summaries
end

local DEFAULT_CATALOG_FIELDS = { 'trigger', 'triggerType', 'description', 'source', 'tags' }

local function tagList(tags)
    if type(tags) ~= 'table' then return nil end
    local list = {}
    for key, value in pairs(tags) do
        local tag
        if type(key) == 'number' then
            tag = value
        elseif value then
            tag = key
        end
        if tag ~= nil then
            list[#list + 1] = tostring(tag)
        end
    end
    if #list == 0 then return nil end
    table.sort(list)
    return list
end

local function fieldLabel(field)
    if field == 'trigger' then return 'Trigger' end
    if field == 'triggerType' then return 'Type' end
    if field == 'description' then return 'Description' end
    if field == 'source' then return 'Source' end
    if field == 'tags' then return 'Tags' end
    if field == 'action' then return 'Action' end
    if field == 'registeredAt' then return 'Registered' end
    if field:sub(1, 9) == 'metadata.' then
        local key = field:sub(10)
        if key == '' then return 'Metadata' end
        return 'Meta ' .. key
    end
    local label = field:gsub('([A-Z])', ' %1')
    label = label:gsub('_', ' ')
    label = label:gsub('^%l', string.upper)
    return label
end

local function resolveField(entry, field)
    if not entry then return nil end
    if field == 'tags' then
        return entry.tags
    elseif field:sub(1, 9) == 'metadata.' then
        local key = field:sub(10)
        local meta = entry.metadata
        if meta then return meta[key] end
        return nil
    else
        return entry[field]
    end
end

local function escapeMarkdown(value)
    return tostring(value or ''):gsub('|', '\\|'):gsub('\n', '<br>')
end

local function formatCatalogValue(field, value)
    if value == nil then return '' end
    if field == 'tags' then
        local list = tagList(value)
        if not list then return '' end
        return table.concat(list, ', ')
    end
    local valueType = type(value)
    if valueType == 'table' then
        local ok, encoded = pcall(json.encode, value)
        if ok then return encoded end
        return tostring(value)
    end
    if valueType == 'boolean' then
        return value and 'true' or 'false'
    end
    return tostring(value)
end

local function normalizeCatalogFields(fields)
    if not fields or #fields == 0 then
        return copyArray(DEFAULT_CATALOG_FIELDS)
    end
    local normalized, seen = {}, {}
    for _, field in ipairs(fields) do
        local name = tostring(field or '')
        if name ~= '' then
            if name == 'metadata' then
                name = 'metadata.notes'
            elseif name:match('^metadata[.:]') then
                name = 'metadata.' .. name:gsub('^metadata[.:]', '')
            end
            if not seen[name] then
                seen[name] = true
                normalized[#normalized + 1] = name
            end
        end
    end
    if #normalized == 0 then
        return copyArray(DEFAULT_CATALOG_FIELDS)
    end
    return normalized
end

local function renderScopeTable(lines, scope, entries, fields)
    if #entries == 0 then return end
    lines[#lines + 1] = '## ' .. scope
    lines[#lines + 1] = ''
    local headers = {}
    for _, field in ipairs(fields) do
        headers[#headers + 1] = fieldLabel(field)
    end
    lines[#lines + 1] = '| ' .. table.concat(headers, ' | ') .. ' |'
    local divider = {}
    for _ = 1, #fields do divider[#divider + 1] = '---' end
    lines[#lines + 1] = '| ' .. table.concat(divider, ' | ') .. ' |'
    for _, entry in ipairs(entries) do
        local row = {}
        for _, field in ipairs(fields) do
            local value = formatCatalogValue(field, resolveField(entry, field))
            row[#row + 1] = escapeMarkdown(value)
        end
        lines[#lines + 1] = '| ' .. table.concat(row, ' | ') .. ' |'
    end
    lines[#lines + 1] = ''
end

local function prepareCatalogEntries(entries)
    entries = entries or {}
    local copied = {}
    for index, entry in ipairs(entries) do
        copied[index] = deepCopy(entry)
    end
    table.sort(copied, function(a, b)
        local scopeA = a.scope or ''
        local scopeB = b.scope or ''
        if scopeA == scopeB then
            return tostring(a.trigger or '') < tostring(b.trigger or '')
        end
        return scopeA < scopeB
    end)
    return copied
end

local function collectDuplicateIssues(entries)
    local seen = {}
    for _, entry in ipairs(entries or {}) do
        local scope = entry.scope or 'unknown'
        local trigger = entry.trigger or NO_TRIGGER
        local key = scope .. '|' .. trigger
        local bucket = seen[key]
        if bucket then
            bucket.entries[#bucket.entries + 1] = entry
        else
            seen[key] = {
                scope = scope,
                trigger = trigger,
                entries = { entry },
            }
        end
    end

    local issues = {}
    for _, bucket in pairs(seen) do
        if #bucket.entries > 1 then
            local triggerLabel = describeTriggerValue(bucket.trigger)
            issues[#issues + 1] = {
                type = 'duplicateTrigger',
                severity = 'error',
                scope = bucket.scope,
                trigger = bucket.trigger ~= NO_TRIGGER and bucket.trigger or nil,
                count = #bucket.entries,
                entries = summarizeEntries(bucket.entries),
                message = string.format('Duplicate trigger %s within scope %s (%d entries)', triggerLabel, bucket.scope,
                    #bucket.entries),
            }
        end
    end
    return issues
end

local function collectMetadataIssues(entries, opts)
    opts = opts or {}
    local requireDescription = opts.requireDescription ~= false
    local requireAction = opts.requireAction == true -- warnings by default
    local warnOnMissingAction = opts.requireAction ~= false
    local requireSource = opts.requireSource == true

    local errors, warnings = {}, {}
    local function push(target, issue)
        target[#target + 1] = issue
    end

    for _, entry in ipairs(entries or {}) do
        local descEmpty = entry.description == nil or entry.description == ''
        if requireDescription and descEmpty then
            push(warnings, {
                type = 'missingDescription',
                severity = 'warning',
                scope = entry.scope,
                trigger = entry.trigger,
                message = string.format('Entry %s in scope %s is missing a description.',
                    describeTriggerValue(entry.trigger), entry.scope or 'unknown'),
                entry = entrySummary(entry),
            })
        end

        local actionEmpty = entry.action == nil or entry.action == ''
        if requireAction and actionEmpty then
            push(errors, {
                type = 'missingAction',
                severity = 'error',
                scope = entry.scope,
                trigger = entry.trigger,
                message = string.format('Entry %s in scope %s is missing an action.', describeTriggerValue(entry.trigger),
                    entry.scope or 'unknown'),
                entry = entrySummary(entry),
            })
        elseif warnOnMissingAction and actionEmpty then
            push(warnings, {
                type = 'missingAction',
                severity = 'warning',
                scope = entry.scope,
                trigger = entry.trigger,
                message = string.format('Entry %s in scope %s has no action metadata.',
                    describeTriggerValue(entry.trigger), entry.scope or 'unknown'),
                entry = entrySummary(entry),
            })
        end

        if requireSource and (entry.source == nil or entry.source == '') then
            push(errors, {
                type = 'missingSource',
                severity = 'error',
                scope = entry.scope,
                trigger = entry.trigger,
                message = string.format('Entry %s in scope %s is missing source provenance.',
                    describeTriggerValue(entry.trigger), entry.scope or 'unknown'),
                entry = entrySummary(entry),
            })
        end
    end

    return errors, warnings
end

local function runValidation(entries, opts)
    local errors, warnings = {}, {}

    local function absorb(list, target)
        for _, issue in ipairs(list or {}) do
            target[#target + 1] = issue
        end
    end

    absorb(collectDuplicateIssues(entries), errors)
    local metadataErrors, metadataWarnings = collectMetadataIssues(entries, opts)
    absorb(metadataErrors, errors)
    absorb(metadataWarnings, warnings)

    return {
        ok = #errors == 0,
        errors = errors,
        warnings = warnings,
    }
end

function M.validate(opts)
    return runValidation(state.entries, opts)
end

function M.validateSnapshot(snapshot, opts)
    local entries = (snapshot and snapshot.entries) or {}
    return runValidation(entries, opts)
end

function M.renderCatalogMarkdown(opts)
    opts = opts or {}
    local fields = normalizeCatalogFields(opts.fields)
    local entries = opts.entries
    if entries then
        entries = prepareCatalogEntries(entries)
    else
        entries = prepareCatalogEntries(state.entries)
    end

    local groups = {}
    for _, entry in ipairs(entries) do
        local scope = entry.scope or 'unknown'
        local bucket = groups[scope]
        if not bucket then
            bucket = {}
            groups[scope] = bucket
        end
        bucket[#bucket + 1] = entry
    end

    local scopes = {}
    for scope in pairs(groups) do scopes[#scopes + 1] = scope end
    table.sort(scopes)

    local total = #entries
    local lines = {}
    local title = opts.title or 'Hotkey Manifest'
    lines[#lines + 1] = '# ' .. title
    lines[#lines + 1] = ''
    local timestamp = os.date('!%Y-%m-%d %H:%M:%SZ')
    lines[#lines + 1] = string.format('_Generated on %s_', timestamp)
    lines[#lines + 1] = ''

    local includeSummary = opts.includeSummary
    if includeSummary == nil then includeSummary = true end
    if includeSummary then
        lines[#lines + 1] = '## Scope Summary'
        lines[#lines + 1] = ''
        lines[#lines + 1] = '| Scope | Entries |'
        lines[#lines + 1] = '| --- | --- |'
        for _, scope in ipairs(scopes) do
            local count = #(groups[scope] or {})
            lines[#lines + 1] = string.format('| %s | %d |', scope, count)
        end
        lines[#lines + 1] = string.format('| Total | %d |', total)
        lines[#lines + 1] = ''
    end

    for _, scope in ipairs(scopes) do
        renderScopeTable(lines, scope, groups[scope], fields)
    end

    if total == 0 then
        lines[#lines + 1] = '_No entries matched the selected filters._'
        lines[#lines + 1] = ''
    end

    return table.concat(lines, '\n')
end

function M.export(path)
    path = path or state.path
    if not path or path == '' then
        return nil, 'no-path'
    end
    local payload = {
        entries = state.entries,
        exportedAt = os.date('!%Y-%m-%dT%H:%M:%SZ'),
    }
    local ok, encoded = pcall(json.encode, payload, true)
    if not ok then return nil, encoded end
    local okWrite, err = fs.writeFile(path, encoded)
    if not okWrite then return nil, err end
    return true
end

function M.import(path, opts)
    path = path or state.path
    if not path or path == '' then return nil, 'no-path' end
    local data, err = fs.readFile(path)
    if not data then return nil, err end
    local ok, decoded = pcall(json.decode, data)
    if not ok then return nil, decoded end
    if type(decoded) ~= 'table' or type(decoded.entries) ~= 'table' then
        return nil, 'invalid-manifest'
    end
    if not opts or opts.replace ~= false then
        M.clear()
    end
    for _, entry in ipairs(decoded.entries) do
        M.record(entry)
    end
    return true
end

return M

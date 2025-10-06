# hsLauncher — Launcher Redesign Handoff (2025-10-02)

This handoff documents the clean baseline for the Launcher Redesign effort. The branch `major/user-interaction-revamp` now assumes a **two-file, single-source** configuration surface for all user-visible behavior. Everything in this document reflects that decision and supersedes the legacy registry-focused workflow.

---

## 1. Snapshot Overview

- **Purpose:** Deliver a declarative launcher that maps actions to hotkeys and menus with minimal duplication.
- **Runtime entry point:** `main/init.lua` still boots the core; `hsLauncher.start()` wires hotkeys, menus, logging, and validation.
- **User customization surface (transition state):**
   - `main/user/userActions.lua` remains the authoritative bridge for leader modules, hotkey contexts, and per-module actions.
   - `main/user/actions.lua` & `main/user/menus.lua` are now validated by the Phase 1 loader and ship with empty stubs until the menu generator populates them.
- **Inclusion policy (target state):** Actions will drive menu population while menus supply structure and policy filters. Until Phase 2, modules continue to expose handcrafted layouts through `userActions.lua`.
- **Observability:** Structured logging (`core/logger.lua`) remains active. Loader diagnostics surface schema issues; a dedicated `Validate Config` command will arrive alongside the diagnostics suite.

Recent highlights:

- Phase 1 delivered `main/core/config_loader.lua` plus `tests/test_config_loader.lua`, covering happy paths, duplicate detection, and cross-reference validation.
- Phase 2 scaffolding added `main/core/menu_builder.lua` and `tests/test_menu_builder.lua`, assembling menu trees, applying tag filters, and surfacing shortcut collisions.
- `main/user/registry.lua` was refactored to consume menu exports, enrich leader root layouts, and preserve per-module extras; `tests/test_leader_registry.lua` now asserts the new behavior.
- Module updates (`module_shortcuts.lua`, `module_text_tools.lua`, `module_utilities.lua`) emit canonical action specs and metadata aligned with the loader schema.
- Declarative config now seeds `main/user/actions.lua` and `main/user/menus.lua` with the Brave launcher plus the three leader mode entries and quick-search prototype so tests run against loader-driven state.
- Hotkey contexts moved into `main/user/hotkeys/`, delegating to `UserActions.hotkeys(...)` when user-defined contexts are present; `hotkeys_global.lua` remains the legacy scaffold until the loader-backed global context lands.
- Applications launcher has been fully migrated into `main/user/actions.lua` using canonical primitives, and the legacy `buildApplicationAction` block plus menu wiring were removed from `main/user/userActions.lua`.

---

## 2. Architecture & Components

| Area | Status |
| --- | --- |
| **Config Loader** | ✅ Phase 1 complete. Loads `actions.lua` / `menus.lua`, deep copies data, enforces schema rules, cross-validates references, and reports diagnostics (not yet driving runtime wiring). |
| **Hotkey Registry** | ⚙️ Legacy registry via `userActions.lua` remains active. Phase 3 will re-source data from the loader and add guard-aware registration; `main/user/hotkeys/hotkeys_global.lua` is still bespoke pending migration. |
| **Menu Builder** | 🚧 In progress (Phase 2). `main/core/menu_builder.lua` now builds menu trees, applies policy filters, and assigns shortcuts with numeric conflict fallbacks; runtime wiring remains outstanding. |
| **Runtime Engine** | ✅ Existing action runner continues to execute steps with error handling; no regressions introduced during Phase 1. |
| **Diagnostics** | ⏳ Pending (Phase 4). Loader emits inline diagnostics, but the unified `Validate Config` workflow and structured reports still need implementation. |

---

## 3. Authoring Workflow

### Current Bridge Workflow

1. Continue defining leader modules, actions, and hotkey contexts in `main/user/userActions.lua` (and associated `main/user/modules/` files). This remains the runtime source of truth until Phase 2 lands.
2. Adjust module-level metadata (`leader`, `rootEntries`, `contrib`) to influence what the refactored registry exposes at the leader root.

### Target Workflow (Enabled by Phase 1 Loader)

1. Declare or update actions in `main/user/actions.lua`. Each action will own its execution steps, hotkeys, menu membership, and metadata.
2. Shape menu structure in `main/user/menus.lua`. Menus specify hierarchy, root inclusion, and policy filters (tags, submenus, auto-population).
3. Run `lua tests/test_config_loader.lua` to validate schema changes before wiring them into runtime components.
4. Once Phase 2+ are in place, reloading hsLauncher will consume loader output, rebuild menus, register hotkeys, and emit conflict reports.

Both declarative files may `require` helper modules (e.g., `actions_filesystem.lua`) as long as the resulting tables comply with the primitives below.

---

## 4. Canonical Primitives

These primitives define the complete schema for Actions and Menus. Treat them as the single source of truth for validation and IDE hints.

```lua
-- Action (universe of options)
-- Required fields: name, actions
-- Optional fields: hotkey, menuDetails, tags, enabled, guard, onError, variables

-- Type: table
Action = {
   -- REQUIRED: internal unique identifier for logs, references, and cross-links
   name = "string",

   -- REQUIRED: sequence of steps to execute (each step is a string evaluating to a callable or a descriptor table)
   -- Examples of string steps:
   --   'hsLauncher.main.core.actions.open("~/Scripts/")'
   --   'hsLauncher.main.core.actions.sleep(300)'
   -- Descriptor table alternative (optional feature):
   --   { fn = "hsLauncher.main.core.actions.open", args = {"~/Scripts/"} }
   actions = "array<string|table>",

   -- OPTIONAL: map this action to hotkeys across contexts
   hotkey = {
      -- OPTIONAL: Context scopes describing where the hotkey is active or inactive
      -- If empty/omitted → treated as global active
      context = "array<{
         -- Context identifier:
         --   'global' or macOS bundle id (e.g., 'com.apple.finder') or a custom namespace
         context = 'string',
         -- Whether hotkey is active within this context
         active = 'boolean' -- default: true
      }>",

      -- REQUIRED if hotkey present: how the keys are pressed
      trigger = {
         -- REQUIRED: one or more entries; if >1, must specify multikeyType
         keys = "array<{
            -- REQUIRED: physical key (e.g. 's', 'o', 'f13')
            key = 'string',

            -- OPTIONAL: modifiers; any combination of:
            --   'cmd', 'alt', 'opt', 'ctrl', 'shift', 'fn', 'hyper'
            mods = 'array<string>' -- default: {},

            -- OPTIONAL: tap count required to fire (1 = single tap, 2 = double tap, etc.)
            taps = 'number', -- default: 1

            -- OPTIONAL: hold behavior
            hold = {
               holdNeeded = 'boolean', -- default: false
               holdTimeMs = 'number'   -- default: core default (e.g., 500)
            }
         }>",

         -- REQUIRED if keys length > 1:
         -- 'chord'   → simultaneously pressed
         -- 'sequence'→ pressed in order (e.g., key A then key B)
         multikeyType = "string: 'chord' | 'sequence'",

         -- OPTIONAL: time window for sequences (ms)
         sequenceTimeoutMs = "number" -- default: core default (e.g., 800)
      }
   },

   -- OPTIONAL: information for menu presentation and membership
   menuDetails = {
      -- Short human-readable description
      description = "string", -- default: name

      -- Primary per-menu mnemonic (single character or digit preferred)
      defaultShortcut = "string", -- optional

      -- Fallback mnemonic on collision
      fallbackShortcut = "string", -- optional

      -- Menus in which this action appears
      inMenu = "array<string>", -- e.g., {'globalRoot','fileSystem'}

      -- Optional per-menu overrides (fine-tuning)
      -- Example:
      -- perMenu = {
      --   fileSystem = { description = "Open Scripts", defaultShortcut = "s" }
      -- }
      perMenu = "table<string, { description?: string, defaultShortcut?: string, fallbackShortcut?: string }>",

      -- Visibility controls
      hidden = "boolean" -- default: false
   },

   -- OPTIONAL: free-form labels (for search, grouping, filtering)
   tags = "array<string>",

   -- OPTIONAL: master switch
   enabled = "boolean", -- default: true

   -- OPTIONAL: predicate to decide at runtime if action may run
   -- E.g., function or string expression evaluated by core
   guard = "function|string", -- default: nil

   -- OPTIONAL: error handling strategy
   onError = {
      -- 'silent'  → swallow and log
      -- 'notify'  → user notification
      -- 'raise'   → rethrow to global handler
      strategy = "string: 'silent' | 'notify' | 'raise'", -- default: 'notify'
      retries = "number", -- default: 0
      backoffMs = "number" -- default: 0
   },

   -- OPTIONAL: ephemeral vars injected into the action runtime scope
   variables = "table<string, any>"
}

-- Validation & behavior rules
-- * name must be unique.
-- * If trigger.keys has more than one entry, multikeyType is required.
-- * defaultShortcut and fallbackShortcut should be a single glyph.
-- * menuDetails.inMenu entries must reference menus defined in menus.lua or 'globalRoot'.
-- * Shortcut collisions unresolved after fallback trigger numeric assignment + conflict report.
```

```lua
-- Menu (universe of options)
-- Required fields: title
-- Optional fields: description, defaultShortcut, fallbackShortcut, subMenus, memberRoot, excludeMenu, policy, sort

-- Type: table
Menu = {
   -- REQUIRED: unique internal identifier, referenced from actions.menuDetails.inMenu
   title = "string",

   -- OPTIONAL: human-readable label
   description = "string", -- default: title

   -- OPTIONAL: preferred mnemonic within parent menu
   defaultShortcut = "string", -- optional, 1 glyph recommended
   fallbackShortcut = "string", -- optional

   -- OPTIONAL: child menus to nest beneath this one
   subMenus = "array<string>",

   -- OPTIONAL: should this menu be included in the root automatically?
   memberRoot = "boolean", -- default: false (except 'globalRoot' which is implicitly root)

   -- OPTIONAL: for 'globalRoot' or collector menus: menus to exclude from auto-inclusion
   excludeMenu = "array<string>",

   -- OPTIONAL: policy hints for population
   policy = {
      autoPopulateFromActions = "boolean", -- default: true
      includeSubMenus = "boolean", -- default: true
      includeTags = "array<string>", -- default: nil
      excludeTags = "array<string>" -- default: nil
   },

   -- OPTIONAL: sorting and display hints
   sort = {
      by = "string: 'alpha' | 'shortcut' | 'custom'", -- default: 'alpha'
      key = "string" -- default: nil
   }
}

-- Special rules
-- * globalRoot is the root launcher menu; defaults to auto-populating actions and submenus.
-- * Shortcut assignment order: defaultShortcut → fallbackShortcut → numeric keys (1–9) with conflict report.
```

---

## 5. Core Responsibilities (Definition of Done)

1. **Loader:** Load both files (and any includes) deterministically, validate against the primitives, detect duplicates, and report schema violations.
2. **Hotkey Registry:** Register/unregister hotkeys per action, enforce context scopes, handle chords and sequences, and respect guard/enable flags.
3. **Menu Builder:** Build the tree declared in `menus.lua`, auto-populate from actions, respect policy/filters, and resolve shortcuts with conflict reporting.
4. **Runtime:** Execute actions sequentially, honor descriptor tables, inject variables, and apply per-action error strategies.
5. **Diagnostics:** Provide a `Validate Config` command (CLI + UI) that reports unknown menus, duplicate names, shortcut conflicts, missing fields, disabled or guard-blocked actions, with structured logs.

---

## 6. Priority Roadmap & Phases

- **Phase 1 — Config Loader & Schema Validation (Complete):** Loader ingests `actions.lua`/`menus.lua`, deep copies data, validates against primitives, cross-checks menu/action references, and ships with regression coverage (`tests/test_config_loader.lua`).
- **Phase 2 — Menu Generator (P1.5):** Build menu tree assembly on top of the loader output, apply policy filters, resolve shortcut conflicts, and log deterministic conflict reports.
- **Phase 3 — Hotkey Engine Revamp (P2):** Register hotkeys derived from loader output, support chords/sequences/holds, honor context scopes, and integrate guard checks.
- **Phase 4 — Diagnostics Suite (P2.5):** Deliver `Validate Config` CLI/UI command backed by loader output, emit structured diagnostics for unknown menus, duplicate names, shortcut collisions, and guard-disabled actions.
- **Phase 5 — Starter Kit (P3):** Publish three example actions/menus showcasing chords, tag filters, per-menu overrides, and provide onboarding narrative tied to the new schema.
- **Phase 6 — Test Harness Expansion (P3.5):** Add unit/integration coverage for loader, menu generator, hotkey engine, runtime error handling, and diagnostics reporting.

Stretch ideas once parity is solid: async action steps, telemetry for menu usage, per-app menu overrides via `menuDetails.perMenu` extensions.

---

## 7. Testing & Verification

Run after meaningful changes:

```bash
lua tests/test_config_loader.lua      # schema validation + duplicate detection
lua tests/test_leader_registry.lua    # leader root assembly and menu contribution coverage
# (Phase 2+) lua tests/test_menu_builder.lua   # menu auto-population, shortcut conflicts
# (Phase 3+) lua tests/test_hotkey_manifest.lua # hotkey registration, chords, sequences
# (Phase 4+) lua tests/test_runtime.lua         # action execution, onError strategies
# (Phase 4+) hs -c "require('tests.validate_config')"
```

`tests/test_leader_registry.lua` now depends on the declarative seed actions (Brave launcher + leader mode entries); re-run it after each migration batch to confirm loader output stays consistent.
`tests/test_startup_failure.lua` anchors the startup diagnostics contract described in `docs/architecture.md`, reinforced by `docs/declarative_parity_plan.md`, and tracked as a guardrail in `docs/core_cleanup_plan.md`; review those references before touching registry or loader boot paths.

Manual smoke checklist:

- Reload hsLauncher via Hammerspoon; confirm `Validate Config` reports success.
- Trigger representative hotkeys (global + app-scoped) to verify guard toggles and hold timing.
- Navigate menus from `globalRoot`, checking auto-populated actions, shortcut assignments, and exclusions.
- Exercise error handling by temporarily disabling an action or forcing a guard failure; confirm logs capture the outcome.

---

## 8. Migration Guidance

- Export legacy registry data before deleting old modules. Convert each legacy entry into an Action definition with matching `menuDetails.inMenu` and tags.
- Map former menu contexts to explicit menus in `menus.lua`. Use `memberRoot` and `excludeMenu` to replicate legacy root behavior.
- Remove obsolete loaders (`user/menus/menu_*.lua`, `user/hotkeys/hotkeys_*.lua`) once the new files are live.
- Update any automation or CLIs that referenced the old registry to consume the new `Validate Config` output or the generated menu/action listings.

---

## 9. Bring-up Checklist

1. Wire hsLauncher into Hammerspoon (ensure `HSLAUNCHER_HOME` points at the spoon, extend `package.path`, call `hsLauncher.start()`).
2. Ensure `logs/` exists and is writable; conflict reports and validation logs land here.
3. Populate `main/user/actions.lua` and `main/user/menus.lua` with starter data; reload Hammerspoon.
4. Run the automated tests and `Validate Config` command; resolve any schema or collision failures.
5. Smoke hotkeys and menus, watching `logs/log.txt` for issues.
6. Document any UX or schema friction to inform the next iteration.

---

## 10. Session Notes — 2025-10-02 @ 14:40 PT

- Phase 1 completed: `config_loader.lua` plus regression tests now validate `actions.lua` / `menus.lua` and surface cross-reference issues.
- Leader registry updated to consume module exports, emit root entries, and preserve extras; test suite expanded to assert shortcut exposure.
- Module and hotkey files realigned with canonical action specs, preparing for menu auto-population.

Follow-up: Begin Phase 2 by designing the menu generator pipeline, enumerating required inputs/outputs, and sketching conflict-resolution strategies before wiring runtime integration.

## 11. Immediate Next Steps

- Wire `menu_builder` output into the runtime path (config loader → builder → leader registry) behind a feature flag so legacy `userActions.lua` can coexist during rollout.
- Extend menu builder coverage to nested submenus, `includeSubMenus = false`, and multi-menu membership to harden conflict handling.
- Surface loader diagnostics through a shared reporting utility so menu builder warnings appear in the same channel as schema errors.
- Document the new builder pipeline in README/onboarding once runtime integration lands.
- Continue porting legacy actions from `main/backup/user/userActions.lua` into the declarative files (`main/user/actions.lua` & `main/user/menus.lua`), targeting the Filesystem context next (folders/files/workspaces).
- As each batch migrates, remove the corresponding contexts from `userActions.lua`, update hotkey specs, and expand loader/leader tests to cover the new declarative entries.
- Populate `main/user/menus.lua` with the planned `externalHotkeys` tree (global + per-app buckets) and tag filters so loader-merged actions become visible immediately after assignment.

## Downstream Tooling Outreach Plan

- **Inventory consumers:** Collect the list of automation clients (internal scripts, CLI tooling, external partners) that historically required `hsLauncher.main.core.hyper_*` imports; capture owners and preferred contact channels.
- **Code scan:** Run `rg "main\.core\.hyper_"` across downstream repos to surface lingering dependencies and share the results with each owner alongside the planned removal timeline.
- **Message template:** Send an announcement that menu builder will become the default and hyper shims are scheduled for removal; include pointers to the declarative startup troubleshooting section and `tests/test_startup_failure.lua` so teams can self-verify.
- **Response log:** Record confirmations, blockers, and migration timelines in the project tracker or the next handoff update; highlight any teams needing support.
- **Follow-up checkpoint:** Schedule a review once responses land to verify no production tooling still imports the archived modules before deleting the shims.
- **Artifacts:** Outreach templates now live in `docs/downstream_outreach.md` (inventory table, scan commands, announcement copy, response log).
- **Local scan:** `rg "hsLauncher.main.core.hyper_" --glob "*.lua"` in this repo only surfaced the expected shim references (`main/core/actions.lua`, `main/core/leader_config.lua`, `main/modules/hotkeys/global_shortcuts.lua`) plus test preloads, confirming no new dependencies.

## 12. Session Notes — 2025-10-02 @ 21:05 PT

- Added `main/core/menu_builder.lua` with numeric shortcut fallback, tag-based inclusion/exclusion, and root membership handling plus `tests/test_menu_builder.lua` covering the primary policies.
- Reconfirmed existing loader coverage; new tests validate per-menu overrides, conflict logging, and root aggregation behavior.
- Updated README status to flag Phase 2 as implementing and refreshed next-step guidance in this handoff.
- Seeded declarative config with initial actions/menus so `tests/test_leader_registry.lua` now runs against loader output (Brave launcher + leader mode entries).

## 13. Session Notes — 2025-10-03 @ 10:20 PT

- Ported the Applications launcher into `main/user/actions.lua`, eliminating the `buildApplicationAction` helper and aligning every entry with the canonical action primitive schema.
- Removed the legacy Applications context from `main/user/userActions.lua`, keeping the remaining contexts intact while declarative coverage expands.
- Verified menu auto-population and action resolution via the existing test suite; user reported all tests passing after the migration.

## 14. Session Notes — 2025-10-03 @ 16:45 PT

- User archived the remaining bespoke runtime scaffolding by relocating the legacy `main/user/` files into `main/backup/user/` so the historical menu/action definitions remain available during the declarative migration.
- Follow-up: When porting additional modules, cross-reference their legacy definitions in `main/backup/user/` before deleting or rewriting them to ensure parity.

## 15. Session Notes — 2025-10-03 @ 18:05 PT

- Agreed on external hotkey ingestion strategy: `main/user/external_hotkeys.lua` will emit canonical action primitives (matching `actions.lua`) and the loader will merge them into the runtime action list while tagging entries for menu routing. Global assignments land in an `externalHotkeys.global` menu; bundle-scoped items land under `externalHotkeys.<bundleId>` automatically, so newly assigned shortcuts surface immediately without a review/approval queue.
- Loader Tasks: treat `external_hotkeys.lua` as optional (empty array by default), reuse action validation across both modules, surface duplicate conflicts across actions/external, and expose a source marker so diagnostics can point at the originating file.
- Menu Tasks: seed `menus.lua` with an `externalHotkeys` root containing `externalHotkeysGlobal` and `externalHotkeysApps` submenus wired via tag filters (`hotkeys.external.global`, `hotkeys.external.app.<bundleId>`); allow the assignment engine to drop entries in the right bucket by applying tags when appending to the file.
- Runtime Tasks: adjust the spoon bootstrap so `package.path`/loader registration happen as soon as the spoon loads (no need to call `:start()` before `require('hsLauncher.*')` works), and update the hotkey manifest flow to consume the merged action set.

## 16. Session Notes — 2025-10-03 @ 19:30 PT

- Implemented the plan above: `main/core/config_loader.lua` now loads `main/user/external_hotkeys.lua` alongside `actions.lua`, shares validation/duplicate detection, and annotates merged records with module provenance for diagnostics.
- Loader return payload includes a unified `actions` list and `actionIndex`, so downstream consumers can resolve entries without caring which module defined them.
- Added the external hotkey stub file plus README coverage; spoon bootstrap already registers package paths on require.
- Follow-up: extend the test suite to cover the merged-path duplicates and module sourcing, and update `menus.lua` to surface the `externalHotkeys` buckets discussed in Session 15.

## 17. Session Notes — 2025-10-03 @ 20:45 PT

- Began wiring `menu_builder` output into the runtime under a guarded flag so we can stage the rollout without breaking legacy `userActions` flows.
- Targeted edits: `main/core/config_loader.lua`, `main/core/menu_builder.lua`, and `main/user/registry.lua`, plus the flag surface in user config.
- Secondary to-dos captured for the next iteration: expand submenu coverage tests, unify diagnostics reporting, and prep `main/user/menus.lua` for the external hotkey buckets.

## 18. Session Notes — 2025-10-03 @ 21:35 PT

- Added `featureFlags.menuBuilder` to `main/user/config.lua` and taught `main/user/registry.lua` to read both the config and an `HSLAUNCHER_MENU_BUILDER` env override. The registry now falls back to legacy data when the flag is off and will consume menu-builder output once the flag is enabled.
- Refactored the registry to lazily load legacy `userActions`, merge loader-defined actions with legacy ones, and construct leader layouts from the appropriate source. Loader and builder diagnostics are merged into a single channel for unified reporting.
- Fixed a startup regression by hoisting the shared `deepCopy` helper above its first call.
- Tests have not been rerun yet; plan to execute at least `lua tests/test_leader_registry.lua` and `lua tests/test_loader_menu_integration.lua` after the feature-flagged path is fully wired.

## 19. Session Notes — 2025-10-03 @ 22:30 PT

- Stood up `main/backup/core/` to archive the unused legacy modules; moved `sequence_runner.lua` and `shortcuts_modal.lua` there as the first batch.
- Removed the thin alias wrappers in `main/core` (`assign_global`, `assign_hotkey`, `combo_utils`, `global_shortcuts`) and updated the test suite to require the canonical `main/modules/hotkeys/*` paths directly.
- Documented the alias removal here so downstream consumers depend on the stable module namespace while the declarative runtime continues to evolve.

## 20. Session Notes — 2025-10-03 @ 23:15 PT

- Added the first declarative runtime scaffolding under `main/runtime/`, including `runtime/action_factory.lua` for compiling action specs and `runtime/hyper/hotkey_resolver.lua` for normalizing triggers/contexts and surfacing hotkey conflicts.
- Captured regression coverage in `tests/test_hotkey_resolver.lua` to lock down canonical key generation, context suppression, and duplicate detection ahead of wiring the resolver into the runtime bootstrap.
- Updated the cleanup plan and architecture docs to reflect Phase 2 progress; next follow-up is integrating the resolver with a dispatcher that feeds the hotkey registry behind the declarative runtime flag.

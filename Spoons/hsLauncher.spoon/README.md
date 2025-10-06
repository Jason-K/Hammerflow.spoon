# hsLauncher

hsLauncher is a Hammerspoon-first automation layer that facilitates user access to hammerspoon functions (`/main/user/modules`), external scripts, and functions that external applications expose for user-configured hotkeys. It allows users to assign hotkeys in the global namespace (`/main/user/hotkeys_Global.lua`) or in application-specific namespaces (e.g., /main/user/hotkeys_QSpace.lua). It also allows users to create modals, which they can call via hotkey assignments in either the global or application-specific namespaces. The absolute core principle is simplicity - a user should only have to edit one location in one file to add a hotkey. Adding a modal entry should be similarly easy. It ships window management, declarative modal authoring, global shortcut assignment, and a conflict-aware manifest so you can extend the stack without rewriting core logic.

---

## Status & Recent Work (2025-10-06)

- **Declarative runtime default:** `main/init.lua` now boots the declarative runtime exclusively; the legacy hyper stack remains archived under `main/backup/core/` for historical reference.
- **Menu builder feature flag:** `main/user/config.lua` still exposes `featureFlags.menuBuilder` (and `HSLAUNCHER_MENU_BUILDER`) so you can toggle the declarative menu pipeline while legacy `userActions.lua` stays available during rollout.
- **Aggregated diagnostics:** `main/user/registry.lua` merges loader + builder diagnostics into a single `[config]` channel and backfills legacy actions when the menu builder flag is off, keeping the runtime usable even if declarative validation fails.
- **Config loader merges external hotkeys:** `main/core/config_loader.lua` ingests both `main/user/actions.lua` and the new `main/user/external_hotkeys.lua`, reusing validation so duplicate detection and diagnostics span all sources before returning a unified action index.
- **External hotkey stub & routing:** `main/user/external_hotkeys.lua` ships as an append-only action list for assignment tooling; loader tagging enables immediate menu exposure once menus adopt the `externalHotkeys.*` structure.
- **Bootstrap requires-ready:** Spoon `init.lua` ensures `package.path` and module loader registration during `require`, so utilities can load hsLauncher modules without waiting for `start()`.
- **Phase 2 implementing:** `main/core/menu_builder.lua` still provides shortcut resolution, tag-based population, and numeric fallback conflicts with coverage in `tests/test_menu_builder.lua`.
- **Leader registry & modules steady:** `main/user/userActions.lua`, registry, and module refresh work from 10-02 remain the runtime surface while the menu generator wiring proceeds.

## Quick Start

1. Point Hammerspoon at the hsLauncher root (copy `hsLauncher/` to `~/.hammerspoon/Spoons/hsLauncher.spoon/` or set `HSLAUNCHER_HOME` to a local checkout):

   ```lua
   local root = os.getenv('HSLAUNCHER_HOME') or (os.getenv('HOME') .. '/.hammerspoon/Spoons/hsLauncher.spoon')
   package.path = table.concat({
     package.path,
     root .. '/?.lua',
     root .. '/?/init.lua',
     root .. '/?/?.lua',
   }, ';')
   local hsLauncher = require('hsLauncher.main.init')
   hsLauncher.start()
   ```

2. Reload Hammerspoon. Tap Hyper briefly to copy any selected text and open the leader root; hold Hyper to open the default window mode as before.

3. Tail logs in `<HSLAUNCHER_HOME or root>/logs/` (defaults to `~/.hammerspoon/Spoons/hsLauncher.spoon/logs/`) if you need to debug startup or binding issues.

> Authoring note: the new loader expects data in `main/user/actions.lua` and `main/user/menus.lua`. Those files currently ship with stubs while we backfill the generator. Continue editing module-backed definitions in `main/user/userActions.lua` until Phase 2 lands.

> Tip: map Caps Lock to `keypad_comma` using `hidutil` or Karabiner so the Hyper engine receives a dedicated scancode.

---

## Feature Flags & Rollout

- Toggle declarative menus with `featureFlags.menuBuilder` in `main/user/config.lua`. The flag defaults to `false` so legacy `userActions.lua` remains authoritative until the new pipeline reaches parity.
- Set `HSLAUNCHER_MENU_BUILDER=1` (or any truthy value) in your environment to force-enable the builder without editing config.
- When the flag is disabled, the registry automatically registers legacy actions and builds leader menus from `userActions.lua`; when enabled, it consumes the loader + `menu_builder` output instead.
- Loader and builder diagnostics now emit through a shared `[config]` channel; check `logs/log.txt` for both schema errors and menu warnings.
- Menu builder reports duplicate and self-referential submenu definitions (`menu.subMenus.duplicate`, `menu.subMenus.self`) to help harden nested layouts before switching the flag on.
- Declarative runtime now runs by default; the legacy hyper stack is archived under `main/backup/core/` for reference if you need to inspect historical behavior.

## Project Layout

| Path | Purpose |
| --- | --- |
| `main/init.lua` | Startup orchestration for the declarative runtime (registry load, logging, diagnostic wiring). |
| `main/core/` | Canonical subsystems: actions runner, window stack, logger, diagnostics, plus thin shims to legacy hyper modules now archived under `main/backup/core/`. |
| `main/backup/core/` | Archived legacy hyper/leader runtime, modal GUI, and supporting helpers retained for reference while the declarative runtime rolls out. |
| `main/core/config_loader.lua` | Phase 1 loader that ingests `main/user/actions.lua` / `menus.lua`, performs schema validation, and returns diagnostics. |
| `main/modules/hotkeys/` | Hotkey primitives shared by assigners, CLI tooling, and manifest collection. |
| `main/user/userActions.lua` | Transitional source of truth for leader modules, hotkey contexts, and user-defined actions. |
| `main/user/actions.lua` / `main/user/menus.lua` | New declarative surface targeted by the loader (currently populated with stubs pending menu generator integration). |
| `main/user/external_hotkeys.lua` | Optional external shortcut append file; validated and merged alongside `actions.lua`. |
| `docs/` | Historical design notes and generated catalogs (superseded by this README + `HANDOFF.md`). |
| `tests/test_config_loader.lua` | Regression tests covering loader success paths, duplicate detection, and schema failures. |
| `tests/` | Additional Lua regression tests for leader registry, manifest validation, and agent templates. |
| `logs/` | Runtime logs and generated manifest/registry exports. |

`main/user/userActions.lua` prepares leader modules, hotkey contexts, and shared user metadata. The file remains the authoritative bridge until the loader fully replaces the legacy exports.

`main/modules/` houses feature bundles that build on the lower-level primitives in `main/core/`. Keep shared engines (input, windowing, manifest) in `core/` and place higher-level orchestration or hotkey-specific helpers under `modules/` so the separation stays clear.


## Guiding Objectives

1. **Unified Hotkey Assignment Framework** – Support a single registry-aware pipeline for assigning hotkeys to (A) native Hammerspoon actions, (B) external scripts across Python, AppleScript, shell, JXA, and more (with parameters), (C) global shortcuts that trigger third-party apps (e.g., `cmd+space` for Raycast), and (D) application-scoped shortcuts that respect an app’s default bindings while avoiding conflicts.
2. **Conflict-Aware Registry** – Maintain an authoritative catalog of every active global and app-specific shortcut so allocation tools can detect collisions before they are committed.
3. **Stateful Physical Key Mapping** – Allow physical keys (such as Caps Lock now mapped through the Hyper key) to dispatch different behaviors based on tap count, hold state, concurrent modifiers, or simultaneous key presses.
4. **Sequence & Gesture Grammar** – Enable multi-step and multi-state sequences (tap–tap, tap → hold, A then B, A+B, etc.) so complex workflows can be built declaratively.
5. **Leader Workflow Consolidation** – Migrate the legacy mix of Karabiner, Hammerspoon, AppleScript, and standalone applications into the Hyper/Leader stack. Current priorities include: single-tap Caps Lock emitting copy → Leader, directional window tiling with cycling ratios on Hyper+arrows, cross-screen transport on Hyper+Shift+arrows, and Hyper+Space toggling maximized vs centered layouts.
6. **Extensibility for Future Leader Replacements** – Once the Hyper foundation is solid, iterate on replacing remaining Leader key automations with first-class hsLauncher modules and user-facing configuration.

These objectives inform the backlog in `HANDOFF.md` and the roadmap bullets later in this README. Each new feature should advertise which objective it advances so tooling, docs, and tests remain aligned.

---

## Core Concepts

### Hyper Modes & Modal Authoring

- Modes are declared with `hyper.defineMode(name, spec)` using the shared `ModeSpec` schema.
- Each entry describes `key`, `description`, `action`, optional `label`, `section`, `order`, `note`, and `exitAfter`.
- `Actions.*` helpers wrap common behaviors (window operations, keystrokes, shell, AppleScript, user actions, sequences) with automatic error logging.
- Layout metadata (`layout = { width, sectionOrder, groups, footerText, ... }`) drives the modal overlay. Exit keys default to Escape/Return/Space/Tab via `core/exit_keys.lua`.
- Set `layout.preset` (`'compact'`, `'spacious'`, `'inspector'`, `'centered'`, etc.) to start from curated canvas presets; mix in overrides for font sizes, grouping, and anchors without rebuilding defaults.
- `chordEntries` document multi-key combos alongside solo bindings so the GUI and manifest stay in sync.

### Declarative Hotkey Surfaces

1. **Hyper configuration** (`main/user/hotkeys/config.lua`)
   - `hyperBindings`: top-level Hyper tap bindings (e.g., `q` → move window west).
   - `modes`: declarative modal specs consumed by the loader.
   - `sequences`: leader-style sequences (e.g., `{'h','a'}` → assign menu hotkey).
   - `apps`: app-specific modal overlays with optional predicates and triggers.
   - The loader (`main/user/hotkeys/loader.lua`) resolves actions, wraps predicates (`predicates.lua`), and wires everything to the live Hyper instance via `hyper.bindSpec` / `hyper.addSequenceSpec`, so include `description`/`source` metadata in your config.

2. **Leader modules** (`main/user/modules/*.lua`)
   - Each module exports `actions` plus optional `leader.groups` metadata.
   - `main/user/registry.lua` aggregates enabled modules from `main/user/config.lua` and feeds them into `core/leader_config.lua`.
   - Shared actions can be referenced from Hyper modes via `userAction('module.action')`.

3. **Global shortcuts** (via `main/user/hotkeys_Global.lua`)
   - The global context exposes a `globalShortcuts` table that the hotkey engine ingests alongside Hyper bindings.
   - Populate taps, chords, sequences, double taps, and disabled combos using the same action specs as Hyper entries.
   - Supports string modifiers (`'hyper'`, `'meh'`) that expand to the chord defined in `core/config.lua`.
   - Provide `mode = 'window'` (or `action = Actions.enterMode('window')`) to launch any Hyper modal from a shortcut—even without holding the Hyper key.
   - Scope shortcuts to specific apps with `apps = { 'bundle:com.hypernote.app' }`, `appNames = { 'Hypernote' }`, or a custom `when` predicate; when inactive, the original key falls through untouched.
   - Built-in examples resolve local scripts via `BasePaths.runtimeFile(...)`; override the Quick Search AppleScript path with `HSLAUNCHER_QUICKSEARCH_SCRIPT` or place the script under `scripts/jjk_QuickSearch/` to avoid hard-coded home directories.

### Runtime Manifest & Tooling

`core/hotkey_manifest.lua` records every binding (Hyper solo/chord, sequences, global shortcuts) with scope, trigger, action summary, and provenance. Startup validation highlights duplicates or missing metadata, and the CLI exposes rich queries.

- `hs hsLauncher.main.tools.hotkey_manifest_cli run list --scope=hyper.mode --summary`
- `hs hsLauncher.main.tools.hotkey_manifest_cli run list --format=markdown --text=window`
- `hs hsLauncher.main.tools.hotkey_manifest_cli run docs docs/hotkey_manifest_catalog.md`
- `hs hsLauncher.main.tools.hotkey_manifest_cli run validate --format=json`
- `hs.console` → `=require('hsLauncher.main.core.modal_inspector').log('window')` to snapshot modal layouts, presets, and grouping diagnostics at runtime.

Global assignment data still lives in `modules/hotkeys/hotkey_registry.lua`; manage it with:

- `hs hsLauncher.main.tools.hotkey_registry_cli run list`
- `hs hsLauncher.main.tools.hotkey_registry_cli run export ~/Desktop/hotkeys.json`
- `hs hsLauncher.main.tools.hotkey_registry_cli run import ~/Desktop/hotkeys.json`

Interactive assignments (`Actions.assignGlobal`, Hyper → `h` `g`) now capture optional external script metadata—type, target, and parameters—when you apply or resend a combo. The details are stored alongside each registry entry so you can audit, update, or remove the script binding during future passes.

---

## Extending hsLauncher

1. **Add a reusable module** under `main/core/` (or `main/modules/...`) with a clean API.
2. **Surface it through Actions** by adding a helper in `core/actions.lua` (e.g., `Actions.myFeature()` → `Actions.moduleFn('hsLauncher.main.core.my_feature', 'run')`).
3. **Expose configuration** via `core/config.lua` or `main/user/config.lua` so users can toggle behavior without editing core files.
4. **Bind it declaratively** using the Hyper loader, leader modules, or global shortcuts.
5. **Document provenance** so the manifest records meaningful metadata.

> Need an imperative hook? Prefer `hyper.bindSpec` / `hyper.addSequenceSpec` and include a `description` and `source` so manifest validation stays clean.

> Core directories (`main/core/`, `main/modules/`) may be overwritten by upstream updates—keep user customizations under `main/user/`.

---

## Development Workflow

- Run tests locally:

  ```bash
  lua tests/test_actions.lua
  lua tests/test_leader_registry.lua
  lua tests/test_hotkey_manifest.lua
      lua tests/test_startup_failure.lua
  hs -c "require('tests.run')"
   lua -l tests.run
  ```

- The startup regression (`tests/test_startup_failure.lua`) ensures `hsLauncher.start()` surfaces loader and menu-builder failures instead of silently falling back, so keep it green when touching registry or runtime boot code. The failure expectations are documented in `docs/architecture.md`, reinforced in `docs/declarative_parity_plan.md`, and tracked in `docs/core_cleanup_plan.md` as a guardrail for future bootstrap work.

- Generate a manifest catalog after changing bindings:

  ```bash
   hs hsLauncher.main.tools.hotkey_manifest_cli run docs docs/hotkey_manifest_catalog.md
  ```

- Use `logs/log.txt` for action runner output, modal lifecycle traces, and registry changes. Promote structured logging via `core/logger.lua` when adding new modules.

### Troubleshooting Declarative Startup

- Declarative startup is the default path: `hsLauncher.start()` aborts if the loader or menu builder reports `ok = false`. The regression test `tests/test_startup_failure.lua` captures the contract and mirrors the guidance in `docs/architecture.md`, `docs/declarative_parity_plan.md`, and `docs/core_cleanup_plan.md`.
- Expect an `[info] hsLauncher start` entry before any failure plus an `[error] config loader did not complete successfully` or `[error] menu builder did not complete successfully` line when startup stops; both land in `logs/log.txt` under the `[core]` channel.
- Common diagnostics:
   - `[config] loader.actions.missingFile` – `main/user/actions.lua`, `menus.lua`, or `external_hotkeys.lua` was not found or returned nil; ensure each file returns a table.
   - `[config] loader.validation.schema` – action or menu schema violation; rerun `lua tests/test_config_loader.lua` for details.
   - `[config] menuBuilder.shortcuts.conflict` – shortcut collision unresolved after fallback; adjust `menuDetails` overrides or tags.
   - `[runtime] registry.declarativeUnavailable` – registry returned nil declarative state; confirm `main/user/registry.lua` completes the declarative branch.
- After addressing the diagnostics, rerun the targeted unit test plus `lua tests/test_startup_failure.lua` to confirm the failure mode stays covered before reloading Hammerspoon.

---

## Additional Resources

- `AGENTS.md` – operating agreements for AI collaborators.
- `HANDOFF.md` – current project status, roadmap checkpoints, and next steps.
- `docs/snippets/agentTemplate.lua` – canonical agent template (with matching spec in `tests/agentTemplate_spec.lua`).
- `docs/hotkey_manifest_catalog.md` – generated manifest snapshot (refresh via CLI above).
- `docs/downstream_outreach.md` – templates for inventorying consumers, scanning repos, and tracking responses before removing hyper shims.

Contributions should preserve declarative specs, keep core modules pure, and route all bindings through the manifest to maintain auditability.

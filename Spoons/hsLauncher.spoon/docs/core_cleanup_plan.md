# hsLauncher Core Cleanup Plan

## Purpose

Clarify which modules under `main/core` are part of the declarative, loader-driven pipeline versus legacy runtime scaffolding, then outline how to relocate the legacy pieces into `main/backup/core` without breaking the current transition state. This plan prioritizes enabling the declarative paradigm (actions + menus + future hotkey engine) while preserving a reference implementation of the abandoned workflow for historical lookups.

## Inputs Reviewed

- `README.md` for high-level roadmap and current bridge workflow
- `HANDOFF.md` for recent migration history and pending phases
- Full inventory of `main/core/*.lua`
- Active tests in `tests/` (config loader, menu builder, leader registry, actions, hotkey manifest)
- Select `main/user/*.lua` files to confirm runtime consumers

## Core Module Inventory

| Module                   | Purpose (current)                                                   | Primary consumers                                         | Status                | Proposed action                                                                         |
| ------------------------ | ------------------------------------------------------------------- | --------------------------------------------------------- | --------------------- | --------------------------------------------------------------------------------------- |
| `action_runner.lua`      | Executes declarative action specs (open, keystroke, shell, etc.)    | `core/actions`, menu/registry runtime                     | **Active**            | Keep in `main/core`                                                                     |
| `actions.lua`            | Canonical action constructors/resolvers, used by declarative tables | Declarative config, hotkey loader, modules                | **Active**            | Keep in `main/core`                                                                     |
| `app_menu_inspector.lua` | Collects existing app menu shortcuts to avoid collisions            | Hotkey allocator (`modules/hotkeys/hotkey_allocator.lua`) | **Active**            | Keep (rename alongside hotkey runtime later)                                            |
| `assign_global.lua`      | Thin alias into `modules/hotkeys`                                   | Legacy runtime, handler factories                         | **Bridge**            | Replace callers → drop alias after refactor                                             |
| `assign_hotkey.lua`      | Thin alias into `modules/hotkeys`                                   | Legacy runtime, handler factories                         | **Bridge**            | Same as above                                                                           |
| `base_paths.lua`         | Resolves repo-rooted paths for logs, temp, etc.                     | Logger, hotkey manifest, diagnostics                      | **Active**            | Keep                                                                                    |
| `combo_utils.lua`        | Thin alias into `modules/hotkeys` helpers                           | Legacy runtime                                            | **Bridge**            | Replace callers → drop alias                                                            |
| `config.lua`             | Runtime configuration (hyper key, windows tuning)                   | Hyper modal, window manager, hotkey allocator             | **Active**            | Keep, but document overrides                                                            |
| `config_loader.lua`      | Declarative loader for actions/menus/external hotkeys               | Tests, user registry, future runtime                      | **Active**            | Keep                                                                                    |
| `diagnostics.lua`        | Common diagnostic logging for loader/builder                        | User registry, future CLI                                 | **Active**            | Keep                                                                                    |
| `exit_keys.lua`          | Normalizes/ensures exit keys for legacy modal UI                    | Hyper modal, modal GUI                                    | **Legacy**            | Move to `backup/core`; new modal stack should own its exits                             |
| `fs.lua`                 | Filesystem helper (join, read/write, ensure dirs)                   | Logger, loader, module actions                            | **Active**            | Keep                                                                                    |
| `global_shortcuts.lua`   | Alias into `modules/hotkeys/global_shortcuts`                       | Hyper runtime                                             | **Bridge**            | Replace callers → drop alias                                                            |
| `hotkey_manifest.lua`    | Records hotkey metadata for diagnostics/reporting                   | Hyper modal, registry, tests                              | **Active**            | Keep                                                                                    |
| `hyper_modal.lua`        | Monolithic legacy hyper key engine + UI integration                 | Runtime entry (`main/init.lua`), registry                 | **Legacy (critical)** | Extract new engine; archive current impl under backup                                   |
| `indicator.lua`          | Canvas indicator for hyper state                                    | Hyper modal                                               | **Legacy**            | Move with hyper stack (or rebuild slimmer status widget)                                |
| `input_engine.lua`       | Key event tap handling for legacy hyper modal                       | Hyper modal                                               | **Legacy**            | Replace with declarative hotkey engine; archive current impl                            |
| `leader_buffer.lua`      | Sequence buffer helper for legacy leader sequences                  | Hyper modal                                               | **Legacy**            | Inline/replace when new engine lands; archive old version                               |
| `leader_config.lua`      | Builds legacy leader menu structures, still bridges to registry     | User registry, hyper modal                                | **Hybrid**            | Refactor to consume declarative menu manifest only; move legacy-specific code to backup |
| `logger.lua`             | Simple file-based logger                                            | Most modules                                              | **Active**            | Keep (consider centralizing logging later)                                              |
| `menu_builder.lua`       | Declarative menu assembly with shortcut assignment                  | Tests, registry, future runtime                           | **Active**            | Keep                                                                                    |
| `modal_gui.lua`          | Canvas-based modal renderer (legacy)                                | Hyper modal, modal inspector                              | **Legacy**            | Move to backup once new declarative UI lands                                            |
| `modal_inspector.lua`    | Ad-hoc debugging API around `modal_gui`                             | Manual tooling                                            | **Legacy**            | Move with modal GUI                                                                     |
| `modal_layouts.lua`      | Preset layout definitions for modal GUI                             | Modal GUI                                                 | **Legacy**            | Move with modal GUI                                                                     |
| `mode_spec.lua`          | Legacy structured mode compiler feeding hyper modal                 | Hyper modal                                               | **Legacy**            | Move with hyper modal stack                                                             |
| `mods.lua`               | Normalizes modifier strings (`hyper`, `meh`, etc.)                  | Actions, hotkey loader                                    | **Active**            | Keep                                                                                    |
| `module_actions.lua`     | Helper to build action specs for legacy contexts                    | `user/userActions.lua`, modules                           | **Bridge**            | Eventually replace with declarative wrappers; keep for now                              |
| `sequence_runner.lua`    | Legacy JSON sequence executor (unused)                              | None discovered                                           | **Dead**              | Archive immediately under backup                                                        |
| `shortcuts_modal.lua`    | Wrapper around legacy shortcuts mode (unused)                       | None discovered                                           | **Dead**              | Archive immediately under backup                                                        |
| `window_geometry.lua`    | Geometry helpers for window manager                                 | `windows_native.lua`                                      | **Active**            | Keep                                                                                    |
| `window_history.lua`     | Undo stack for window operations                                    | `windows_native.lua`                                      | **Active**            | Keep                                                                                    |
| `window_neighbors.lua`   | Adjust neighbor windows after operations                            | `windows_native.lua`                                      | **Active**            | Keep                                                                                    |
| `windows_native.lua`     | Primary window management actions                                   | Actions/module handlers                                   | **Active**            | Keep                                                                                    |

### Classification legend

- **Active**: Aligned with declarative pipeline or current runtime action targets; stays in `main/core`.
- **Bridge**: Transitional adapters between legacy runtime and new modules; plan to collapse once callers migrate.
- **Legacy**: Part of the abandoned modal/leader runtime; keep working reference in `main/backup/core` while new implementation is built.
- **Dead**: No live references; safe to archive immediately.

## Legacy Cluster Overview

The legacy cluster is the hyper/leader runtime and its canvas UI:

- `hyper_modal.lua`
- `input_engine.lua`
- `leader_buffer.lua`
- `indicator.lua`
- `exit_keys.lua`
- `mode_spec.lua`
- `modal_gui.lua`
- `modal_layouts.lua`
- `modal_inspector.lua`
- Dependent helpers (`shortcuts_modal.lua`, `sequence_runner.lua`)

These files interdepend heavily and still power the live runtime via `main/init.lua`. They should move together once a declarative replacement is ready. Until then, keep them under feature-flag control (as already done via `featureFlags.menuBuilder`) to enable incremental migration.

## Target Layout Proposal

```text
main/
  core/            # Declarative loader, menu builder, shared libs, action runner
  runtime/         # New declarative runtime (hotkey engine, modal presenter, leader integration)
  backup/
    core/          # Archived legacy modal/leader implementation (read-only)
```

During transition we can stage files in `runtime/` while keeping `hyper_modal` live. Once parity is achieved, relocate the legacy stack to `backup/core` and update `init.lua` to point at the new runtime modules.

## Migration Plan

### Phase 0 – Baseline & guardrails

- [x] Add a `docs/architecture.md` section (or expand this plan) describing desired runtime layering.
- [x] Ensure existing tests (`test_config_loader.lua`, `test_menu_builder.lua`, `test_leader_registry.lua`) run clean; add CI gate if missing.
- [x] Capture runtime smoke checklist (hyper tap, leader menus, window actions) for regression testing.

### Phase 1 – Quick hygiene wins

- [x] Create `main/backup/core/` and move immediately unused files (`sequence_runner.lua`, `shortcuts_modal.lua`).
- [x] Replace direct requires of `core/assign_*` aliases with `modules/hotkeys/*` to simplify the namespace, then delete the aliases.
- [x] Document alias removals in `HANDOFF.md`.

### Phase 2 – Carve out new declarative runtime scaffolding

- [x] Design a declarative hotkey engine that consumes loader output (align with Phase 3 roadmap in `HANDOFF.md`) — initial `runtime/action_factory.lua` and `runtime/hyper/hotkey_resolver.lua` scaffolding landed.
- [x] Prototype new modules under `main/runtime/hyper/` (e.g., `dispatcher.lua`, `registrar.lua`, `ui.lua`).
- [x] Update `tests/` to cover the new runtime pieces (unit tests for dispatcher, integration tests for loader → runtime wiring).

### Phase 3 – Feature parity + flag-driven swap

- [x] Implement menu presentation based on `menu_builder` output (likely new lightweight UI instead of `modal_gui`).
- [x] Rebuild leader sequencing with declarative metadata (replacing `leader_buffer` and `mode_spec`). Initial pass lives in `main/runtime/menu/sequences.lua` with coverage in `tests/test_menu_sequences.lua`.
- [x] Introduce runtime feature flag (`featureFlags.declarativeRuntime` + `HSLAUNCHER_DECLARATIVE_RUNTIME`) to toggle between legacy and new implementation.
- [x] When flag enabled, ensure `main/init.lua` uses the new runtime path; run regression tests and manual smoke. Fallback to legacy path when declarative startup reports an error so the spoon remains usable while stabilizing the new runtime.

### Phase 4 – Archive legacy stack

- [ ] Move `hyper_modal.lua`, `input_engine.lua`, `leader_buffer.lua`, `indicator.lua`, `exit_keys.lua`, `mode_spec.lua`, `modal_gui.lua`, `modal_layouts.lua`, and `modal_inspector.lua` into `main/backup/core/`.
- [ ] Update `README`/`HANDOFF` to reference the archival location and new runtime modules.
- [ ] Remove feature flag fallback once the new runtime stabilizes.

### Phase 5 – Clean-up and documentation

- [ ] Delete or rewrite any remaining bridge helpers (e.g., `module_actions.lua`) after declarative stubs cover all use-cases.
- [ ] Prune backup files once no longer needed, or mark them clearly as read-only historical artifacts.
- [ ] Refresh developer onboarding docs to describe the fully declarative workflow.

## Risks & Mitigations

| Risk                                                                               | Impact                             | Mitigation                                                                                       |
| ---------------------------------------------------------------------------------- | ---------------------------------- | ------------------------------------------------------------------------------------------------ |
| Hyper runtime regression while refactoring                                         | Loss of leader/hyper functionality | Feature flags + dual-path tests + manual smoke checklist                                         |
| Declarative runtime lacking parity (menus, sequences, UI expectations)             | User experience regressions        | Reuse loader/menu builder data, port UI requirements into declarative schema before cutting over |
| Hidden dependencies on legacy modules (e.g., direct `require` in personal scripts) | Breakage outside repo              | Search repo for stray requires, document breaking changes, optionally supply shims               |
| Time sink reimplementing UI                                                        | Slows migration                    | Scope MVP UI (text-based palette or simple chooser) before feature parity polish                 |

## Immediate Next Steps

1. Stand up `main/backup/core/` and relocate unused modules (`sequence_runner.lua`, `shortcuts_modal.lua`).
2. Replace alias modules (`assign_*`, `combo_utils`, `global_shortcuts`) with direct requires to reduce surface area.
3. Draft the runtime architecture doc describing desired declarative hotkey/leader flow (inputs, outputs, state, UI expectations).
4. Review the "pre-declarative" branch to confirm there are no additional legacy dependencies hiding elsewhere before files move.

Tracking these items centrally (e.g., project board or issue list) will keep the migration focused and prevent regression gaps.

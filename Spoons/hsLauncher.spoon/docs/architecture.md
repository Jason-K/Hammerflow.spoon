# hsLauncher Runtime Architecture

Last updated: 2025-10-06

## Layering Overview

The runtime is organized into three cooperating layers that reflect the declarative pipeline and the legacy scaffolding we are phasing out:

1. **Core (`main/core/`)**

   - Home of declarative infrastructure that is environment agnostic.
   - Includes the config loader, menu builder, action runner, diagnostics helpers, filesystem utilities, and other pure services.
   - Guarantees: deterministic behavior, no direct dependence on Hammerspoon UI state, reusable by future CLI tooling.

2. **Runtime (`main/runtime/`)**

   - Hosts the declarative hotkey engine, modal presenter, and leader orchestration now used by default.
   - Consumes loader + builder output, registers hotkeys, renders menus, and mediates feature flags.
   - Implementation under `main/runtime/hyper/` maintains clear boundaries between dispatcher, registrar, and UI concerns.
   - **Core components:** `runtime/action_factory.lua` compiles declarative actions into runnable specs while `runtime/hyper/hotkey_resolver.lua` normalizes triggers, contexts, and conflict detection ahead of registration.
   - **Runtime services:** `runtime/hyper/dispatcher.lua` coordinates hotkey registration, `runtime/hyper/registrar.lua` abstracts binding lifecycles, and `runtime/hyper/ui.lua` renders an interim textual view for assignments.

3. **Backup (`main/backup/`)**
   - Stores read-only legacy implementations for reference during the migration.
   - `main/backup/core/` now contains the deprecated sequence/shortcuts modules; the remaining hyper stack will relocate here once the declarative runtime reaches parity.
   - `main/backup/user/` preserves the pre-declarative user configuration for historical lookup.

```text
main/
  core/            -- declarative services + shared libraries
   runtime/         -- declarative runtime (hotkey engine, modal UI)
  backup/
    core/          -- archived legacy modal/hyper stack (read-only)
    user/          -- legacy user actions/menus
```

## Data Flow

1. **Loader Stage** — `core/config_loader.lua`

   - Reads `main/user/actions.lua`, `menus.lua`, and `external_hotkeys.lua`.
   - Validates schema, merges actions, and emits diagnostics plus an indexed payload.

2. **Builder Stage** — `core/menu_builder.lua`

   - Transforms loader payload into resolved menus with shortcut assignments and policy enforcement.

3. **Runtime Stage**

   - Declarative hotkey engine consumes loader output to register contexts/chords/sequences.
   - Menu presenter consumes builder output to render modal/UI experiences.
   - Menu builder feature flag still gates menu integration; the declarative runtime now ships as the default path.

4. **Execution Stage** — `core/action_runner.lua`
   - Executes action specs with logging, guard checks, and error handling strategies.
   - Regression coverage: `tests/test_startup_failure.lua` exercises loader/menu-builder failure paths so runtime bootstrap changes must keep emitting actionable diagnostics; its expectations are propagated through `docs/declarative_parity_plan.md` and the cleanup guardrails in `docs/core_cleanup_plan.md`.

## Migration Guardrails

- Keep the legacy hyper stack archived in `main/backup/core/` for reference while the declarative pipeline continues to gain coverage.
- Archive unused legacy files in `backup/core/` as soon as they are no longer referenced to reduce namespace noise.
- Replace bridge aliases with direct module imports to enforce a single canonical namespace for hotkey helpers.
- Document each archival or namespace change in `HANDOFF.md` to guide downstream consumers.

## Smoke Checklist

Maintain the following manual checks during each migration batch:

- Reload hsLauncher and confirm no startup errors in `logs/log.txt`.
- Trigger representative hyper shortcuts (window management, applications launcher) with the legacy stack enabled.
- Toggle `featureFlags.menuBuilder` to validate the declarative path stays green in tests and manual use.
- Verify menu conflicts are logged when expected and that menu items resolve to the correct actions.

## Next Steps

- Harden declarative runtime dispatcher and registrar coverage, especially around failure/retry paths.
- Document troubleshooting guidance for declarative startup, including how to inspect archived legacy modules when debugging; reference the new startup failure regression in onboarding material.
- Continue migrating legacy `main/core` modules into `backup/core/` as their declarative replacements come online.

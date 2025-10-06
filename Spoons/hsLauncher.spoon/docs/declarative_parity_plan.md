# Declarative Runtime Parity Verification

## Purpose

Ensure the new declarative runtime provides functional parity with the legacy hyper/leader stack. This checklist captured the verification steps used before removing the legacy fallback and should continue to guide future regression validation.

## Dependency Audit

- Core shims now delegate to archived modules under `main/backup/core/`.
- Remaining direct imports of legacy modules originate from:
  - `main/init.lua`
  - `main/core/leader_config.lua`
  - `main/core/actions.lua`
  - `main/modules/hotkeys/global_shortcuts.lua`
- These modules resolve through the new shim layer; no other packages require legacy modules directly. Re-run `rg "require('hsLauncher.main.core.hyper_modal'"` after major refactors to ensure new direct dependencies are not introduced.

## Automated Verification Roadmap

1. **Loader ↔ Runtime integration tests**
   - Exercise the declarative runtime startup path by loading actions/menus and asserting registered hotkeys, menu graphs, and diagnostics.
   - Use `tests/test_startup_failure.lua` to simulate loader or menu-builder failures and ensure `hsLauncher.start()` surfaces actionable errors rather than silently continuing; keep the expectations aligned with the runtime layering described in `docs/architecture.md` and the safeguards captured in `docs/core_cleanup_plan.md`.
2. **Hotkey dispatch regression suite**
   - Expand `tests/test_hotkey_resolver.lua` with tap/hold/sequence permutations to mirror high-priority leader workflows.
   - Add dispatcher tests covering guard predicates, disabled actions, and error handling strategies.
3. **Menu presentation tests**
   - Create focused specs that compare `menu_builder` output to expected layouts for representative configurations (global root, nested submenus, external hotkey buckets).
   - Validate shortcut conflict reporting and numeric fallback behavior under declarative runtime conditions.
4. **Window/action behavior**
   - Port existing window management specs to run through the declarative runtime invocation path to guarantee action runner compatibility.
5. **CI gate**
   - Introduce a dedicated test entry point (e.g., `tests/test_declarative_runtime.lua`) and wire it into CI prior to flag removal.

## Manual Parity Checklist

- Reload Hammerspoon with declarative runtime active (default) and, if needed, enable `HSLAUNCHER_MENU_BUILDER=1` to compare menu-builder output.
- Smoke core workflows:
  - Hyper tap → leader root menu (clipboard capture, overlay rendering).
  - Legacy leader sequences (window mode, search palette, external tools).
  - Hotkey assignments for representative modules (Applications launcher, window management, text utilities).
- Confirm modal overlay fidelity (layout presets, exit keys, chord indicators) against legacy behavior.
- Inspect logs (`logs/log.txt`) for diagnostics, conflict reports, and runtime warnings.
- Confirm disabling menu-builder or other feature flags fails fast with clear diagnostics now that the legacy runtime fallback has been removed.

## Observability & Tooling

- Ensure `HotkeyManifest` captures declarative registrations; compare outputs produced under both runtimes.
- Add explicit log markers when declarative runtime initializes, registers hotkeys, or encounters recoverable errors.
- Keep `tests/test_startup_failure.lua` in the default test matrix so startup regressions surface immediately during CI.
- Consider a temporary CLI (`hs hsLauncher.main.tools.runtime_check run`) that reports parity metrics (registered hotkey counts, menu counts, unresolved actions).

## Exit Criteria

- Automated suite passing with declarative runtime enabled.
- Manual parity checklist signed off and documented in `HANDOFF.md` session notes.
- No outstanding direct imports of legacy modules outside shim layer.
- Decision recorded to remove legacy fallbacks and delete archived backup modules in a subsequent phase.

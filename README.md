# hsLauncher Configuration

Personal Hammerspoon setup built around the `hsLauncher` spoon. Phase 1 of the launcher redesign delivered a validated config loader and tests while keeping the legacy `userActions` bridge in place for runtime behaviour. This README explains how to work inside that transition state and hints at the declarative workflow the loader unlocks.

## Repository Map

- `Spoons/hsLauncher.spoon/main/init.lua` – spoon entry point invoked by `init.lua` at repo root.
- `Spoons/hsLauncher.spoon/main/user/config.lua` – enables menu contexts, sets leader layout defaults, and turns hotkey contexts on or off.
- `Spoons/hsLauncher.spoon/main/user/userActions.lua` – temporary source of truth for actions, leader metadata, and hotkey specs until the declarative pipeline ships.
- `Spoons/hsLauncher.spoon/main/user/modules/` – context-specific action helpers invoked by `userActions.lua`.
- `Spoons/hsLauncher.spoon/main/user/menus/*.lua` & `.../hotkeys/*.lua` – thin wrappers that expose context data (`return UserActions.menu('<context>')`).
- `Spoons/hsLauncher.spoon/main/user/actions.lua` & `menus.lua` – declarative stubs validated by the new loader; populated in Phase 2.
- `Spoons/hsLauncher.spoon/tests/` – regression coverage for the loader and leader registry.
- `logs/` – runtime logs and config diagnostics written by the spoon.

## Working in the Bridge (Phase 1)

1. Edit contexts in `main/user/userActions.lua`. Each builder (`buildApplicationsContext`, etc.) defines:
   - `actions`: map of `id -> ModuleActions.*(...)` describing execution.
   - Optional `leader` metadata: root entries, grouped entries, extras, and ordering.
   - Optional `hotkeys`: Hyper bindings, modal layouts, sequences, or per-app bindings.
2. Touch accompanying module files in `main/user/modules/` if you need new helpers or richer action metadata.
3. Keep wrapper files under `main/user/menus/` and `main/user/hotkeys/` untouched—they simply proxy the registry output and will be replaced once the generator is active.

Leader menu ordering and visibility are controlled through `config.lua` (`menus = {...}`) and each context’s `leader` spec. Hotkey contexts are enabled by listing them under `hotkeys.contexts` in the same config file.

## Declarative Schema (Phase 1 Output)

`main/core/config_loader.lua` now loads and validates `main/user/actions.lua` and `main/user/menus.lua`. Even though runtime still relies on the bridge, you can start modelling data in those files to exercise the schema and tests. Highlights:

- Actions support execution steps, rich hotkey definitions (including chords/sequences), per-menu overrides, guards, tags, and error strategies.
- Menus describe hierarchy, root membership, policy filters, and sort hints.
- Cross-reference validation ensures `menuDetails.inMenu` entries point at real menus (or `globalRoot`).
- Loader output is deeply copied before use, so helpers can freely mutate original tables.

Run `lua tests/test_config_loader.lua` whenever you update the declarative files to confirm schema compliance.

## Runtime Validation & Tests

- `lua tests/test_config_loader.lua` – validates declarative action/menu tables, duplicate detection, multikey safeguards, and cross-references.
- `lua tests/test_leader_registry.lua` – exercises the refactored registry, ensuring root shortcuts and modal metadata are exposed.
- Reload Hammerspoon (`hs.reload()`) after edits; watch `logs/reloadLog.txt` and `logs/log.txt` for loader notices and watcher output.

Upcoming phases will add dedicated menu and hotkey tests alongside a `Validate Config` command; placeholders already exist in the handoff notes for when those suites land.

## Roadmap Snapshot

| Phase | Focus | Status |
| --- | --- | --- |
| Phase 1 | Config loader + schema validation | ✅ Complete |
| Phase 2 | Menu generator fed by loader output | 🚧 In design |
| Phase 3 | Hotkey engine sourced from loader data | 🔜 |
| Phase 4 | Diagnostics workflow (`Validate Config`) | 🔜 |

Until Phase 2 ships, continue maintaining `userActions.lua` and related modules. Populate the declarative files in parallel so the transition is a import swap instead of a rewrite.

## Getting Started

1. Install Hammerspoon and clone this repo into `~/.hammerspoon`.
2. Launch Hammerspoon; `init.lua` loads the spoon, starts SafeLoad, and registers reload watchers.
3. Trigger leader (`hyper` → `space`) or hotkey sequences to verify runtime behaviour.
4. When you change contexts or modules, reload Hammerspoon and run the relevant tests listed above.

## License

MIT for personal configuration; individual spoons retain their upstream licenses.

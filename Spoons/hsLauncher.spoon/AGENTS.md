# AGENTS.md – hsLauncher

This document is the **source of truth** for AI agents (Codex, Devin, GPT Assistants, etc.) and human contributors working with **hsLauncher**.

---

## 0. Mission Statement

**hsLauncher** is a modular Hammerspoon suite enabling end-users to assign hotkeys, modals, and automation agents with minimal effort.  

Core principles:  
1. **SIMPLE!!!!** - Users should only have to add/remove/modify one entry in one file to add a hotkey or option in a modal. If they need to add new logic, that is a separate issue.
2. **Extensible** – Users add functionality without touching core logic.  
3. **Safe** – Core files are never corrupted; user edits are isolated.  
4. **Maintainable** – Shared logic lives in reusable libraries.

---

## 1. Directory Layout (TL;DR)

hsLauncher/
├── AGENTS.md
├── README.md
├── HANDOFF.md             ← Always update at the start of a tast and once it is complete. Always use a timestamp.
├── docs/
├── logs/
├── main/
│   ├── init.lua
│   ├── core/              ← Do not edit once project is implemented
│   ├── modules/           ← Location for user extensions/modules
│   ├── tools/
│       ├── actions.lua   ← Declarative source of truth for all user-specified actions and hotkeys, and their associated menus. Extensible via include/requirements by the user.
│       └── menus.lua     ← Declarative source of truth for relationships between menus 
└── tests/

**Rule of thumb:**

- `main/core/` can be overwritten by upstream updates.
- `main/user/` is the sandbox for local customization.

---

## 2. Core instructions

- Work doggedly. Your goal is to be autonomous as long as possible. If you know the user's overall goal, and there is still progress you can make towards that goal, continue working until you can no longer make progress. Whenever you stop working, be prepared to justify why.

- Work smart. When debugging, take a step back and think deeply about what might be going wrong. When something is not working as intended, add logging to check your assumptions.

- Check your work. If you write a chunk of code, try to find a way to run it and make sure it does what you expect. If you kick off a long process, wait 30 seconds then check the logs to make sure it is running as expected.

- Be cautious with terminal commands. Before every terminal command, consider carefully whether it can be expected to exit on its own, or if it will run indefinitely (e.g. launching a web server). For processes that run indefinitely, always launch them in a new process (e.g. nohup). Similarly, if you have a script to do something, make sure the script has similar protections against running indefinitely before you run it.


---

## 3. Naming Conventions

- Use `snake_case.lua` (for example, `toggle_dark_mode.lua`).
- Match the returned table name to the filename for clarity.

---

## 4. Workflow for Codex

- Update HANDOFF.md at the start of a phase, identifying the upcoming task, the files to be added/removed/edited, and the purpose of the changes.
- Update HANDOFF.md at the end of a phase or upon successful implementation of a feature, identifying the task completed, files added/removed/edited, and the reason for the changes.
- Update HANDOFF.md before the end of a session, documenting new features and incomplete or upcoming tasks or project goals. 
- Update README.md whenever you begin adding a new feature or module (marking it as 'IMPLEMENTING', and when you complete adding the new feature ('COMPLETE')

---

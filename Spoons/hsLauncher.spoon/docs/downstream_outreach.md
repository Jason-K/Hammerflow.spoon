# Downstream Tooling Outreach

## Purpose

Coordinate with automation consumers before removing the archived `hsLauncher.main.core.hyper_*` shims and enabling the declarative menu builder by default.

## Consumer Inventory Template

| Consumer | Owner(s) | Contact | Known Usage | Status | Notes |
| --- | --- | --- | --- | --- | --- |
| Example: Internal CLI tooling | [jason@example.com](mailto:jason@example.com) | Slack `#hslauncher-dev` | Imports `hsLauncher.main.core.hyper_modal` | Pending outreach | Confirm declarative runtime compatibility |

Populate each row as outreach progresses. Include downstream repos, scripts, or partner automations that might require changes.

## Code Scan Checklist

Run the following search in each downstream repository to surface legacy hyper module imports:

```bash
rg "hsLauncher.main.core.hyper_" --glob "*.lua"
```

If the repository uses another language, adjust the `--glob` filter accordingly. Record findings in the inventory table.

## Announcement Template

```text
Subject: hsLauncher declarative menus going default

Hi <team>,

We are preparing to enable the declarative menu builder by default and remove the `hsLauncher.main.core.hyper_*` shims. Please verify that your automation works against the declarative startup path before <target date>.

Key diagnostics:
- Run `lua tests/test_startup_failure.lua` to confirm startup failures surface correctly.
- Check `logs/log.txt` for `[config]`/`[runtime]` entries if declarative startup fails.
- Review docs/architecture.md and docs/declarative_parity_plan.md for the runtime layering expectations.

Let us know if you still rely on the archived hyper modules or need assistance migrating. We plan to remove the shims once all downstream consumers confirm readiness.

Thanks,
<your name>
```

## Response Log Template

| Consumer | Date Contacted | Response | Follow-up | Ready for Shim Removal? |
| --- | --- | --- | --- | --- |
| Example: Internal CLI tooling | 2025-10-07 | Pending | Follow up on 2025-10-10 | No |

Update this table as confirmations arrive. Once every consumer reports readiness, schedule the shim removal and menu builder default flip.

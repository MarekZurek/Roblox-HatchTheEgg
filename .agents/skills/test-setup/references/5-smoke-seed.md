# /test-setup — Phase 5: Create Smoke Test Seed

## Roblox smoke seed

For Roblox write into the existing tests/<suite>/run.luau convention and register the suite, rather than creating Godot/Unity/Unreal assets. Derive observations from approved criteria, with independent expected-result provenance. For a bug seed show a valid FAIL on the unfixed behavior or isolated semantic fault and PASS on the fix; never substitute an import failure. Keep native UI/replication/Studio checks in a separate evidence scope. Read docs/workflow/ROBLOX_TESTING_CONTRACT.md.


> Part of `/test-setup`. `SKILL.md` names when to read this file; the settings it
> resolved and the rules under its later headings still apply here.

## Phase 5: Create Smoke Test Seed

Create `tests/smoke/critical-paths.md`:

```markdown
# Smoke Test: Critical Paths

**Purpose**: Run these 10-15 checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries when new core systems are implemented.

## Core Stability (always run)

1. Game launches to main menu without crash
2. New game / session can be started from the main menu
3. Main menu responds to all inputs without freezing

## Core Mechanic (update per sprint)

<!-- Add the primary mechanic for each sprint here as it is implemented -->
<!-- Example: "Player can move, jump, and the camera follows correctly" -->
4. [Primary mechanic — update when first core system is implemented]

## Data Integrity

5. Save game completes without error (once save system is implemented)
6. Load game restores correct state (once load system is implemented)

## Performance

7. No visible frame rate drops on target hardware (60fps target)
8. No memory growth over 5 minutes of play (once core loop is implemented)
```

---

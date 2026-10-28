# Claude Code Game Studios — Roblox Game Studio Architecture (HatchTheEgg)

Professional Roblox game development managed through coordinated AI subagents and domain specialists.
Each agent owns a specific domain, enforcing separation of concerns, engine best practices, and code quality.

## Technology Stack

- **Engine**: Roblox (Studio 2026 / DataModel runtime)
- **Language**: Luau (strict mode `--!strict`)
- **Sync & Build**: Rojo 7.x (`default.project.json` -> `HatchTheEgg.rbxlx`)
- **Test Runner & Headless Runtime**: Lune 0.8.x + Custom test suites (`tools/test.ps1`)
- **Client/Server Structure**: `src/server`, `src/client`, `src/shared`
- **Data Persistence**: DataStoreService with session-locking and schema versioning
- **Replication**: Server-authoritative RemoteEvents and UnreliableRemoteEvents

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/roblox/VERSION.md

## Technical Preferences

`project.yaml` at the repo root is the primary config store — engine, specialists,
naming, platform, performance, modes. Skills resolve it via `resolve_config`
(see `.claude/docs/config-resolution.md`).

Key project specs and contracts:
- [CURRENT_SPEC](docs/CURRENT_SPEC.md) — gameplay contracts, status flags (N/S/R/P/H).
- [WORKING_CONTEXT](docs/WORKING_CONTEXT.md) — active implementation state and boundaries.
- [TODO](docs/TODO.md) — backlog tasks and deferred decisions.
- [Numbers & Player State Contract](docs/27_numbers_time_and_player_state_contract.md) — time, units, numerical precision.
- [Modules & Client-Server Contract](docs/28_modules_and_client_server_contract.md) — service boundaries and network protocol.

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
  (exempt: `active.md` appends, agent memory, a subagent's new file at the path
  its orchestrating skill named; see `.claude/rules/agent-memory.md`)
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction
- A skipped or dismissed question is not an answer: act on nothing, re-ask in
  plain text and wait
- Respect project boundaries: never unfreeze deferred balance docs (`docs/17`–`21`)
  without explicit user authorization.

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

Read `.claude/docs/context-management.md` on demand — it is a reference, not
session context:

- **`production/session-state/active.md` is the session checkpoint.** The file is
  the memory, not the conversation. Read it first after any compaction, crash, or
  `/clear`.
- **Helpers in `.claude/scripts/` emit observations, never verdicts.**

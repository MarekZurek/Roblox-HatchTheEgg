# Antigravity & Agent Studio Constitution — Roblox (HatchTheEgg)

Professional Roblox game development managed through coordinated AI agents, studio workflows, and specialized domain roles.

## Technology Stack

- **Engine**: Roblox (Studio 2026 / DataModel runtime)
- **Language**: Luau (strict mode `--!strict` enforced)
- **Toolchain & Sync**: Rojo 7.x (`default.project.json` -> `HatchTheEgg.rbxlx`)
- **Testing & Headless Runtime**: Lune 0.8.x + Custom test suites (`tools/test.ps1`)
- **Code Organization**:
  - `src/server` -> `ServerScriptService` (Authoritative game logic, persistence, security)
  - `src/client` -> `StarterPlayerScripts` / `StarterGui` (UI, client prediction, camera)
  - `src/shared` -> `ReplicatedStorage` (Shared math, types, codecs, action catalog)
- **Data Persistence**: DataStoreService with session-locking (ProfileService pattern) and schema versioning
- **Replication**: Server-authoritative RemoteEvents and UnreliableRemoteEvents

## Studio Roles & Hierarchy

Custom agent definitions live in [`.agents/agents/`](.agents/agents/):
- **Technical Director & Roblox Engine Lead**: [`.agents/agents/roblox-specialist.md`](.agents/agents/roblox-specialist.md)
- **Luau Language Specialist**: [`.agents/agents/roblox-luau-specialist.md`](.agents/agents/roblox-luau-specialist.md)
- **Network & Anti-Exploit Specialist**: [`.agents/agents/roblox-network-specialist.md`](.agents/agents/roblox-network-specialist.md)
- **DataStore & Persistence Specialist**: [`.agents/agents/roblox-datastore-specialist.md`](.agents/agents/roblox-datastore-specialist.md)
- **Roblox UI & Mobile Specialist**: [`.agents/agents/roblox-ui-specialist.md`](.agents/agents/roblox-ui-specialist.md)
- **Toolchain & CI Specialist**: [`.agents/agents/roblox-toolchain-specialist.md`](.agents/agents/roblox-toolchain-specialist.md)
- Full multi-discipline studio: Game Designer, Economy Designer, Systems Designer, QA Lead, Producer, etc.

## Engine Reference & Best Practices

Always consult the pinned engine documentation in [`docs/engine-reference/roblox/`](docs/engine-reference/roblox/):
- [VERSION.md](docs/engine-reference/roblox/VERSION.md) — Studio 2026, Luau 0.600+, Rojo 7.4.4, Lune 0.8.9.
- [current-best-practices.md](docs/engine-reference/roblox/current-best-practices.md) — Server authority, session locking, zero allocation loops, Maid/Janitor patterns.
- [breaking-changes.md](docs/engine-reference/roblox/breaking-changes.md) — Deferred signal behavior, Luau 2.0 type solver, audio wires.
- [deprecated-apis.md](docs/engine-reference/roblox/deprecated-apis.md) — Forbidden legacy APIs (`wait`, `spawn`, `delay`, BodyMovers, FindPartOnRay).

## Studio Rules & Coding Standards

Discovered automatically by Antigravity in [`.agents/rules/`](.agents/rules/):
- `engine-code.md` — Zero allocations in hot loops, Luau table pooling, RunService optimization.
- `network-code.md` — Server authority, player parameter validation, UnreliableRemoteEvent usage, rate limiting.
- `ui-code.md` — Mobile-first (>50% mobile), UDim2 Scale, UIAspectRatioConstraint, Safe Area insets.
- `scene-files.md` — Rojo `.project.json`, `.rbxlx` XML conventions, prohibition of raw text edits on binary `.rbxl`/`.rbxm`.
- `test-standards.md` — TestEZ / Lune test patterns and Arrange/Act/Assert structure.
- `gameplay-code.md` — External configuration values, delta time, strict module interfaces.

## Active Project Specs & Contracts

- [CURRENT_SPEC](docs/CURRENT_SPEC.md) — Gameplay contracts and status flags.
- [WORKING_CONTEXT](docs/WORKING_CONTEXT.md) — Active context and implementation boundaries.
- [TODO](docs/TODO.md) — Task backlog and deferred decisions.
- [27 — Numbers, Time & Player State Contract](docs/27_numbers_time_and_player_state_contract.md)
- [28 — Modules & Client-Server Contract](docs/28_modules_and_client_server_contract.md)
- **Deferred Balance Boundaries**: Never unfreeze or modify deferred balance files (`docs/17`–`21`) without explicit user instruction.

## Collaboration Protocol

- Always propose architecture and file changes before applying.
- Ask for confirmation before major edits.
- Never spawn runaway background processes or recursive command loops.

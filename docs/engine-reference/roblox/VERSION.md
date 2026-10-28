# Roblox Engine & Luau — Version Reference

| Field | Value |
|-------|-------|
| **Engine Version** | Roblox Studio 2026 (Live Engine & DataModel API) |
| **Installed Toolchain** | Rojo 7.4.4, Lune 0.8.9, Python 3.x harness |
| **Language Runtime** | Luau 0.600+ (Strict Type Solver, Native Code Gen support) |
| **Project Pinned** | 2026-10-27 |
| **Last Docs Verified** | 2026-10-27 |
| **LLM Knowledge Cutoff** | May 2025 |

## Knowledge Gap Warning

The LLM's baseline knowledge often conflates legacy Roblox Lua 5.1 with modern **Luau**.
Crucial advancements in modern Luau and Roblox Studio that MUST be respected:
- Strict typing (`--!strict`) with complete type inference, type packs, generic functions, and `export type`.
- Deprecation of legacy global routines (`spawn`, `delay`, `wait`) in favor of the `task` library (`task.spawn`, `task.defer`, `task.delay`, `task.wait`, `task.cancel`).
- Parallel Luau execution model (`task.desynchronize()`, `task.synchronize()`, Actor model, SharedTable).
- Modern networking: `UnreliableRemoteEvent` alongside `RemoteEvent`, Strict Player validation on server events.
- Audio API overhaul: `AudioPlayer`, `AudioEmitter`, `AudioListener`, wire-based routing.
- Modern Constraint Physics replacing legacy BodyMovers.
- Session-locked DataStores (ProfileService pattern) to prevent item/currency duplication across server boundaries.

## Engine & Toolchain Stack

| Component | Standard | Purpose |
|-----------|----------|---------|
| **Rojo** | 7.4.x | Syncs filesystem (`src/client`, `src/server`, `src/shared`) into Studio DataModel via `default.project.json` |
| **Lune** | 0.8.x | Headless standalone Luau runtime used for instant unit tests, oracles, and vector validation without launching Studio GUI |
| **DataModel Sync** | `.rbxlx` | XML place representation; edited via Rojo sync, never hand-edited concurrently with Studio |
| **Linting** | Selene | Static code analysis and Luau linting |
| **Formatting** | StyLua | Enforces standard Luau code style (indentation, operators, quotes) |

## Target Platforms & Inputs

- **Mobile (iOS / Android)**: Primary player base (>50%). Touch input with Dynamic Thumbstick and TouchTap, responsive UI scaling with Safe Area insets.
- **PC (Windows / Mac)**: Mouse & Keyboard, scalable window resolutions.
- **Console (Xbox / PlayStation)**: Gamepad navigation with GuiService and ContextActionService.

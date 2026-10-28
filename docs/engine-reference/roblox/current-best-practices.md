# Roblox — Current Best Practices

Last verified: 2026-10-27 | Engine: Roblox Studio 2026 / Luau 0.600+

Best practices and architectural standards for professional Roblox development.

---

## 1. Strict Luau & Module Architecture

### File Mode & Types
- Always place `--!strict` at the very first line of every Luau script.
- Export all interface and data types using `export type Typename = { ... }`.
- Prefer immutable data shapes where possible.
- Use explicit return types on public module methods.

```luau
--!strict
local MyService = {}
MyService.__index = MyService

export type ServiceConfig = {
    tickRate: number,
    debugMode: boolean,
}

function MyService.new(config: ServiceConfig): MyService
    local self = setmetatable({}, MyService)
    self.config = config
    return self
end

export type MyService = typeof(MyService.new(...))
return MyService
```

### Module Separation
- `src/server`: Server-only execution. Runs in `ServerScriptService`. Handles database, economy authority, validation, security.
- `src/client`: Client-only execution. Runs in `StarterPlayerScripts` / `StarterGui`. Handles rendering, input, predictive UI, camera.
- `src/shared`: Replicated code placed in `ReplicatedStorage`. Pure math, data definitions, serialization codecs, shared contracts.

---

## 2. Server Authority & Anti-Exploit Security

- **Never Trust the Client**:
  The client can forge any packet, modify local variables, change camera or walkspeed, and spam RemoteEvents.
- **Client Identity**:
  The first argument of `RemoteEvent.OnServerEvent` is always the authenticated `player: Player`. Never pass a Player parameter inside the payload.
- **Payload Validation**:
  Validate every parameter passed over remotes (types, ranges, NaN checks, array length limits).
- **Rate Limiting**:
  Track request timestamps per player to prevent remote spamming / server denial of service.
- **UnreliableRemoteEvent**:
  Use `UnreliableRemoteEvent` for ephemeral, high-frequency, non-critical data (e.g. particle trigger positions, footstep sounds, cosmetic drone trails). Use `RemoteEvent` for state transactions.

---

## 3. DataStore & Persistence Integrity

- **Session Locking (ProfileService pattern)**:
  Never read and write data without an active session lock. If a player leaves Server A and joins Server B before Server A has finished saving, session locking prevents data overwrite and item duping.
- **DataStore Budgets**:
  Monitor `DataStoreService:GetRequestBudgetForRequestType()`. Never write in high-frequency loops. Batch mutations in memory and flush on periodic autosave (e.g., every 3-5 minutes) or `PlayerRemoving` / `BindToClose`.
- **Game Closure Protection**:
  Always register `game:BindToClose()` to flush and unlock all active player sessions when servers shut down.
- **Schema Versioning & Migrations**:
  Include a `schemaVersion: number` in player data. Write forward-migrators that transform older schema versions into current structures.

---

## 4. RunService, Performance & Zero Allocations

- **Loop Selection**:
  - `RunService.RenderStepped`: Client ONLY. For camera updates and pre-render visuals. Never do gameplay or physics here.
  - `RunService.Stepped`: Pre-physics step. Useful client/server for custom collision or constraints.
  - `RunService.Heartbeat`: Post-physics step. Standard game logic tick.
- **Zero Allocations in Hot Paths**:
  Avoid creating new tables, closures, or Vector3 instances inside `Heartbeat` loops.
  Reuse tables using `table.clear()` and pre-allocate with `table.create(capacity)`.
- **Parallel Luau**:
  Use Actors (`task.desynchronize()` / `task.synchronize()`) for heavy batch computations (e.g., procedural world generation, pathfinding grids, large flocking math).

---

## 5. Memory Management & Lifecycle Cleanup

- **RBXScriptConnection Leaks**:
  Any connection (`:Connect()`) to an instance that outlives the script will leak memory if not explicitly disconnected (`:Disconnect()`).
- **Maid / Janitor / Trove Pattern**:
  Store cleanup tasks, instances, and connections inside a cleanup manager:
  ```luau
  local maid = Maid.new()
  maid:GiveTask(part.Touched:Connect(onTouched))
  maid:GiveTask(tempInstance)
  -- On cleanup:
  maid:Destroy()
  ```

---

## 6. Responsive UI & Cross-Platform Ergonomics

- **AnchorPoint & Positioning**:
  Use `AnchorPoint = Vector2.new(0.5, 0.5)` for centered UI cards and popups.
- **Scale over Offset**:
  Use UDim2 with `Scale` for responsive sizing across different screen aspect ratios (phones, tablets, PCs).
- **UIAspectRatioConstraint**:
  Attach `UIAspectRatioConstraint` to preserve square or card proportions without stretching.
- **Safe Area Insets**:
  Mobile devices with notches require safe area offsets. Respect `GuiService:GetGuiInset()` or modern ScreenGui safe area clipping.
- **ContextActionService**:
  Bind actions using `ContextActionService:BindAction()` to automatically handle Touch buttons on mobile, keyboard keys on PC, and gamepad buttons on console.

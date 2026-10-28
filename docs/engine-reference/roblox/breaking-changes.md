# Roblox — Breaking Changes & Engine Evolution

Last verified: 2026-10-27 | Engine: Roblox Studio 2026

Critical runtime behavioral changes that differ from older Roblox engine versions and legacy tutorials.

---

## 1. Deferred Signal Behavior

- **Historical behavior**: `Workspace.SignalBehavior = Immediate` ran event listeners synchronously during property changes or method calls.
- **Current standard**: `Workspace.SignalBehavior = Deferred` is the default in modern experiences.
- **Impact**:
  - Event callbacks do not execute immediately when an event fires. Instead, they are enqueued and executed at designated resumption points in the task scheduler.
  - Code relying on synchronous side effects (e.g., setting a property, firing a bindable, and expecting an immediate update within the same stack frame) will fail.
  - Yielding inside event handlers now properly isolates caller state.

---

## 2. Luau Type Engine Rework (Type Solver 2.0)

- Stricter checking on table shapes, metatable indexing, and sealed table types.
- Unsealed tables inferred incrementally inside their scope; attempting to add new properties outside creation scope requires explicit typing:
  ```luau
  -- CORRECT: Explicit interface definition
  type PlayerState = {
      cash: number,
      farmLevel: number?,
  }
  local state: PlayerState = { cash = 0 }
  state.farmLevel = 1 -- Allowed because optional in type definition
  ```
- Stricter return type enforcement for overloaded functions and generics.

---

## 3. Modern Audio System (AudioPlayer / AudioEmitter)

- Legacy `Sound` instances parented to parts or SoundService are superseded by the modern Audio API (`AudioPlayer`, `AudioEmitter`, `AudioListener`, `Wire`).
- Wire routing allows flexible DSP effects (reverb, equalization, spatial falloff) without duplicating sound assets.

---

## 4. TextChatService Migration

- Legacy `Chat` service methods and `ChatServiceRunner` in ServerScriptService are deprecated.
- Experiences use `TextChatService` with `TextChannel` instances, rich text formatting, and modern client UI integration.

# Roblox — Deprecated & Forbidden APIs

Last verified: 2026-10-27 | Engine: Roblox Studio 2026

The following APIs are deprecated, obsolete, or prohibited in modern Luau and Roblox production code.

---

## 1. Threading & Scheduling

| Deprecated / Forbidden | Modern Replacement | Rationale |
|------------------------|--------------------|-----------|
| `wait(n)` | `task.wait(n)` | `wait()` throttles to 30Hz minimum (minimum ~0.03s delay) and drifts under load. `task.wait()` runs on TaskScheduler at frame rate (60Hz / 120Hz+). |
| `spawn(fn)` | `task.spawn(fn)` | `spawn()` introduces an unnecessary 1-2 frame delay. `task.spawn()` runs immediately in the current frame resumption point. |
| `delay(n, fn)` | `task.delay(n, fn)` | `delay()` suffers from legacy 30Hz throttle. `task.delay()` is precise. |
| `coroutine.resume(co)` without error check | `task.spawn(co)` or check `pcall` | Unhandled errors in resumed coroutines can silently swallow stack traces. |

---

## 2. Spatial Queries & Raycasting

| Deprecated / Forbidden | Modern Replacement | Rationale |
|------------------------|--------------------|-----------|
| `workspace:FindPartOnRay(ray, ignore)` | `workspace:Raycast(origin, direction, RaycastParams)` | `FindPartOnRay` does not support collision groups, tag filtering, or flexible ignore lists. |
| `workspace:FindPartsInRegion3(...)` | `workspace:GetPartBoundsInBox(...)` | Region3 queries are axis-aligned only and allocate heavily. |
| `workspace:FindPartsInRegion3WithWhiteList` | `workspace:GetPartBoundsInRadius(...)` | Replaced by SpatialQuery API with `OverlapParams`. |

---

## 3. Physics & Movement

| Deprecated / Forbidden | Modern Replacement | Rationale |
|------------------------|--------------------|-----------|
| `BodyPosition` | `AlignPosition` | Legacy BodyMovers are deprecated and do not integrate cleanly with PGS physics solver. |
| `BodyVelocity` | `LinearVelocity` | LinearVelocity supports world/relative axes and precise constraint force limits. |
| `BodyGyro` | `AlignOrientation` | AlignOrientation uses modern dual-attachment orientation math. |
| `BodyForce` | `VectorForce` | VectorForce provides deterministic force application. |

---

## 4. Animation & Audio

| Deprecated / Forbidden | Modern Replacement | Rationale |
|------------------------|--------------------|-----------|
| `Humanoid:LoadAnimation(anim)` | `Animator:LoadAnimation(anim)` | Loading animations on Humanoid directly causes replication anomalies and is deprecated. |
| `AnimationController:LoadAnimation(anim)` | `Animator:LoadAnimation(anim)` | Must load through an `Animator` child instance. |

---

## 5. Input & Client Services

| Deprecated / Forbidden | Modern Replacement | Rationale |
|------------------------|--------------------|-----------|
| `Player:GetMouse()` (`mouse.Hit`, `mouse.Target`) | `UserInputService` + `workspace:Raycast()` | `Mouse` object provides imprecise legacy raycasting and lacks touch/gamepad multi-input support. |
| Direct `UserInputService.InputBegan` for gameplay | `ContextActionService:BindAction()` | `ContextActionService` supports platform priority, mobile on-screen buttons, and clean unbinding. |

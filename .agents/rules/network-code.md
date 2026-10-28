---
paths:
  - "src/networking/**"
  - "src/server/**"
  - "src/client/**"
  - "src/shared/network/**"
  - "src/shared/protocol/**"
  - "Assets/**/{Networking,networking,Network,network}/**/*.cs"
  - "Source/**/{Networking,networking,Network,network}/**/*.{h,cpp}"
---

# Network Code Rules

- Server is AUTHORITATIVE for all gameplay-critical state — never trust the client
- All network messages must be versioned for forward/backward compatibility
- Client predicts locally, reconciles with server — implement rollback for mispredictions
- Handle disconnection, reconnection, and host migration gracefully
- Rate-limit all network logging to prevent log flooding
- All networked values must specify replication strategy: reliable/unreliable, frequency, interpolation
- Bandwidth budget: define and track per-message-type bandwidth usage
- Security: validate all incoming packet sizes, field ranges, and player authorization

## Roblox Specific Rules
- In `RemoteEvent.OnServerEvent`, the first argument `player: Player` is engine-provided; NEVER accept a caller-provided player identity in payload.
- Use `UnreliableRemoteEvent` for non-critical, high-frequency stream signals (cosmetics, effects, visual indicators).
- NEVER call `RemoteFunction:InvokeClient` from server (an exploiter or lagged client can freeze the server thread). Use `RemoteEvent` pairs instead.
- Validate every argument type and check for NaN or infinite numbers before processing.

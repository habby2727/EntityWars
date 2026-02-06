# Integration Notes

## Autoloads (optional)
- No autoloads are required for this integration.
- Optional autoloads if you want global access:
  - `SceneRouter` (for scene navigation helpers)
  - `StaticDB` (if you prefer a single shared instance)
  - `AssetCatalog` (if you prefer a single shared instance)

## MainMenu Navigation Bridge (optional)
- If MainMenu button paths change, attach `scripts/ui/menu_bridge.gd` to the MainMenu root.
- It finds buttons by exported NodePaths or button text ("Lab" / "Inventory" / "Combat").

## Backend
- From `backend/`:
  - `bun run dev` (starts on `0.0.0.0:8787`)
  - `bun run build` / `bun run start` for production-like build
- Smoke test:
  - `bun backend/src/tests/smoke.ts`

## Backend URL in Godot
- `scripts/net/backend_client.gd` exposes `base_url` as an exported property.
- You can set it per `BackendClient` node in a scene, or change the default in the script.

## Self-Check Tests (Godot)
- Script: `scripts/tests/self_check.gd`
- Add it to any scene (e.g., a debug node) and call:
  - `SelfCheck.run_all()`
- Checks:
  - StaticDB validation
  - AssetCatalog required textures
  - Lab/Inventory scene load
  - Backend `/static/version` reachability
  - Action idempotency + wallet sanity

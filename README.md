# ArmouredTycoon

## Toolchain

Install the versions pinned in `rokit.toml` with `rokit install`. Rokit is the project toolchain manager.

The root Wally manifest lists direct dependencies. `wally install` regenerates the package tree; keep `wally.lock` with the manifest when dependencies change.

## Build and checks

```powershell
rojo build default.project.json -o ArmouredTycoon.rbxlx
selene src/ServerScriptService/Services/Networking/NetworkGuard.luau src/ServerScriptService/Services/Commerce/CommerceService.luau src/StarterPlayer/StarterPlayerScripts/InventoryClient/Controller.luau
```

Open the built place in Roblox Studio for multiplayer and purchase flow testing. The local CLI build verifies the Rojo tree, but does not run Roblox services or DataStores.
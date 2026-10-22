# ArmouredTycoon

## Toolchain

Install the versions pinned in `rokit.toml` with `rokit install`. Rokit is the project toolchain manager.

The root Wally manifest lists direct dependencies. `wally install` regenerates the package tree; keep `wally.lock` with the manifest when dependencies change.

## Build and checks

Install the pinned tools with rokit install, then run the repository verification script:

    rokit install
    .\tools\verify.ps1

The script builds the place with the pinned Rojo version and checks patch whitespace. Rojo is the syntax gate because the pinned Selene release does not parse Luau `const` declarations. The same checks run in .github/workflows/ci.yml.

For a build only:

    rojo build default.project.json -o ArmouredTycoon.rbxlx
Open the built place in Roblox Studio for multiplayer and purchase flow testing. The local CLI build verifies the Rojo tree, but does not run Roblox services or DataStores.
$ErrorActionPreference = "Stop"
rojo build default.project.json -o (Join-Path $env:TEMP "ArmouredTycoon.rbxlx")
# Selene 0.28 does not parse Luau const declarations; Rojo build above is the syntax gate.
git -c core.safecrlf=false diff --check

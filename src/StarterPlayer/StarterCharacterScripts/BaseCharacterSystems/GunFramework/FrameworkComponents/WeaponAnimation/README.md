# WeaponAnimation

Procedural replacement foundation for ACS weapon/viewmodel animation.

The current ACS system calls per-tool `ACS_Animations` functions that tween `Motor6D`
offsets directly. This folder introduces a layered animator so we can migrate toward:

1. Base weapon pose from `ACS_Animations`
2. Code-driven idle breathing/drift
3. Movement bob
4. Camera sway/inertia
5. Recoil spring
6. Future timeline/action layers for reload, equip, inspect, jam clear, and melee

Nothing here should require Roblox animation tracks. It outputs CFrame poses that can be
applied to the existing first-person viewmodel joints and weapon model.

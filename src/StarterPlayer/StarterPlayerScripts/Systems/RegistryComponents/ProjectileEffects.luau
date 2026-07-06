--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Runtime = require(script.Parent:WaitForChild("Runtime"))
local ProjectileVisuals = require(ReplicatedStorage.Modules:WaitForChild("ProjectileVisuals"))

type Context = {
	events: Instance,
	fx: Instance,
	hitmarker: any,
}

type WeaponData = {
	WalkMult: number?,
	RainbowMode: boolean?,
	TracerColor: Color3?,
	Tracer: boolean?,
	BulletFlare: boolean?,
	MuzzleVelocity: number?,
}

type WeaponModifierData = {
	WalkMult: number?,
	MuzzleVelocity: number?,
}

local ProjectileEffects = {}

function ProjectileEffects.start(context: Context)
	local event = Runtime.getRemoteEvent(context.events, "ServerBullet")
	if not event then
		return
	end

	event.OnClientEvent:Connect(function(player: Player, origin: Vector3, direction: Vector3, weaponData: WeaponData, modifierData: WeaponModifierData)
		if player == Players.LocalPlayer or not player.Character then
			return
		end

		if weaponData.Tracer ~= true and weaponData.BulletFlare ~= true then
			return
		end

		ProjectileVisuals.spawnTracer(origin, direction, {
			parent = Runtime.getEffectsFolder(),
			weaponData = weaponData,
			velocityScale = Runtime.getNumber(modifierData.MuzzleVelocity, 1),
			width = 0.05,
		})
	end)
end

return ProjectileEffects

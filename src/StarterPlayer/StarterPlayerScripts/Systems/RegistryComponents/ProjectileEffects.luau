--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Runtime = require(script.Parent:WaitForChild("Runtime"))
local ProjectileVisuals = require(ReplicatedStorage.Modules:WaitForChild("ProjectileVisuals"))
local PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)
local Packets = PacketBootstrap.Get()

local ProjectileEffects = {}

function ProjectileEffects.start(_context: any)
	Packets.packets.ProjectilePresentation.listen(function(data)
		local player = Players:GetPlayerByUserId(data.shooterUserId)
		if not player or player == Players.LocalPlayer or not player.Character then
			return
		end

		if data.tracer ~= true and data.bulletFlare ~= true then
			return
		end

		ProjectileVisuals.spawnTracer(data.origin, data.direction, {
			parent = Runtime.getEffectsFolder(),
			weaponData = {
				Tracer = data.tracer,
				BulletFlare = data.bulletFlare,
				TracerColor = data.tracerColor,
				MuzzleVelocity = data.muzzleVelocity,
			},
			velocityScale = Runtime.getNumber(data.muzzleVelocity, 1),
			width = 0.05,
		})
	end)
end

return ProjectileEffects

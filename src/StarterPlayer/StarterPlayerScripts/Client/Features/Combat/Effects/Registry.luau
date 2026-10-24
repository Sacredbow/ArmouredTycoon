--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterEffects = require(script.Parent:WaitForChild("CharacterEffects"))
local ProjectileEffects = require(script.Parent:WaitForChild("ProjectileEffects"))

local Registry = {}

function Registry.start()
	local engine = ReplicatedStorage:WaitForChild("ACS_Engine")
	local events = engine:WaitForChild("Events")
	local acsModules = engine:WaitForChild("Modules")
	local fx = engine:WaitForChild("FX")
	local hitmarker = require(acsModules:WaitForChild("Hitmarker"))

	local context = {
		events = events,
		fx = fx,
		hitmarker = hitmarker,
	}

	CharacterEffects.start(context)
	ProjectileEffects.start(context)
end

return Registry

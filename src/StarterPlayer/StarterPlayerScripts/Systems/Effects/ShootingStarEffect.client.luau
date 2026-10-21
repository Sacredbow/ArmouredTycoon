--!strict
--[[
	@class ShootingStarEffect

	@desc
	Client-side shooting star VFX. Listens for the ShootingStar packet
	broadcast by EnvironmentService during the night and renders the
	ShootingStar model streaking across the sky or impacting the map.
	Runs on the client so the server never pays the cost of spawning
	and animating the effect.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)
local Packets = PacketBootstrap.Get()

local ShootingStarTemplate = ReplicatedStorage.Assets["Visual Effects"]:FindFirstChild("ShootingStar")
if not ShootingStarTemplate then
	return
end

--// Constants

local STREAK_SPEED = 900 -- studs/sec across the sky
local IMPACT_SPEED = 700 -- studs/sec plunging toward the map
local STREAK_DURATION = 10 -- seconds a sky streak lasts
local MAX_IMPACT_DISTANCE = 5000 -- raycast reach to find the map

--// Helpers

local function emitBurst(star: Model)
	for _, descendant in star:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant:Emit(24)
		end
	end
end

local function spawnShootingStar(payload)
	local star = ShootingStarTemplate:Clone()
	star.Parent = Workspace

	local startPosition = payload.startPosition
	local direction = payload.direction.Unit
	local impact = payload.impact

	star:PivotTo(CFrame.lookAt(startPosition, startPosition + direction))

	local speed = if impact then IMPACT_SPEED else STREAK_SPEED
	local startedAt = os.clock()

	-- Precompute the impact point once so we don't raycast every frame.
	local impactDistance = MAX_IMPACT_DISTANCE
	if impact then
		local ray = RaycastParams.new()
		ray.FilterType = Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances = { star }
		local result = Workspace:Raycast(startPosition, direction * MAX_IMPACT_DISTANCE, ray)
		if result then
			impactDistance = result.Distance
		end
	end

	local connection: RBXScriptConnection?
	connection = RunService.RenderStepped:Connect(function()
		if not star.Parent then
			if connection then
				connection:Disconnect()
			end
			return
		end

		local traveled = speed * (os.clock() - startedAt)

		if impact and traveled >= impactDistance then
			local impactPoint = startPosition + direction * impactDistance
			star:PivotTo(CFrame.lookAt(impactPoint, impactPoint + direction))
			emitBurst(star)
			-- Keep the star alive briefly so the impact burst is visible.
			task.delay(1.5, function()
				if star.Parent then
					star:Destroy()
				end
			end)
			if connection then
				connection:Disconnect()
			end
			return
		end

		if not impact and traveled >= speed * STREAK_DURATION then
			star:Destroy()
			if connection then
				connection:Disconnect()
			end
			return
		end

		local position = startPosition + direction * traveled
		star:PivotTo(CFrame.lookAt(position, position + direction))
	end)
end

Packets.packets.ShootingStar.listen(function(payload)
	spawnShootingStar(payload)
end)

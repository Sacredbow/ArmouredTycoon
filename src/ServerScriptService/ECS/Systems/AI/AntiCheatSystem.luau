--!strict
--[[
	@class AntiCheatSystem

	Per-character anti-cheat state lives in ECS as plain counters, timestamps,
	history, and boundary Instance references. Detection behavior stays here
	instead of being captured by typed ECS lifecycle components.
]]

const ServerScriptService = game:GetService("ServerScriptService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const LoggingEvent = require(ReplicatedStorage.Packages.signal).get("ServerLogging")
const Config = require(ServerScriptService.Services.External.ServerAuthority.Utilities.Config)
const Whitelist = require(ServerScriptService.Services.External.ServerAuthority.Utilities.Whitelist)
const CheckInterval = 0.5
local function CreateCharacterRayParams(character: Model): RaycastParams
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { character }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	return rayParams
end

local function GetHorizontalSpeed(lastPosition: Vector3, currentPosition: Vector3, deltaTime: number): number
	local horizontalDelta = Vector3.new(currentPosition.X - lastPosition.X, 0, currentPosition.Z - lastPosition.Z)
	return horizontalDelta.Magnitude / deltaTime
end

local function GetHorizontalDistance(fromPosition: Vector3, toPosition: Vector3): number
	local horizontalDelta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	return horizontalDelta.Magnitude
end

local function GetHeightAboveGround(humanoidRootPart: BasePart, character: Model): number
	local result =
		workspace:Raycast(humanoidRootPart.Position, Vector3.new(0, -300, 0), CreateCharacterRayParams(character))
	if result then
		return humanoidRootPart.Position.Y - result.Position.Y
	end

	return 0
end

local function CheckNoclip(lastPosition: Vector3, currentPosition: Vector3, character: Model): boolean
	local direction = currentPosition - lastPosition
	local distance = direction.Magnitude
	if distance < Config.Noclip.MinDistance then
		return false
	end

	local unitDirection = direction.Unit
	local result = workspace:Raycast(lastPosition, unitDirection * distance, CreateCharacterRayParams(character))
	if not result or not result.Instance.CanCollide then
		return false
	end

	local hitToCurrent = currentPosition - result.Position
	if hitToCurrent.Magnitude <= Config.Noclip.SurfaceTolerance then
		return false
	end

	if hitToCurrent:Dot(unitDirection) <= Config.Noclip.ForwardTolerance then
		return false
	end

	return math.abs(result.Normal:Dot(unitDirection)) >= Config.Noclip.RequiredNormalAlignment
end

local function CheckTeleport(lastPosition: Vector3, currentPosition: Vector3): boolean
	local horizontalDistance = GetHorizontalDistance(lastPosition, currentPosition)
	local verticalDistance = math.abs(currentPosition.Y - lastPosition.Y)

	if horizontalDistance < Config.Teleport.MinDistance then
		return false
	end

	return verticalDistance <= Config.Teleport.MaxVerticalDistance
end

local function CopyPositionHistory(history: { any }): { any }
	local copiedHistory = {}
	for index, sample in history do
		copiedHistory[index] = {
			Position = sample.Position,
			Time = sample.Time,
		}
	end
	return copiedHistory
end

local function IsServerTeleportAllowed(Player: Player, Now: number): boolean
	for Entity, PlayerRef in ECS.world:query(ECS.Components.PlayerRef) do
		if PlayerRef == Player then
			const TeleportGraceExpiry = ECS.world:get(Entity, ECS.Components.TeleportGrace) or 0
			return type(TeleportGraceExpiry) == "number" and Now <= TeleportGraceExpiry
		end
	end
	return false
end

local function ResetCharacterToPosition(character: Model, humanoidRootPart: BasePart, targetPosition: Vector3)
	local targetCFrame = CFrame.new(targetPosition) * (humanoidRootPart.CFrame - humanoidRootPart.Position)
	character:PivotTo(targetCFrame)

	if Config.Teleport.ResetVelocity then
		humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
	end
end

local function BuildEvidence(state: any, currentPosition: Vector3, speed: number?, heightAboveGround: number?)
	local humanoidState = "Unknown"
	local success, stateName = pcall(function()
		return state.humanoid:GetState().Name
	end)
	if success then
		humanoidState = stateName
	end

	return {
		CurrentPosition = currentPosition,
		LastPosition = state.lastPosition,
		Speed = speed,
		HeightAboveGround = heightAboveGround,
		TeleportDistance = GetHorizontalDistance(state.lastPosition, currentPosition),
		VerticalDelta = math.abs(currentPosition.Y - state.lastPosition.Y),
		Violations = state.violations + 1,
		NoclipStrikes = state.noclipStrikes,
		TeleportStrikes = state.teleportStrikes,
		HumanoidState = humanoidState,
		PositionHistory = CopyPositionHistory(state.positionHistory),
	}
end

local function AddViolation(state: any, reason: string, evidence): boolean
	local player = state.player
	if Whitelist[player.UserId] then
		return false
	end

	state.violations += 1
	state.lastViolationTime = os.clock()
	if state.violations < 4 then
		return false
	end

	LoggingEvent:Fire(player, reason, evidence)
	player:Kick("You were caught by ServerAuthority: Anomalous Behaviour Detected.")
	return true
end

local function RunCheck(state: any): boolean
	local character = state.character
	local player = state.player
	local humanoid = state.humanoid
	local humanoidRootPart = state.humanoidRootPart

	if not player.Parent or not character.Parent or not humanoid.Parent or not humanoidRootPart.Parent then
		return false
	end

	local now = os.clock()
	if now < state.cooldownUntil then
		return true
	end

	local currentPosition = humanoidRootPart.Position
	local delta = now - state.lastInputTime
	if delta <= 0 then
		return true
	end

	table.insert(state.positionHistory, {
		Position = currentPosition,
		Time = math.round(now * 100) / 100,
	})
	if #state.positionHistory > 6 then
		table.remove(state.positionHistory, 1)
	end

	if now - state.lastViolationTime > Config.ViolationDecayTime then
		state.violations = math.max(0, state.violations - 1)
	end

	if IsServerTeleportAllowed(player, now) then
		state.lastPosition = currentPosition
		state.lastInputTime = now
		state.teleportStrikes = 0
		state.noclipStrikes = 0
		return true
	end

	local speed = GetHorizontalSpeed(state.lastPosition, currentPosition, delta)

	if CheckTeleport(state.lastPosition, currentPosition) then
		state.teleportStrikes += 1
		if state.teleportStrikes >= Config.Teleport.RequiredStrikes then
			local evidence = BuildEvidence(state, currentPosition, speed, nil)
			ResetCharacterToPosition(character, humanoidRootPart, state.lastPosition)
			state.teleportStrikes = 0

			if AddViolation(state, "Anomalous Behaviour Detected: Teleport Exploits", evidence) then
				return false
			end

			state.lastPosition = humanoidRootPart.Position
			state.lastInputTime = os.clock()
			state.cooldownUntil = state.lastInputTime + 1
			return true
		end
	else
		state.teleportStrikes = 0
	end

	if speed > Config.MaxSpeed then
		local evidence = BuildEvidence(state, currentPosition, speed, nil)
		if AddViolation(state, "Anomalous Behaviour Detected: Speed Exploits", evidence) then
			return false
		end

		state.lastPosition = humanoidRootPart.Position
		state.lastInputTime = os.clock()
		state.cooldownUntil = state.lastInputTime + 3
		return true
	end

	if humanoid.FloorMaterial == Enum.Material.Air then
		local heightAboveGround = GetHeightAboveGround(humanoidRootPart, character)
		if heightAboveGround > Config.MaxJumpHeight then
			local evidence = BuildEvidence(state, currentPosition, speed, heightAboveGround)
			if AddViolation(state, "Anomalous Behaviour Detected: Jump Exploits", evidence) then
				return false
			end

			state.lastPosition = humanoidRootPart.Position
			state.lastInputTime = os.clock()
			state.cooldownUntil = state.lastInputTime + 3
			return true
		end
	end

	state.tickCount += 1
	if state.tickCount % Config.Noclip.CheckIntervalTicks == 0 then
		if CheckNoclip(state.lastPosition, currentPosition, character) then
			state.noclipStrikes += 1
			if state.noclipStrikes < Config.Noclip.RequiredStrikes then
				state.lastPosition = currentPosition
				state.lastInputTime = now
				return true
			end

			local evidence = BuildEvidence(state, currentPosition, speed, nil)
			state.noclipStrikes = 0
			if AddViolation(state, "Anomalous Behaviour Detected: Noclip Exploits", evidence) then
				return false
			end

			state.lastPosition = humanoidRootPart.Position
			state.lastInputTime = os.clock()
			state.cooldownUntil = state.lastInputTime + 3
			return true
		end

		state.noclipStrikes = 0
	end

	state.lastPosition = currentPosition
	state.lastInputTime = now
	return true
end

return function(context: any)
	local world = context.world
	local Components = context.Components
	local dt = context.dt

	for entity, state in world:query(Components.AntiCheatState) do
		if os.clock() < state.readyAt then
			state.elapsed = 0
			world:set(entity, Components.AntiCheatState, state)
			continue
		end

		state.elapsed += dt
		if state.elapsed < CheckInterval then
			world:set(entity, Components.AntiCheatState, state)
			continue
		end

		state.elapsed -= CheckInterval
		if RunCheck(state) then
			world:set(entity, Components.AntiCheatState, state)
		else
			world:delete(entity)
		end
	end
end

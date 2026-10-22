--!strict
--[[
	@class AntiCheatSystem

	Per-character anti-cheat state lives in ECS as plain counters, timestamps,
	history, and boundary Instance references. Detection behavior stays here
	instead of being captured by ScheduledTask callbacks.
]]

local ServerScriptService = game:GetService("ServerScriptService")

local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
local LoggingEvent = require(ServerScriptService.Signals.LogSignal)
local Config = require(ServerScriptService.Services.External.ServerAuthority.Utilities.Config)
local Whitelist = require(ServerScriptService.Services.External.ServerAuthority.Utilities.Whitelist)

local CHECK_INTERVAL = 0.5

local function createCharacterRayParams(character: Model): RaycastParams
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { character }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	return rayParams
end

local function getHorizontalSpeed(lastPosition: Vector3, currentPosition: Vector3, deltaTime: number): number
	local horizontalDelta = Vector3.new(currentPosition.X - lastPosition.X, 0, currentPosition.Z - lastPosition.Z)
	return horizontalDelta.Magnitude / deltaTime
end

local function getHorizontalDistance(fromPosition: Vector3, toPosition: Vector3): number
	local horizontalDelta = Vector3.new(toPosition.X - fromPosition.X, 0, toPosition.Z - fromPosition.Z)
	return horizontalDelta.Magnitude
end

local function getHeightAboveGround(humanoidRootPart: BasePart, character: Model): number
	local result = workspace:Raycast(
		humanoidRootPart.Position,
		Vector3.new(0, -300, 0),
		createCharacterRayParams(character)
	)
	if result then
		return humanoidRootPart.Position.Y - result.Position.Y
	end

	return 0
end

local function checkNoclip(lastPosition: Vector3, currentPosition: Vector3, character: Model): boolean
	local direction = currentPosition - lastPosition
	local distance = direction.Magnitude
	if distance < Config.Noclip.MinDistance then
		return false
	end

	local unitDirection = direction.Unit
	local result = workspace:Raycast(lastPosition, unitDirection * distance, createCharacterRayParams(character))
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

local function checkTeleport(lastPosition: Vector3, currentPosition: Vector3): boolean
	local horizontalDistance = getHorizontalDistance(lastPosition, currentPosition)
	local verticalDistance = math.abs(currentPosition.Y - lastPosition.Y)

	if horizontalDistance < Config.Teleport.MinDistance then
		return false
	end

	return verticalDistance <= Config.Teleport.MaxVerticalDistance
end

local function copyPositionHistory(history: { any }): { any }
	local copiedHistory = {}
	for index, sample in ipairs(history) do
		copiedHistory[index] = {
			Position = sample.Position,
			Time = sample.Time,
		}
	end
	return copiedHistory
end

local function isServerTeleportAllowed(player: Player, now: number): boolean
	local graceUntil = PlayerRuntimeState.GetAntiCheatTeleportGraceUntil(player)
	return type(graceUntil) == "number" and now <= graceUntil
end

local function resetCharacterToPosition(character: Model, humanoidRootPart: BasePart, targetPosition: Vector3)
	local targetCFrame = CFrame.new(targetPosition) * (humanoidRootPart.CFrame - humanoidRootPart.Position)
	character:PivotTo(targetCFrame)

	if Config.Teleport.ResetVelocity then
		humanoidRootPart.AssemblyLinearVelocity = Vector3.zero
		humanoidRootPart.AssemblyAngularVelocity = Vector3.zero
	end
end

local function buildEvidence(state: any, currentPosition: Vector3, speed: number?, heightAboveGround: number?)
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
		TeleportDistance = getHorizontalDistance(state.lastPosition, currentPosition),
		VerticalDelta = math.abs(currentPosition.Y - state.lastPosition.Y),
		Violations = state.violations + 1,
		NoclipStrikes = state.noclipStrikes,
		TeleportStrikes = state.teleportStrikes,
		HumanoidState = humanoidState,
		PositionHistory = copyPositionHistory(state.positionHistory),
	}
end

local function addViolation(state: any, reason: string, evidence): boolean
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

local function runCheck(state: any): boolean
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

	if isServerTeleportAllowed(player, now) then
		state.lastPosition = currentPosition
		state.lastInputTime = now
		state.teleportStrikes = 0
		state.noclipStrikes = 0
		return true
	end

	local speed = getHorizontalSpeed(state.lastPosition, currentPosition, delta)

	if checkTeleport(state.lastPosition, currentPosition) then
		state.teleportStrikes += 1
		if state.teleportStrikes >= Config.Teleport.RequiredStrikes then
			local evidence = buildEvidence(state, currentPosition, speed, nil)
			resetCharacterToPosition(character, humanoidRootPart, state.lastPosition)
			state.teleportStrikes = 0

			if addViolation(state, "Anomalous Behaviour Detected: Teleport Exploits", evidence) then
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
		local evidence = buildEvidence(state, currentPosition, speed, nil)
		if addViolation(state, "Anomalous Behaviour Detected: Speed Exploits", evidence) then
			return false
		end

		state.lastPosition = humanoidRootPart.Position
		state.lastInputTime = os.clock()
		state.cooldownUntil = state.lastInputTime + 3
		return true
	end

	if humanoid.FloorMaterial == Enum.Material.Air then
		local heightAboveGround = getHeightAboveGround(humanoidRootPart, character)
		if heightAboveGround > Config.MaxJumpHeight then
			local evidence = buildEvidence(state, currentPosition, speed, heightAboveGround)
			if addViolation(state, "Anomalous Behaviour Detected: Jump Exploits", evidence) then
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
		if checkNoclip(state.lastPosition, currentPosition, character) then
			state.noclipStrikes += 1
			if state.noclipStrikes < Config.Noclip.RequiredStrikes then
				state.lastPosition = currentPosition
				state.lastInputTime = now
				return true
			end

			local evidence = buildEvidence(state, currentPosition, speed, nil)
			state.noclipStrikes = 0
			if addViolation(state, "Anomalous Behaviour Detected: Noclip Exploits", evidence) then
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
		if state.elapsed < CHECK_INTERVAL then
			world:set(entity, Components.AntiCheatState, state)
			continue
		end

		state.elapsed -= CHECK_INTERVAL
		if runCheck(state) then
			world:set(entity, Components.AntiCheatState, state)
		else
			world:delete(entity)
		end
	end
end
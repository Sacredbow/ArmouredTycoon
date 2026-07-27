local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)
local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
local Remotes = ReplicatedStorage.Remotes

local LoggingEvent = ServerScriptService.Services.External.LogService:WaitForChild("Logging")

local Config = require(script.Config)
local ServerSettings = require(script.ServerSettings)

local function createCharacterRayParams(character: Model): RaycastParams
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { character }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	return rayParams
end

local function getHorizontalSpeed(lastPosition: Vector3, currentPosition: Vector3, deltaTime: number): number
	local horizontalDelta = Vector3.new(
		currentPosition.X - lastPosition.X,
		0,
		currentPosition.Z - lastPosition.Z
	)

	return horizontalDelta.Magnitude / deltaTime
end

local function getHorizontalDistance(fromPosition: Vector3, toPosition: Vector3): number
	local horizontalDelta = Vector3.new(
		toPosition.X - fromPosition.X,
		0,
		toPosition.Z - fromPosition.Z
	)

	return horizontalDelta.Magnitude
end

local function getHeightAboveGround(humanoidRootPart: BasePart, character: Model): number
	local rayOrigin = humanoidRootPart.Position
	local rayDirection = Vector3.new(0, -300, 0)
	local result = workspace:Raycast(rayOrigin, rayDirection, createCharacterRayParams(character))
	if result then
		return rayOrigin.Y - result.Position.Y
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

	local normalAlignment = math.abs(result.Normal:Dot(unitDirection))
	if normalAlignment < Config.Noclip.RequiredNormalAlignment then
		return false
	end

	return true
end

local function checkTeleport(lastPosition: Vector3, currentPosition: Vector3): boolean
	local horizontalDistance = getHorizontalDistance(lastPosition, currentPosition)
	local verticalDistance = math.abs(currentPosition.Y - lastPosition.Y)

	if horizontalDistance < Config.Teleport.MinDistance then
		return false
	end

	if verticalDistance > Config.Teleport.MaxVerticalDistance then
		return false
	end

	return true
end

local function copyPositionHistory(history)
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

Players.PlayerAdded:Connect(function(player)
	local function Registry(character)
		local humanoid = character:WaitForChild("Humanoid")
		local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
		local lastPosition = humanoidRootPart.Position
		local lastInputTime = os.clock()
		local violations = 0
		local lastViolationTime = 0
		local noclipStrikes = 0
		local teleportStrikes = 0
		local positionHistory = {}
		local tickCount = 0

		local function recordPositionSample(position: Vector3, sampleTime: number)
			table.insert(positionHistory, {
				Position = position,
				Time = math.round(sampleTime * 100) / 100,
			})

			if #positionHistory > 6 then
				table.remove(positionHistory, 1)
			end
		end

		local function buildEvidence(currentPosition: Vector3, speed: number?, heightAboveGround: number?)
			local humanoidState = "Unknown"
			local success, stateName = pcall(function()
				return humanoid:GetState().Name
			end)
			if success then
				humanoidState = stateName
			end

			return {
				CurrentPosition = currentPosition,
				LastPosition = lastPosition,
				Speed = speed,
				HeightAboveGround = heightAboveGround,
				TeleportDistance = getHorizontalDistance(lastPosition, currentPosition),
				VerticalDelta = math.abs(currentPosition.Y - lastPosition.Y),
				Violations = violations + 1,
				NoclipStrikes = noclipStrikes,
				TeleportStrikes = teleportStrikes,
				HumanoidState = humanoidState,
				PositionHistory = copyPositionHistory(positionHistory),
			}
		end

		local function AddViolation(targetPlayer: Player, reason: string, evidence)
			if ServerSettings[targetPlayer.Name] then
				return false
			end

			violations += 1
			lastViolationTime = os.clock()
			print("Violation:", violations)

			if violations >= 4 then
				LoggingEvent:Fire(targetPlayer, reason, evidence)
				targetPlayer:Kick("You were caught by SentraGuard: Anomalous Behaviour Detected.")
				--SystemMessageRemote:FireAllClients(
				--	"[Game]: <b><font color='#ff4444'>" .. targetPlayer.Name
				--		.. " was kicked by the Anti-Cheat, Agumentation of Character properties.</font></b>"
				--)
				return true
			end

			return false
		end

		local cooldownUntil = 0

		local function runCheck()
			if not character.Parent then
				return false
			end

			local now = os.clock()
			if now < cooldownUntil then
				return
			end

			local currentPosition = humanoidRootPart.Position
			local delta = now - lastInputTime
			if delta <= 0 then
				return
			end

			recordPositionSample(currentPosition, now)

			if now - lastViolationTime > Config.ViolationDecayTime then
				violations = math.max(0, violations - 1)
			end

			if isServerTeleportAllowed(player, now) then
				lastPosition = currentPosition
				lastInputTime = now
				teleportStrikes = 0
				noclipStrikes = 0
				return
			end

			local speed = getHorizontalSpeed(lastPosition, currentPosition, delta)

			if checkTeleport(lastPosition, currentPosition) then
				teleportStrikes += 1
				if teleportStrikes >= Config.Teleport.RequiredStrikes then
					local evidence = buildEvidence(currentPosition, speed, nil)
					resetCharacterToPosition(character, humanoidRootPart, lastPosition)
					teleportStrikes = 0

					if AddViolation(player, "Anomalous Behaviour Detected: Teleport Exploits", evidence) then
						return
					end

					lastPosition = humanoidRootPart.Position
					lastInputTime = os.clock()
					cooldownUntil = lastInputTime + 1
					return
				end
			else
				teleportStrikes = 0
			end

			if speed > Config.MaxSpeed then
				local evidence = buildEvidence(currentPosition, speed, nil)
				if AddViolation(player, "Anomalous Behaviour Detected: Speed Exploits", evidence) then
					return
				end

				lastPosition = humanoidRootPart.Position
				lastInputTime = os.clock()
				cooldownUntil = lastInputTime + 3
				return
			end

			if humanoid.FloorMaterial == Enum.Material.Air then
				local heightAboveGround = getHeightAboveGround(humanoidRootPart, character)
				if heightAboveGround > Config.MaxJumpHeight then
					print("Jump violation, height:", heightAboveGround)
					local evidence = buildEvidence(currentPosition, speed, heightAboveGround)
					if AddViolation(player, "Anomalous Behaviour Detected: Jump Exploits", evidence) then
						return
					end

					lastPosition = humanoidRootPart.Position
					lastInputTime = os.clock()
					cooldownUntil = lastInputTime + 3
					return
				end
			end

			tickCount += 1
			if tickCount % Config.Noclip.CheckIntervalTicks == 0 then
				if checkNoclip(lastPosition, currentPosition, character) then
					noclipStrikes += 1
					if noclipStrikes < Config.Noclip.RequiredStrikes then
						lastPosition = currentPosition
						lastInputTime = now
						return
					end

					local evidence = buildEvidence(currentPosition, speed, nil)
					noclipStrikes = 0
					if AddViolation(player, "Anomalous Behaviour Detected: Noclip Exploits", evidence) then
						return
					end

					lastPosition = humanoidRootPart.Position
					lastInputTime = os.clock()
					cooldownUntil = lastInputTime + 3
					return
				end

				noclipStrikes = 0
			end

			lastPosition = currentPosition
			lastInputTime = now
		end

		ECS.createEntity({
			Name = `{player.Name}:AntiCheatMonitor`,
			Model = character,
			ScheduledTask = {
				delay = 0.5,
				elapsed = 0,
				repeatEvery = 0.5,
				callback = runCheck,
			},
		})
	end

	player.CharacterAdded:Connect(function(character)
		ECS.createEntity({
			Name = `{player.Name}:AntiCheatRegistryDelay`,
			Model = character,
			ScheduledTask = {
				delay = 10,
				elapsed = 0,
				callback = function()
					if character.Parent then
						Registry(character)
					end
				end,
			},
		})
	end)
end)

--KickPlayer.OnServerEvent:Connect(function(player)
--	Diagnostics.reject(player, "AntiCheat.KickPlayer", "Client attempted to invoke a server-owned anti-cheat action")
--end)

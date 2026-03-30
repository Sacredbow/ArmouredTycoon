local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Remotes = ReplicatedStorage.Remotes
local SystemMessageRemote = Remotes.Interface:WaitForChild("TextChatService")
local KickPlayer = Remotes.Interface:WaitForChild("KickPlayer")
local LoggingEvent = ServerScriptService.Services.External.LogService:WaitForChild("Logging")
local MaxSpeed = 36
local MaxJumpHeight = 20
local ViolationDecayTime = 10




local ServerSettings = require(script.ServerSettings)


Players.PlayerAdded:Connect(function(Player)
	local function Registry(Character)
		local Humanoid = Character:WaitForChild("Humanoid")
		local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
		local LastPosition = HumanoidRootPart.Position
		local LastInputTime = os.clock()
		local Violations = 0
		local LastViolationTime = 0
		
		local TickCount = 0

		local function AddViolation(player : Player, reason : string)
			if ServerSettings[player.Name] then
				
				return
			end
			Violations += 1
			LastViolationTime = os.clock()
			print("Violation:", Violations)
			if Violations >= 4 then
				LoggingEvent:Fire(player, reason)
				Player:Kick("You were caught by SentraGuard™: Anomalous Behaviour Detected.")
				SystemMessageRemote:FireAllClients("[Game]: <b><font color='#ff4444'>".. Player.Name.." was kicked by the Anti-Cheat, Agumentation of Character properties.</font></b>")
				return true 
			end
			return false
		end


		local rayParams = RaycastParams.new()
		
		local function CheckNoclip(lastPos, currentPos, character)
			local direction = currentPos - lastPos
			local distance = direction.Magnitude
			if distance < 0.1 then return false end -- didn't move, skip

			local rayParams = RaycastParams.new()
			rayParams.FilterDescendantsInstances = {character}
			rayParams.FilterType = Enum.RaycastFilterType.Exclude

			local result = workspace:Raycast(lastPos, direction.Unit * distance, rayParams)
			if result and result.Instance.CanCollide then
				-- They passed THROUGH a solid part between frames
				return true
			end
			return false
		end

		local function GetHeightAboveGround()
			local rayOrigin = HumanoidRootPart.Position
			local rayDirection = Vector3.new(0, -300, 0)
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {Character}
			raycastParams.FilterType = Enum.RaycastFilterType.Exclude
			local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
			if result then
				return rayOrigin.Y - result.Position.Y
			end
			return 0
		end

		task.spawn(function()
			while Character.Parent do
				task.wait(0.5)

				local Now = os.clock()
				local CurrentPosition = HumanoidRootPart.Position
				local Delta = Now - LastInputTime
				if Delta <= 0 then continue end


				if Now - LastViolationTime > ViolationDecayTime then
					Violations = math.max(0, Violations - 1)
				end


				local horizontalDelta = Vector3.new(
					CurrentPosition.X - LastPosition.X,
					0,
					CurrentPosition.Z - LastPosition.Z
				)
				local speed = horizontalDelta.Magnitude / Delta

				if speed > MaxSpeed then
					if AddViolation(Player, "Anomalous Behaviour Detected: Speed Exploits") then return end
					--Character:PivotTo(CFrame.new(LastPosition))
					task.wait(0.1)
					LastPosition = HumanoidRootPart.Position
					LastInputTime = os.clock()
					task.wait(3)
					continue
				end


				if Humanoid.FloorMaterial == Enum.Material.Air then
					local heightAboveGround = GetHeightAboveGround()
					if heightAboveGround > MaxJumpHeight then
						print("Jump violation, height:", heightAboveGround)
						if AddViolation(Player, "Anomalous Behaviour Detected: Jump Exploits") then return end
						--Character:PivotTo(CFrame.new(LastPosition))
						task.wait(0.1)
						LastPosition = HumanoidRootPart.Position
						LastInputTime = os.clock()
						task.wait(3)
						continue
					end
				end
				
				
				TickCount += 1
				if TickCount % 2 == 0 then
					if CheckNoclip(LastPosition, CurrentPosition, Character) then
						if AddViolation(Player, "Anomalous Behaviour Detected: Noclip Exploits") then return end
						task.wait(0.1)
						LastPosition = HumanoidRootPart.Position
						LastInputTime = os.clock()
						task.wait(3)
						continue
					end
				end
			

				LastPosition = CurrentPosition
				LastInputTime = Now
			end
		end)
	end

	Player.CharacterAdded:Connect(function(Character)

		task.wait(10)

		Registry(Character)
	end)

end)


KickPlayer.OnServerEvent:Connect(function(player)
	player:Kick("Anomalous Behaviour Detected.")
	SystemMessageRemote:FireAllClients("[Game]: <b><font color='#ff4444'>".. player.Name.." was kicked by the Anti-Cheat, Agumentation of Character properties.</font></b>")
end)



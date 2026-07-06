
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.ECS)

local RagdollModule = {}

local function enableRagdoll(character)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	humanoid.PlatformStand = false
	humanoid.BreakJointsOnDeath = false

	local motorTable = {}
	local socketTable = {}

	for _, joint in pairs(character:GetDescendants()) do
		if joint:IsA("Motor6D") then
			
			table.insert(motorTable, joint:Clone())

			local socket = Instance.new("BallSocketConstraint")
			local a1 = Instance.new("Attachment")
			local a2 = Instance.new("Attachment")

			a1.Parent = joint.Part0
			a2.Parent = joint.Part1
			socket.Parent = joint.Parent
			socket.Attachment0 = a1
			socket.Attachment1 = a2
			a1.CFrame = joint.C0
			a2.CFrame = joint.C1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true

			table.insert(socketTable, {motor = joint, socket = socket, a1 = a1, a2 = a2})

			joint:Destroy()
		end
	end

	
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(root.Position) * CFrame.Angles(math.rad(-90), 0, 0)
		
		root:ApplyImpulse(Vector3.new(math.random(-50,50), -50, math.random(-50,50)))
	end

	return socketTable, motorTable
end


local function restoreCharacter(character, socketTable, motorTable)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	humanoid.PlatformStand = false


	if socketTable then
		for _, v in pairs(socketTable) do
			v.socket:Destroy()
			v.a1:Destroy()
			v.a2:Destroy()
		end
	end

	
	if motorTable then
		for _, joint in pairs(motorTable) do
			joint.Parent = character
		end
	end
end


function RagdollModule.Ragdoll(player, duration)
	local character = player.Character
	if not character then return end

	local sockets, motors = enableRagdoll(character)
	duration = duration or 4

        ECS.createEntity({
                Name = `{player.Name}:RagdollRestore`,
                ScheduledTask = {
                        delay = duration,
                        elapsed = 0,
                        callback = function()
                                if player.Character then
                                        restoreCharacter(player.Character, sockets, motors)
                                end
                        end,
                },
        })
end

return RagdollModule

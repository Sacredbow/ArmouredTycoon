
--!strict
--[[
	@class RagdollModule

	@desc
	Handles ragdoll state for players — replaces Motor6D joints with
	BallSocketConstraint to allow physics-driven limb collapse, then
	restores them after a configurable duration.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const ECS = require(ReplicatedStorage.ECS)

--// Micro-Optimisations

const math_rad = math.rad
const math_random = math.random
const Vector3_new = Vector3.new

--// Module

local RagdollModule = {}

--// Internal Methods

local function EnableRagdoll(Character: Model): (any, any)
	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then
		return nil, nil
	end

	Humanoid.PlatformStand = false
	Humanoid.BreakJointsOnDeath = false

	local MotorTable = {}
	local SocketTable = {}

	for _, Joint in Character:GetDescendants() do
		if Joint:IsA("Motor6D") then
			table.insert(MotorTable, Joint:Clone())

			local Socket = Instance.new("BallSocketConstraint")
			local A1 = Instance.new("Attachment")
			local A2 = Instance.new("Attachment")

			A1.Parent = Joint.Part0
			A2.Parent = Joint.Part1
			Socket.Parent = Joint.Parent
			Socket.Attachment0 = A1
			Socket.Attachment1 = A2
			A1.CFrame = Joint.C0
			A2.CFrame = Joint.C1
			Socket.LimitsEnabled = true
			Socket.TwistLimitsEnabled = true

			table.insert(SocketTable, { motor = Joint, socket = Socket, a1 = A1, a2 = A2 })
			Joint:Destroy()
		end
	end

	local Root = Character:FindFirstChild("HumanoidRootPart")
	if Root then
		Root.CFrame = CFrame.new(Root.Position) * CFrame.Angles(math_rad(-90), 0, 0)
		Root:ApplyImpulse(Vector3_new(math_random(-50, 50), -50, math_random(-50, 50)))
	end

	return SocketTable, MotorTable
end

local function RestoreCharacter(Character: Model, SocketTable: any, MotorTable: any)
	local Humanoid = Character:FindFirstChild("Humanoid")
	if not Humanoid then
		return
	end

	Humanoid.PlatformStand = false

	if SocketTable then
		for _, Entry in SocketTable do
			Entry.socket:Destroy()
			Entry.a1:Destroy()
			Entry.a2:Destroy()
		end
	end

	if MotorTable then
		for _, Joint in MotorTable do
			Joint.Parent = Character
		end
	end
end

--// Public API

function RagdollModule.RestoreScheduled(Character: Model, SocketTable: any, MotorTable: any)
	RestoreCharacter(Character, SocketTable, MotorTable)
end

function RagdollModule.Ragdoll(Player: Player, Duration: number?)
	local Character = Player.Character
	if not Character then
		return
	end

	local Sockets, Motors = EnableRagdoll(Character)
	Duration = Duration or 4

	ECS.createEntity({
		Name = `{Player.Name}:RagdollRestore`,
		ScheduledTask = {
			delay = Duration,
			elapsed = 0,
			kind = "RagdollRestore",
			character = Character,
			sockets = Sockets,
			motors = Motors,
		},
	})
end

return RagdollModule

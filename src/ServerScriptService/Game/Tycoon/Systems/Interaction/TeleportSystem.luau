--!strict
--[[
	Consumes Teleport intents and advances delayed arrival from ECS data.
	Prompt events are translated into ECS intents at the integration boundary.
]]
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const ValidatePromptRange = require(ServerScriptService.Game.Tycoon.Shared.ValidatePromptRange)
const Notify = require(ServerScriptService.Game.Tycoon.Shared.NotifyPlayer)
local function QueueArrival(World: any, Components: any, Entity: number, Player: Player, Data: any, Character: Model)
	const Root = Character:FindFirstChild("HumanoidRootPart")
	const TeleportPart = Data.TeleportPart
	if not Root or not Root:IsA("BasePart") or not TeleportPart or not TeleportPart:IsA("BasePart") then
		return
	end
	const Yaw = select(2, Root.CFrame:ToEulerAnglesYXZ())
	const GroundPosition = TeleportPart.Position - Vector3.new(0, TeleportPart.Size.Y / 2, 0)
	World:set(Entity, Components.TeleportGrace, os.clock() + 0.5)
	World:set(Entity, Components.TeleportPending, {
		TycoonEntity = Data.TycoonEntity,
		Character = Character,
		SpawnPoint = Data.SpawnPoint,
		Remaining = 1.5,
		Yaw = Yaw,
	})
	Character:PivotTo(CFrame.new(GroundPosition) * CFrame.Angles(0, Yaw, 0))
	Packets.packets.Notification.sendTo({ ["type"] = "info", message = "Teleporting...", RequiresFade = true }, Player)
end

local function ProcessIntent(World: any, Components: any, Entity: number, Player: Player, Intent: any)
	const Data = Intent.Data
	const TycoonEntity = Data and Data.TycoonEntity
	const Owner = TycoonEntity and World:get(TycoonEntity, Components.Owner)
	if not Owner or Owner.player ~= Player then
		Notify(Player, "error", "Only the tycoon owner can use this teleporter.")
		return
	end
	const Prompt = Data.TeleportPart and Data.TeleportPart:FindFirstChild("TeleportPrompt")
	if not Prompt or not Prompt:IsA("ProximityPrompt") or not ValidatePromptRange(Player, Prompt) then
		Notify(Player, "info", "Move closer to use the teleporter.")
		return
	end
	const Character = Player.Character
	if Character then
		QueueArrival(World, Components, Entity, Player, Data, Character)
	end
end

return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const Dt = Context.dt
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.PromptIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "Teleport" then
				ProcessIntent(World, Components, Entity, Player, Intent)
			else
				Remaining[#Remaining + 1] = Intent
			end
		end
		if #Remaining == 0 then
			World:remove(Entity, Components.PromptIntent)
		else
			World:set(Entity, Components.PromptIntent, Remaining)
		end
	end

	for Entity, Player, Pending in World:query(Components.PlayerRef, Components.TeleportPending) do
		Pending.Remaining -= Dt
		const Character = Pending.Character
		const Owner = World:get(Pending.TycoonEntity, Components.Owner)
		if Pending.Remaining > 0 then
			if Character and Character.Parent and Player.Character == Character then
				World:set(Entity, Components.TeleportPending, Pending)
			else
				World:remove(Entity, Components.TeleportPending)
			end
		elseif
			Owner
			and Owner.player == Player
			and Character
			and Character.Parent
			and Player.Character == Character
			and Pending.SpawnPoint
			and Pending.SpawnPoint.Parent
		then
			World:set(Entity, Components.TeleportGrace, os.clock() + 0.4)
			Character:PivotTo(Pending.SpawnPoint.CFrame)
			World:remove(Entity, Components.TeleportPending)
		else
			World:remove(Entity, Components.TeleportPending)
		end
	end
end

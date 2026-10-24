--!strict
-- Prompt and contact callbacks are translation boundaries only. They enqueue
-- ECS intents; gameplay systems consume those intents on the runner frame.
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Players = game:GetService("Players")
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const QuickZone = require(ReplicatedStorage.Packages.quickzone)
const Bridge = {}
local function FindPlayerEntity(Player: Player): number?
	for Entity, PlayerRef in ECS.world:query(ECS.Components.PlayerRef) do
		if PlayerRef == Player then
			return Entity
		end
	end
	return nil
end

local function FindPlayerFromHit(Hit: Instance): Player?
	const Character = Hit:FindFirstAncestorOfClass("Model")
	return Character and Players:GetPlayerFromCharacter(Character)
end

local function QueueContact(Player: Player, Action: string, Data: any)
	const Entity = FindPlayerEntity(Player)
	if not Entity then
		return
	end
	const Queue = ECS.world:get(Entity, ECS.Components.ContactIntent) or {}
	Queue[#Queue + 1] = { Action = Action, Data = Data, Player = Player, TouchedAt = os.clock() }
	ECS.world:set(Entity, ECS.Components.ContactIntent, Queue)
end

function Bridge.BindZone(Observer: any, Zone: any, TycoonEntity: number, Connections: { any })
	const EnterCleanup = Observer:onPlayerEnter(function(Player: Player)
		QueueContact(Player, "LabDoorEnter", { TycoonEntity = TycoonEntity })
	end)
	const ExitCleanup = Observer:onPlayerExit(function(Player: Player)
		QueueContact(Player, "LabDoorExit", { TycoonEntity = TycoonEntity })
	end)
	Connections[#Connections + 1] = {
		Disconnect = function()
			if EnterCleanup then
				EnterCleanup()
			end
			if ExitCleanup then
				ExitCleanup()
			end
			Observer:destroy()
			Zone:destroy()
		end,
	}
end

function Bridge.BindPrompt(Prompt: ProximityPrompt, Action: string, Data: any, Connections: { RBXScriptConnection })
	Connections[#Connections + 1] = Prompt.Triggered:Connect(function(Player: Player)
		const Entity = FindPlayerEntity(Player)
		if not Entity then
			return
		end
		const Queue = ECS.world:get(Entity, ECS.Components.PromptIntent) or {}
		Queue[#Queue + 1] = { Action = Action, Data = Data, Player = Player, TriggeredAt = os.clock() }
		ECS.world:set(Entity, ECS.Components.PromptIntent, Queue)
	end)
end

function Bridge.BindContact(Part: BasePart, Action: string, Data: any, Connections: { RBXScriptConnection })
	Connections[#Connections + 1] = Part.Touched:Connect(function(Hit: Instance)
		const Player = FindPlayerFromHit(Hit)
		const Entity = Player and FindPlayerEntity(Player)
		if not Player or not Entity then
			return
		end
		const Queue = ECS.world:get(Entity, ECS.Components.ContactIntent) or {}
		Queue[#Queue + 1] = { Action = Action, Data = Data, Player = Player, Hit = Hit, TouchedAt = os.clock() }
		ECS.world:set(Entity, ECS.Components.ContactIntent, Queue)
	end)
end

function Bridge.BindContactEnded(Part: BasePart, Action: string, Data: any, Connections: { RBXScriptConnection })
	Connections[#Connections + 1] = Part.TouchEnded:Connect(function(Hit: Instance)
		const Player = FindPlayerFromHit(Hit)
		const Entity = Player and FindPlayerEntity(Player)
		if not Player or not Entity then
			return
		end
		const Queue = ECS.world:get(Entity, ECS.Components.ContactIntent) or {}
		Queue[#Queue + 1] = { Action = Action, Data = Data, Player = Player, Hit = Hit, TouchedAt = os.clock() }
		ECS.world:set(Entity, ECS.Components.ContactIntent, Queue)
	end)
end

function Bridge.BindTycoon(TycoonEntity: number): () -> ()
	const Hierarchy = ECS.world:get(TycoonEntity, ECS.Components.Hierarchy)
	const Connections: { any } = {}
	if not Hierarchy then
		return function() end
	end

	local function BindRequester(Root: Instance?, Action: string, Data: any)
		if not Root then
			return
		end
		const Requester = Root:FindFirstChild("Requester")
		const Prompt = Requester and Requester:FindFirstChildOfClass("ProximityPrompt")
		if Prompt then
			Bridge.BindPrompt(Prompt, Action, Data, Connections)
		end
	end

	if Hierarchy.GunModels then
		for _, GunModel in Hierarchy.GunModels:GetChildren() do
			BindRequester(GunModel, "GunPickup", { TycoonEntity = TycoonEntity, GunModel = GunModel })
		end
	end

	const OwnerDoor = Hierarchy.MainItems and Hierarchy.MainItems:FindFirstChild("OwnerDoor")
	const OwnerDoorPart = OwnerDoor and OwnerDoor:FindFirstChild("Door")
	if OwnerDoorPart and OwnerDoorPart:IsA("BasePart") then
		Bridge.BindContact(OwnerDoorPart, "ClaimTycoon", { TycoonEntity = TycoonEntity }, Connections)
	end

	for _, Root in { Hierarchy.MainItems, Hierarchy.Stages, Hierarchy.PurchasedItems } do
		if Root then
			for _, Prompt in Root:GetDescendants() do
				if
					Prompt:IsA("ProximityPrompt")
					and Prompt.Name == "Activate"
					and Prompt:FindFirstAncestor("ButtonStand")
				then
					Bridge.BindPrompt(
						Prompt,
						"NukeLaunch",
						{ TycoonEntity = TycoonEntity, Prompt = Prompt },
						Connections
					)
				end
			end
		end
	end

	if Hierarchy.Stages then
		for _, Teleporter in Hierarchy.Stages:GetDescendants() do
			if not Teleporter:IsA("Model") or not Teleporter:HasTag("Teleporters") then
				continue
			end
			const TeleportPart = Teleporter:FindFirstChild("Teleport")
			const SpawnPoint = Teleporter:FindFirstChild("SpawnPoint")
			if TeleportPart and TeleportPart:IsA("BasePart") and SpawnPoint and SpawnPoint:IsA("BasePart") then
				const Prompt = TeleportPart:FindFirstChild("TeleportPrompt")
				if Prompt and Prompt:IsA("ProximityPrompt") then
					Bridge.BindPrompt(
						Prompt,
						"Teleport",
						{ TycoonEntity = TycoonEntity, TeleportPart = TeleportPart, SpawnPoint = SpawnPoint },
						Connections
					)
				end
			end
		end
		const Stage1 = Hierarchy.Stages:FindFirstChild("Stage1")
		const AmmoArea = Stage1 and Stage1:FindFirstChild("AmmoArea")
		const Lakester = AmmoArea and AmmoArea:FindFirstChild("Lakester")
		BindRequester(Lakester, "Reload", { TycoonEntity = TycoonEntity, Lakester = Lakester })
		const ATM = Hierarchy.MainItems and Hierarchy.MainItems:FindFirstChild("ATM")
		const Display = ATM and ATM:FindFirstChild("Display")
		const Request = Display and Display:FindFirstChild("Request")
		if Request and Request:IsA("ProximityPrompt") then
			Bridge.BindPrompt(Request, "CollectCash", { TycoonEntity = TycoonEntity, Prompt = Request }, Connections)
		end

		local ArmourAssets = ReplicatedStorage:FindFirstChild("Assets")
			and ReplicatedStorage.Assets:FindFirstChild("CharacterItems")
			and ReplicatedStorage.Assets.CharacterItems:FindFirstChild("Armour") --__STYLUA_CONST__
		for ArmourName, Health in { Armour1 = 50, Armour2 = 120 } do
			const Pickup = Stage1:FindFirstChild(ArmourName)
			const Part = Pickup and Pickup:FindFirstChild("Part")
			const Template = ArmourAssets and ArmourAssets:FindFirstChild(ArmourName)
			if Part and Part:IsA("BasePart") and Template and Template:IsA("Model") then
				Bridge.BindContact(
					Part,
					"ArmourPickup",
					{ TycoonEntity = TycoonEntity, Part = Part, Template = Template, Health = Health },
					Connections
				)
			end
		end

		const Stage2 = Hierarchy.Stages:FindFirstChild("Stage2")
		const Lab = Stage2 and Stage2:FindFirstChild("ScientificLab")
		const FuseBox = Lab and Lab:FindFirstChild("FUSE_BOX")
		const Fuse = FuseBox and FuseBox:FindFirstChild("FuseBox")
		const Lever = Fuse and Fuse:FindFirstChild("FuseLeaver")
		const LeverPart = Lever and Lever:FindFirstChild("Part")
		const PowerPrompt = LeverPart and LeverPart:FindFirstChildWhichIsA("ProximityPrompt", true)
		if PowerPrompt then
			Bridge.BindPrompt(
				PowerPrompt,
				"RestorePower",
				{ TycoonEntity = TycoonEntity, Prompt = PowerPrompt },
				Connections
			)
		end
		const LabDoor = Lab and Lab:FindFirstChild("LabDoor")
		const Magnitude = LabDoor and LabDoor:FindFirstChild("Magnitude")
		const Magnitude2 = LabDoor and LabDoor:FindFirstChild("Magnitude2")
		const DoorPart = LabDoor and LabDoor:IsA("Model") and LabDoor.PrimaryPart
		if
			LabDoor
			and LabDoor:IsA("Model")
			and Magnitude
			and Magnitude:IsA("BasePart")
			and Magnitude2
			and Magnitude2:IsA("BasePart")
			and DoorPart
		then
			const BaseCFrame = DoorPart.CFrame
			ECS.world:set(TycoonEntity, ECS.Components.LabDoor, {
				Door = LabDoor,
				BaseCFrame = BaseCFrame,
				OpenCFrame = BaseCFrame * CFrame.new(12, 0, 0),
				IsOpen = false,
				ActiveTween = nil,
				CloseRemaining = 0,
			})
			const Zone = QuickZone.Zone.fromParts({ Magnitude, Magnitude2 }, { autoSync = false })
			const Observer = QuickZone.Observer.new({ zones = { Zone } })
			Bridge.BindZone(Observer, Zone, TycoonEntity, Connections)
		end
		for _, Root in { Hierarchy.Stages, Hierarchy.PurchasedItems, Hierarchy.MainItems, Hierarchy.GunModels } do
			if Root then
				for _, ElectricityPart in Root:GetDescendants() do
					if ElectricityPart:IsA("BasePart") and ElectricityPart:HasTag("ElectricityParts") then
						Bridge.BindContact(
							ElectricityPart,
							"ElectricityHit",
							{ TycoonEntity = TycoonEntity, Part = ElectricityPart },
							Connections
						)
					end
				end
			end
		end

		const Stage4 = Hierarchy.Stages:FindFirstChild("Stage4")
		const Lasers = Stage4 and Stage4:FindFirstChild("Lasers")
		if Lasers then
			for _, Laser in Lasers:GetChildren() do
				if Laser:IsA("BasePart") then
					Bridge.BindContact(Laser, "LaserHit", { TycoonEntity = TycoonEntity, Laser = Laser }, Connections)
				end
			end
		end
	end

	return function()
		for _, Connection in Connections do
			Connection:Disconnect()
		end
		table.clear(Connections)
	end
end

return Bridge

--!strict
-- ECS electricity fuse and hazard system for a tycoon entity.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local Observers = require(ReplicatedStorage.Packages.Observers)
local Factory = require(ServerScriptService.ECS.TycoonFactory)
local Packets = require(ReplicatedStorage.Network.Packets)

local ValidatePromptRange = require(ServerScriptService.Classes.Tycoon.Utilities.ValidatePromptRange)

local ElectricitySystem = {}

local ELECTRIFY_IMPACT_DELAY = 0.3
local ELECTRIFY_COOLDOWN = 5
local function toast(player: Player, kind: string, message: string)
	Packets.packets.Notification.sendTo({["type"] = kind, message = message}, player)
end

local function enableElectricity(hierarchy: any)
	local purchased = hierarchy.PurchasedItems
	if not purchased then return end
	for _, part in purchased:GetDescendants() do
		if part:IsA("BasePart") and part:FindFirstChild("SwitchLight") then
			part.Material = Enum.Material.Neon
			part.BrickColor = BrickColor.new("Institutional white")
		elseif part:IsA("PointLight") then
			part.Brightness = 0.09
		elseif CollectionService:HasTag(part, "ElectricityParts") and part:IsA("BasePart") then
			part.Material = Enum.Material.Neon
		elseif CollectionService:HasTag(part, "Power") and part:IsA("ParticleEmitter") then
			part.Enabled = true
		end
	end
end

local function electrify(entity: number, player: Player, playerService: any, ownerGeneration: number)
	if playerService:IsElectrified(player) then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return
	end

	playerService:SetElectrified(player, true)
	humanoid:UnequipTools()

	-- Store the exact character/humanoid that was hit. The scheduled system
	-- validates that the player has not respawned before applying the impact.
	ECS.createEntity({
		Name = player.Name .. ":ElectricityImpact",
		ScheduledTask = {
			delay = ELECTRIFY_IMPACT_DELAY,
			elapsed = 0,
			kind = "ElectricityImpact",
			player = player,
			character = character,
			humanoid = humanoid,
			tycoonEntity = entity,
			ownerGeneration = ownerGeneration,
			sourceModel = Factory.getModel(entity),
		},
	})
	ECS.createEntity({
		Name = player.Name .. ":ElectricityCooldown",
		ScheduledTask = {
			delay = ELECTRIFY_COOLDOWN,
			elapsed = 0,
			kind = "ElectricityCooldown",
			player = player,
		},
	})
end

function ElectricitySystem.setup(entity: number, playerService: any): (() -> ())?
	local hierarchy = Factory.getHierarchy(entity)
	local model = Factory.getModel(entity)
	if not hierarchy or not hierarchy.Stages or not model then return nil end
	local stage2 = hierarchy.Stages:FindFirstChild("Stage2")
	local lab = stage2 and stage2:FindFirstChild("ScientificLab")
	local fuseBox = lab and lab:FindFirstChild("FUSE_BOX")
	local fuse = fuseBox and fuseBox:FindFirstChild("FuseBox")
	local lever = fuse and fuse:FindFirstChild("FuseLeaver")
	local leverPart = lever and lever:FindFirstChild("Part")
	local prompt = leverPart and leverPart:FindFirstChildWhichIsA("ProximityPrompt", true)
	local connections: {RBXScriptConnection} = {}

	if prompt then
		table.insert(connections, prompt.Triggered:Connect(function(player: Player)
			local ownerData = ECS.world:get(entity, ECS.Components.Owner)
			if not ownerData or ownerData.player ~= player then
				toast(player, "error", "Only the tycoon owner can restore power.")
				return
			end
			if not ValidatePromptRange(player, prompt) then return end
			local currentState = Factory.getState(entity)
			if not currentState or currentState.owner ~= player then
				return
			end
			if currentState.power then
				toast(player, "info", "Power is already on")
				return
			end
			if not hierarchy.PurchasedItems:FindFirstChild("1b") then
				toast(player, "info", "Find the wires first")
				return
			end
			currentState.power = true
			ECS.world:set(entity, ECS.Components.TycoonState, currentState)
			enableElectricity(hierarchy)
			toast(player, "success", "Power restored")
		end))
	end

	-- Observe tagged hazard parts as a lifecycle boundary. This handles parts
	-- added by purchased builds and disconnects them when the tycoon is removed.
	local stopElectricityObserver = Observers.observeTag("ElectricityParts", function(instance: Instance)
		if not instance:IsA("BasePart") then
			return nil
		end

		local connection = instance.Touched:Connect(function(hit: Instance)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			local ownerData = ECS.world:get(entity, ECS.Components.Owner)
			local tycoonState = Factory.getState(entity)
			local ownerPlayer = ownerData and ownerData.player
			if not player or not ownerPlayer or not tycoonState or not tycoonState.power then return end
			if ownerPlayer == player then return end
			electrify(entity, player, playerService, ownerData.generation or 0)
		end)

		return function()
			connection:Disconnect()
		end
	end, { model })

	return function()
		stopElectricityObserver()
		for _, connection in connections do connection:Disconnect() end
		table.clear(connections)
	end
end

return ElectricitySystem




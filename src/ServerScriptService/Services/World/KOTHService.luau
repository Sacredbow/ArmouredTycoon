--!strict

-- KOTHService is a world adapter. It discovers the physical zone and translates
-- touch boundaries into ECS contact intents. KOTH state and rules live in KOTHSystem.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.Shared.Core.ECS)
local PromptIntentBridge = require(ServerScriptService.ECS.PromptIntentBridge)

local KOTHService = {}

local Connections: { any } = {}
local ZoneEntity: number? = nil
local Initialized = false

local function FindKingLabel(Contest: BasePart): TextLabel?
	local King = Contest:FindFirstChild("King")
	local Label = King and King:FindFirstChild("TextLabel")
	if Label and Label:IsA("TextLabel") then
		return Label
	end
	warn("[KOTHService] Contest.King.TextLabel was not found")
	return nil
end

function KOTHService.Init()
	if Initialized then
		return
	end

	local Model = workspace.Map.MiddleSection.KOTH
	if not Model:IsA("Model") then
		warn("[KOTHService] workspace.Map.MiddleSection.KOTH was not found")
		return
	end

	local Contest = Model:FindFirstChild("Contest")
	if not Contest or not Contest:IsA("BasePart") then
		warn("[KOTHService] workspace.Map.MiddleSection.KOTH.Contest must be a BasePart")
		return
	end

	ZoneEntity = ECS.createEntity({
		Name = "KOTH:Zone",
		KOTHZone = {
			Model = Model,
			Contest = Contest,
			KingLabel = FindKingLabel(Contest),
			KingEntity = nil,
			KingStartedAt = 0,
			LastAnnouncedInterval = 0,
			AwardRemaining = 1,
			AwardInterval = 1,
		},
	})

	PromptIntentBridge.BindContact(Contest, "KOTHEnter", { ZoneEntity = ZoneEntity }, Connections)
	PromptIntentBridge.BindContactEnded(Contest, "KOTHExit", { ZoneEntity = ZoneEntity }, Connections)
	Initialized = true
end

function KOTHService.Destroy()
	for _, Connection in Connections do
		if Connection.Disconnect then
			Connection:Disconnect()
		end
	end
	table.clear(Connections)

	if ZoneEntity and ECS.world:get(ZoneEntity, ECS.Components.KOTHZone) then
		ECS.deleteEntity(ZoneEntity)
	end

	ZoneEntity = nil
	Initialized = false
end

return KOTHService

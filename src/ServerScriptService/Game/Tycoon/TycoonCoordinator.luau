--!strict
--[[
	TycoonRuntime contains the Tycoon domain systems. Each function operates on
	an ECS entity and component data; no Tycoon instance or metatable is used.
]]
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.Shared.Core.ECS)
local Factory = require(ServerScriptService.Game.Tycoon.TycoonFactory)
local ButtonConfiguration = require(ServerScriptService.Game.Tycoon.Config.ButtonConfig)
local ColorConfiguration = require(ServerScriptService.Game.Tycoon.Config.ColorPalette)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
local Notify = require(ServerScriptService.Game.Tycoon.Shared.NotifyPlayer)
local BuildAssemble = require(ReplicatedStorage.Shared.Game.Tycoon.Building.BuildEffect)
local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
local InteractionSystem = require(ServerScriptService.Game.Tycoon.Systems.InteractionSystem)
local PromptIntentBridge = require(ServerScriptService.ECS.PromptIntentBridge)
local FriendService = require(ServerScriptService.Game.Tycoon.PlayerService.FriendService)

local Runtime = {}
local connections: { [number]: { any } } = {}
local buttonConnections: { [number]: { RBXScriptConnection } } = {}
local purchaseServices: { [number]: any } = {}
local buildServices: { [number]: any } = {}
local purchaseDebounce: { [BasePart]: number } = setmetatable({}, { __mode = "k" })
local buttonEntities: { [BasePart]: number } = setmetatable({}, { __mode = "k" })

local palettes = {
	Tycoon1 = ColorConfiguration.White,
	Tycoon2 = ColorConfiguration.Blue,
	Tycoon3 = ColorConfiguration.Black,
	Tycoon4 = ColorConfiguration.Green,
	Tycoon5 = ColorConfiguration.Grey,
	Tycoon6 = ColorConfiguration.Red,
	Tycoon7 = ColorConfiguration.Yellow,
	Tycoon8 = ColorConfiguration.Purple,
}

local function hierarchy(entity: number): any?
	return ECS.world:get(entity, ECS.Components.Hierarchy)
end

local function state(entity: number): any?
	return ECS.world:get(entity, ECS.Components.TycoonState)
end

local function owner(entity: number): Player?
	local ownerData = ECS.world:get(entity, ECS.Components.Owner)
	return ownerData and ownerData.player
end

local function model(entity: number): Model?
	return ECS.world:get(entity, ECS.Components.ModelRef)
end

local function findPlayerEntity(player: Player): number?
	for entity, playerRef in ECS.world:query(ECS.Components.PlayerRef) do
		if playerRef == player then
			return entity
		end
	end
	return nil
end

local function findOwnedTycoon(player: Player): number?
	for entity, ownerData in ECS.world:query(ECS.Components.Owner) do
		if ownerData.player == player then
			return entity
		end
	end
	return nil
end

local function applyAppearance(entity: number)
	local h = hierarchy(entity)
	local m = model(entity)
	local palette = m and palettes[m.Name]
	if not h or not palette then
		return
	end
	local colors = { Primary = palette.Primary, Secondary = palette.Secondary, Accent = palette.Accent }
	for _, root in { h.Stages, h.GunModels } do
		if root then
			for _, item in root:GetDescendants() do
				if item:IsA("BasePart") then
					for tag, color in colors do
						if CollectionService:HasTag(item, tag) then
							item.Color = color
							break
						end
					end
				end
			end
		end
	end
end

local function findTemplate(entity: number, name: string): Instance?
	local h = hierarchy(entity)
	if not h then
		return nil
	end
	for _, root in { h.Droppers, h.GunModels, h.MainItems, h.Stages, h.Components } do
		if root then
			local direct = root:FindFirstChild(name)
			if direct then
				return direct
			end
		end
	end
	local stages = h.Stages
	return stages and stages:FindFirstChild(name, true) or nil
end

local function dependenciesMet(entity: number, config: any): boolean
	for _, name in config.Build.Items do
		if not findTemplate(entity, name) then
			return false
		end
	end
	return true
end

local function recordPurchase(entity: number, buttonName: string, save: boolean?)
	local purchased = ECS.world:get(entity, ECS.Components.PurchasedButtons)
	if not purchased or purchased.lookup[buttonName] then
		return
	end
	purchased.lookup[buttonName] = true
	table.insert(purchased.order, buttonName)
	ECS.world:set(entity, ECS.Components.PurchasedButtons, purchased)
	local player = owner(entity)
	if save ~= false and player then
		local profile = ProfileManager.Profiles[player]
		if profile then
			profile.Data.TycoonConstruction = profile.Data.TycoonConstruction or { PurchasedButtons = {} }
			profile.Data.TycoonConstruction.PurchasedButtons = table.clone(purchased.order)
		end
	end
end

local function spawnItems(entity: number, config: any)
	local h = hierarchy(entity)
	local stateValue = state(entity)
	if not h or not stateValue then
		return
	end
	for _, name in config.Build.Items do
		local template = findTemplate(entity, name)
		if template then
			template.Parent = h.PurchasedItems
			ECS.createEntity({
				Name = string.format("%s:%s:BuildItem", stateValue.model.Name, template.Name),
				Model = template,
				BuildItem = { item = template, purchasedAt = os.clock() },
			})
			if template:IsA("Model") then
				BuildAssemble.Play(template, function() end)
				local spawnPart = template:FindFirstChild("Spawn")
				if spawnPart and spawnPart:IsA("BasePart") then
					local value = if template.Name == "GoldenDropper"
						then 85
						elseif template.Name == "EliteDropper" then 225
						else 15
					ECS.createEntity({
						Name = string.format("%s:%s:Producer", stateValue.model.Name, template.Name),
						Model = template,
						Producer = {
							tycoonEntity = entity,
							dropper = template,
							spawnPart = spawnPart,
							value = value,
							interval = 2.5,
							elapsed = 0,
							paused = false,
						},
					})
				end
			end
		end
	end
end

function Runtime.CheckCompletion(entity: number): boolean
	local h = hierarchy(entity)
	if not h or not h.Buttons then
		return false
	end
	for _, button in h.Buttons:GetChildren() do
		if button:IsA("BasePart") then
			local config = ButtonConfiguration.Get(button.Name)
			if
				config
				and ButtonConfiguration.GetKind(config) == "Basic"
				and ButtonConfiguration.GetGamepass(config) == nil
			then
				return false
			end
		end
	end
	return true
end
function Runtime.ApplyPurchasedButton(entity: number, button: BasePart, options: any?): boolean
	if not button or not button.Parent then
		return false
	end
	local config = ButtonConfiguration.Get(button.Name)
	if not config or not dependenciesMet(entity, config) then
		return false
	end
	spawnItems(entity, config)
	for _, nextName in ButtonConfiguration.GetRevealedButtons(config) do
		local nextButton = hierarchy(entity).Buttons:FindFirstChild(nextName)
		if nextButton and nextButton:IsA("BasePart") then
			nextButton.Transparency = 0
			nextButton.CanTouch = true
			local gui = nextButton:FindFirstChild("BillboardGui")
			if gui and gui:IsA("BillboardGui") then
				gui.Enabled = true
			end
		end
	end
	local purchased = ECS.world:get(entity, ECS.Components.PurchasedButtons)
	if purchased then
		recordPurchase(entity, button.Name, options and options.saveState)
	end
	local buttonEntity = buttonEntities[button]
	if buttonEntity then
		ECS.deleteEntity(buttonEntity)
		buttonEntities[button] = nil
	end
	purchaseDebounce[button] = nil
	button:Destroy()
	return true
end

local CURRENT_CONFIG_VERSION = 1

local function migrateConstruction(player: Player)
	local profile = ProfileManager.Profiles[player]
	local construction = profile and profile.Data.TycoonConstruction
	if type(construction) ~= "table" then
		return
	end
	local savedVersion = tonumber(construction.ConfigVersion) or 1
	if savedVersion >= CURRENT_CONFIG_VERSION then
		return
	end
	local savedButtons = construction.PurchasedButtons
	if type(savedButtons) ~= "table" then
		construction.PurchasedButtons = {}
		construction.ConfigVersion = CURRENT_CONFIG_VERSION
		return
	end
	local validButtons = {}
	for _, buttonName in savedButtons do
		if ButtonConfiguration.Get(tostring(buttonName)) then
			table.insert(validButtons, tostring(buttonName))
		end
	end
	construction.PurchasedButtons = validButtons
	construction.ConfigVersion = CURRENT_CONFIG_VERSION
end
function Runtime.Claim(entity: number, player: Player, buildService: any?)
	buildService = buildService or buildServices[entity]
	if owner(entity) then
		return false
	end
	local h = hierarchy(entity)
	local m = model(entity)
	if not h or not m then
		return false
	end
	Factory.SetOwner(entity, player)
	local stateValue = state(entity)
	if stateValue then
		local PlayerEntity = findPlayerEntity(player)
		local multiplier = PlayerEntity and ECS.world:get(PlayerEntity, ECS.Components.PlayerMultiplier) or 1
		multiplier *= FriendService.GetBoostMultiplier(player)
		stateValue.cashMultiplier = multiplier
		ECS.world:set(entity, ECS.Components.TycoonState, stateValue)
	end
	local door = h.MainItems:FindFirstChild("OwnerDoor")
	local doorPart = door and door:FindFirstChild("Door")
	local title = door and door:FindFirstChild("Title")
	local label = title and title:FindFirstChild("SurfaceGui") and title.SurfaceGui:FindFirstChild("TextLabel")
	if doorPart and doorPart:IsA("BasePart") then
		doorPart.Transparency = 0.6
	end
	if label and label:IsA("TextLabel") then
		label.Text = player.Name .. "'s Tycoon"
	end
	migrateConstruction(player)
	local profile = ProfileManager.Profiles[player]
	local construction = profile and profile.Data.TycoonConstruction
	local savedButtons = construction and construction.PurchasedButtons
	if type(savedButtons) == "table" then
		for _, buttonName in savedButtons do
			local savedButton = h.Buttons:FindFirstChild(tostring(buttonName))
			if savedButton and savedButton:IsA("BasePart") then
				Runtime.ApplyPurchasedButton(entity, savedButton, { saveState = false })
			end
		end
	end
	if buildService and buildService.RestorePlayer then
		buildService:RestorePlayer(player, entity)
	end
	Packets.packets.Tutorial.sendTo({ type = "TycoonClaimed", target = m.Name }, player)
	return true
end

local function disconnectButtons(entity: number)
	local list = buttonConnections[entity]
	if list then
		for _, connection in list do
			connection:Disconnect()
		end
		buttonConnections[entity] = nil
	end
end

function Runtime.PurchaseButton(entity: number, player: Player, button: BasePart): boolean
	if button.Transparency == 1 or owner(entity) ~= player then
		if owner(entity) ~= player then
			Notify(player, "info", "Only the tycoon owner can buy buttons.")
		end
		return false
	end
	const config = ButtonConfiguration.Get(button.Name)
	if not config or not dependenciesMet(entity, config) then
		Notify(player, "info", "Purchase the required buttons first.")
		return false
	end
	const gamepass = ButtonConfiguration.GetGamepass(config)
	if gamepass then
		const now = os.clock()
		if purchaseDebounce[button] and now - purchaseDebounce[button] < 1.5 then
			return false
		end
		purchaseDebounce[button] = now
		const service = purchaseServices[entity]
		if service then
			service:PromptGamepass(player, button, entity, gamepass)
		end
		return true
	end
	const price = ButtonConfiguration.GetPrice(config)
	const profile = ProfileManager.Profiles[player]
	if price and profile and profile.Data.Cash >= price then
		ProfileManager.AddCash(player, -price)
		Runtime.ApplyPurchasedButton(entity, button)
		const PlayerEntity = findPlayerEntity(player)
		if PlayerEntity then
			ECS.world:set(PlayerEntity, ECS.Components.CanRebirth, Runtime.CheckCompletion(entity))
		end
		return true
	end
	return false
end

local function bindButtons(entity: number, purchaseService: any?)
	local h = hierarchy(entity)
	local tycoonModel = model(entity)
	if not h or not h.Buttons or not tycoonModel then
		return
	end

	disconnectButtons(entity)
	local list: { any } = {}
	buttonConnections[entity] = list

	for _, button in h.Buttons:GetChildren() do
		if not button:IsA("BasePart") then
			continue
		end
		local config = ButtonConfiguration.Get(button.Name)
		if not config then
			continue
		end
		ButtonConfiguration.ApplyVisual(button, config)
		local buttonEntity = ECS.createEntity({
			Name = string.format("%s:%s:Button", tycoonModel.Name, button.Name),
			Model = button,
			Button = { tycoonEntity = entity, button = button, visible = ButtonConfiguration.StartsVisible(config) },
		})
		buttonEntities[button] = buttonEntity
		PromptIntentBridge.BindContact(button, "PurchaseButton", { TycoonEntity = entity, Button = button }, list)
	end
end

function Runtime.Cleanup(entity: number, buildService: any?)
	if ECS.world:get(entity, ECS.Components.NukeCooldown) then
		ECS.world:remove(entity, ECS.Components.NukeCooldown)
	end
	for producerEntity, producer in ECS.world:query(ECS.Components.Producer) do
		if producer.tycoonEntity == entity then
			ECS.deleteEntity(producerEntity)
		end
	end
	for itemEntity, item in ECS.world:query(ECS.Components.BuildItem) do
		local itemValue = item.item
		local currentModel = model(entity)
		if currentModel and itemValue and itemValue:IsDescendantOf(currentModel) then
			ECS.deleteEntity(itemEntity)
		end
	end
	disconnectButtons(entity)
	for buttonEntity, buttonData in ECS.world:query(ECS.Components.Button) do
		if buttonData.tycoonEntity == entity then
			if buttonData.button then
				buttonEntities[buttonData.button] = nil
				purchaseDebounce[buttonData.button] = nil
			end
			ECS.world:delete(buttonEntity)
		end
	end
	local player = owner(entity)
	if player then
		const PlayerEntity = findPlayerEntity(player)
		if PlayerEntity then
			ECS.world:set(PlayerEntity, ECS.Components.Electrified, false)
			ECS.world:set(PlayerEntity, ECS.Components.ArmourEquipped, false)
			ECS.world:set(PlayerEntity, ECS.Components.CanRebirth, false)
		end
	end
	if buildService and buildService.ReleaseTycoon then
		buildService:ReleaseTycoon(entity)
	end
	local h = hierarchy(entity)
	if h then
		if h.Buttons and h.ButtonTemplate then
			for _, child in h.Buttons:GetChildren() do
				child:Destroy()
			end
			for _, child in h.ButtonTemplate:GetChildren() do
				child:Clone().Parent = h.Buttons
			end
		end
		local purchased = h.PurchasedItems
		if purchased then
			for _, item in purchased:GetChildren() do
				item:Destroy()
			end
		end
	end
	bindButtons(entity)
	Factory.SetOwner(entity, nil)
	local current = state(entity)
	if current then
		current.collectorAmount = 0
		current.displayUpdatePending = false
		current.power = false
		ECS.world:set(entity, ECS.Components.TycoonState, current)
	end
	local purchased = ECS.world:get(entity, ECS.Components.PurchasedButtons)
	if purchased then
		table.clear(purchased.lookup)
		table.clear(purchased.order)
		ECS.world:set(entity, ECS.Components.PurchasedButtons, purchased)
	end
end

function Runtime.Init(entity: number, purchaseService: any, buildService: any?)
	purchaseServices[entity] = purchaseService
	buildServices[entity] = buildService
	local h = hierarchy(entity)
	if not h then
		return
	end
	if connections[entity] then
		return
	end
	applyAppearance(entity)
	connections[entity] = {}

	local promptIntentCleanup = PromptIntentBridge.BindTycoon(entity)
	if promptIntentCleanup then
		table.insert(connections[entity], { Disconnect = promptIntentCleanup })
	end
	local interactionCleanup = InteractionSystem.init(entity)
	if interactionCleanup then
		table.insert(connections[entity], { Disconnect = interactionCleanup })
	end

	bindButtons(entity, purchaseService)
end

function Runtime.disconnect(entity: number)
	disconnectButtons(entity)
	purchaseServices[entity] = nil
	local list = connections[entity]
	if list then
		for _, connection in list do
			connection:Disconnect()
		end
		connections[entity] = nil
	end
end

-- Permanently removes a tycoon runtime when its authored model is removed.
-- Normal rebirth/player cleanup intentionally keeps the runtime alive so the
-- same plot can be claimed again.
function Runtime.Destroy(entity: number)
	Runtime.disconnect(entity)
	buildServices[entity] = nil
	local currentModel = model(entity)
	for producerEntity, producer in ECS.world:query(ECS.Components.Producer) do
		if producer.tycoonEntity == entity then
			ECS.deleteEntity(producerEntity)
		end
	end
	for itemEntity, item in ECS.world:query(ECS.Components.BuildItem) do
		if currentModel and item.item and item.item:IsDescendantOf(currentModel) then
			ECS.deleteEntity(itemEntity)
		end
	end
	for buttonEntity, buttonData in ECS.world:query(ECS.Components.Button) do
		if buttonData.tycoonEntity == entity then
			if buttonData.button then
				buttonEntities[buttonData.button] = nil
				purchaseDebounce[buttonData.button] = nil
			end
			ECS.deleteEntity(buttonEntity)
		end
	end
end

return Runtime

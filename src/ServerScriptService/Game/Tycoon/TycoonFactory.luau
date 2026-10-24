--!strict
--[[
	TycoonFactory is the only entry point that turns a Workspace tycoon model
	into ECS data. It never creates a Lua object or stores a facade.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.Shared.Core.ECS)
local World = ECS.world
local Components = ECS.Components

local Factory = {}
local EntityByModel: { [Model]: number } = {}

local function folder(model: Model, name: string): Folder
	return model:WaitForChild(name) :: Folder
end

function Factory.Spawn(model: Model): number
	local existing = EntityByModel[model]
	if existing and World:get(existing, Components.TycoonPlot) then
		return existing
	end

	local mainItems = folder(model, "MainItems")
	local stages = folder(model, "Stages")
	local buttons = folder(model, "Buttons")
	local purchasedItems = folder(model, "PurchasedItems")
	local droppers = folder(model, "Droppers")
	local gunModels = model:FindFirstChild("GunModels") :: Folder?
	local components = model:FindFirstChild("Components") :: Folder?
	local audios = model:FindFirstChild("Audios") :: Folder?
	local atm = mainItems:WaitForChild("ATM")
	local display = atm:FindFirstChild("Display")
	local moneyLabel = display and display:FindFirstChild("SurfaceGui")
	local collectorLabel = moneyLabel and moneyLabel:FindFirstChild("Money")

	local entity = World:entity()
	local state = {
		model = model,
		mainItems = mainItems,
		stages = stages,
		buttons = buttons,
		purchasedItems = purchasedItems,
		droppers = droppers,
		gunModels = gunModels,
		components = components,
		audios = audios,
		collectorDisplayLabel = collectorLabel,
		owner = nil,
		ownerGeneration = 0,
		collectorAmount = 0,
		displayUpdatePending = false,
		cashMultiplier = 1,
		power = false,
		nukeCooldownReady = true,
		active = true,
	}
	local buttonTemplate = buttons:Clone()
	buttonTemplate.Parent = nil
	local hierarchy = {
		MainItems = mainItems,
		Stages = stages,
		Buttons = buttons,
		PurchasedItems = purchasedItems,
		Droppers = droppers,
		GunModels = gunModels,
		Components = components,
		Audios = audios,
		ButtonTemplate = buttonTemplate,
	}

	World:set(entity, Components.Name, model.Name)
	World:set(entity, Components.ModelRef, model)
	World:set(entity, Components.TycoonPlot, true)
	World:set(entity, Components.Hierarchy, hierarchy)
	World:set(entity, Components.Owner, { player = nil, generation = 0 })
	World:set(entity, Components.Collector, { amount = 0, pendingUpdate = false, label = collectorLabel })
	World:set(entity, Components.Upgrades, { x2 = {}, x3 = {}, applied = {} })
	World:set(entity, Components.PurchasedButtons, { lookup = {}, order = {} })
	World:set(entity, Components.NeedsElectricity, true)
	World:set(entity, Components.TycoonState, state)

	EntityByModel[model] = entity
	return entity
end

function Factory.GetEntity(model: Model): number?
	local entity = EntityByModel[model]
	if entity and World:get(entity, Components.TycoonPlot) then
		return entity
	end
	return nil
end

function Factory.GetModel(entity: number): Model?
	return World:get(entity, Components.ModelRef)
end

function Factory.GetHierarchy(entity: number): any?
	return World:get(entity, Components.Hierarchy)
end

function Factory.GetState(entity: number): any?
	return World:get(entity, Components.TycoonState)
end

function Factory.SetOwner(entity: number, player: Player?)
	local state = Factory.GetState(entity)
	local owner = World:get(entity, Components.Owner)
	if not state or not owner then
		return
	end

	owner.generation = (owner.generation or 0) + 1
	owner.player = player
	state.owner = player
	state.ownerGeneration = owner.generation
	World:set(entity, Components.Owner, owner)
	World:set(entity, Components.TycoonState, state)
end

function Factory.Destroy(entity: number)
	local model = Factory.GetModel(entity)
	if model then
		EntityByModel[model] = nil
	end
	World:delete(entity)
end

return table.freeze(Factory)

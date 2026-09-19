--!strict



local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.signal)
local InventoryShared = require(ReplicatedStorage.CharacterUtilities.Inventory.InventoryShared)
local ItemIconRegistry = require(script.Parent.ItemIconRegistry)

local rarityOk, InventoryRarity = pcall(function()
	return require(ReplicatedStorage.CharacterUtilities.Inventory.Rarity)
end)

if not rarityOk then
	warn("[InventoryClient] Inventory rarity classifier failed to load; using safe defaults.", InventoryRarity)
	InventoryRarity = nil
end

local DEBUG_INVENTORY = true

export type Snapshot = InventoryShared.InventorySnapshot & {
	isOpen: boolean,
}

local TOGGLE_KEYS = {
	[Enum.KeyCode.Backquote] = true,
}

local EQUIP_KEYS = {
	[Enum.KeyCode.E] = true,
}

local SLOT_KEYS = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Six] = 6,
	[Enum.KeyCode.Seven] = 7,
	[Enum.KeyCode.Eight] = 8,
}

local InventoryController = {}
InventoryController.__index = InventoryController

local singleton = nil

local function debugPrint(message: string, ...: any)
	if DEBUG_INVENTORY then
		print("[InventoryClient]", message, ...)
	end
end

local function setBackpackEnabled(enabled: boolean)
	task.spawn(function()
		for attempt = 1, 12 do
			local ok = pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, enabled)
			end)

			if ok then
	
				return
			end

			debugPrint("Backpack CoreGui was not ready yet, retrying", attempt)
			task.wait(0.25)
		end

		warn("[InventoryClient] Failed to set Roblox backpack CoreGui after retries.")
	end)
end

function InventoryController.new()
	local self = setmetatable({}, InventoryController)

	self._isOpen = false
	self._items = {}
	self._selectedSlot = 1
	self._maxSlots = InventoryShared.MAX_SLOTS
	self._changed = Signal.new()
	self._started = false
	self._inputConnection = nil
	self._connections = {}
	self._toolSlotByName = {}

	return self
end

local function getToolQuantity(tool: Tool): number
	local quantity = tool:GetAttribute("Quantity")
	if typeof(quantity) == "number" then
		return math.max(1, math.floor(quantity))
	end

	return 1
end

local function toStatNumber(value: any): number?
	if typeof(value) == "number" then
		return value
	end

	if typeof(value) == "table" then
		local total = 0
		local count = 0
		local highest = 0
		for _, entry in pairs(value) do
			if typeof(entry) == "number" then
				total += entry
				count += 1
				highest = math.max(highest, entry)
			end
		end

		if count > 0 then
			return math.max(highest, total / count)
		end
	end

	return nil
end

local function readNumber(source: { [any]: any }?, names: { string }): number?
	if not source then
		return nil
	end

	for _, name in ipairs(names) do
		local value = toStatNumber(source[name])
		if value then
			return value
		end
	end

	return nil
end

local function readToolNumber(tool: Tool, names: { string }): number?
	for _, name in ipairs(names) do
		local value = toStatNumber(tool:GetAttribute(name))
		if value then
			return value
		end
	end

	return nil
end

local function readAcsSettings(tool: Tool): { [any]: any }?
	local settingsModule = tool:FindFirstChild("ACS_Settings")
	if not settingsModule or not settingsModule:IsA("ModuleScript") then
		return nil
	end

	local ok, settings = pcall(require, settingsModule)
	if ok and typeof(settings) == "table" then
		return settings
	end

	return nil
end

local function getWeaponStats(tool: Tool): { [string]: number }?
	local settings = readAcsSettings(tool)
	if not settings and not tool:FindFirstChild("ACS_Settings") and not string.find(string.lower(tool.Name), "gun", 1, true) then
		return nil
	end

	local damage = readToolNumber(tool, { "Damage", "GunDamage", "MaxDamage" })
		or readNumber(settings, { "Damage", "gunDamage", "MaxDamage", "HeadDamage", "TorsoDamage", "LimbsDamage" })
		or 35
	local fireRate = readToolNumber(tool, { "FireRate", "RateOfFire", "RPM" })
		or readNumber(settings, { "FireRate", "fireRate", "ShootRate", "RPM", "MinSpread" })
		or 55
	local accuracy = readToolNumber(tool, { "Accuracy", "Stability" })
		or readNumber(settings, { "Accuracy", "accuracy", "MinSpread", "MaxSpread", "gunRecoil" })
		or 62
	local capacity = readToolNumber(tool, { "Ammo", "Magazine", "AmmoInGun", "MagSize" })
		or readNumber(settings, { "Ammo", "StoredAmmo", "AmmoInGun", "MagSize", "AmmoPerMag" })
		or 30

	if settings then
		local minSpread = readNumber(settings, { "MinSpread" })
		local maxSpread = readNumber(settings, { "MaxSpread" })
		if minSpread or maxSpread then
			local spread = math.max(minSpread or 0, maxSpread or 0)
			accuracy = math.clamp(100 - spread * 12, 5, 100)
		end

		local recoil = readNumber(settings, { "gunRecoil", "Recoil", "Kickback" })
		if recoil then
			accuracy = math.clamp(accuracy - recoil * 5, 1, 100)
		end
	end

	return {
		Damage = math.floor(damage + 0.5),
		["Fire Rate"] = math.floor(fireRate + 0.5),
		Accuracy = math.floor(accuracy + 0.5),
		Capacity = math.floor(capacity + 0.5),
	}
end

local function getPlayerContainers(): (Backpack?, Model?)
	local player = Players.LocalPlayer
	return player:FindFirstChildOfClass("Backpack"), player.Character
end

function InventoryController:_disconnectTrackedSignals()
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end

	table.clear(self._connections)
end

function InventoryController:_connectContainer(container: Instance?)
	if not container then
		return
	end

	table.insert(self._connections, container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			debugPrint("Tool added", child.Name, "container =", container.Name)
			self:_refreshTools()
		end
	end))

	table.insert(self._connections, container.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			debugPrint("Tool removed", child.Name, "container =", container.Name)
			task.defer(function()
				self:_refreshTools()
			end)
		end
	end))
end

function InventoryController:_bindToolContainers()
	local player = Players.LocalPlayer
	self:_disconnectTrackedSignals()

	local backpack, character = getPlayerContainers()
	self:_connectContainer(backpack)
	self:_connectContainer(character)

	table.insert(self._connections, player.CharacterAdded:Connect(function()
		debugPrint("Character added, rebinding tool containers")
		task.defer(function()
			self:_bindToolContainers()
			self:_refreshTools()
		end)
	end))
end

function InventoryController:_getNextSlotForTool(tool: Tool): number?
	local key = tool:GetAttribute("InventoryId")
	if typeof(key) ~= "string" or key == "" then
		key = tool.Name
	end

	local existingSlot = self._toolSlotByName[key]
	if existingSlot then
		return existingSlot
	end

	for slot = 1, self._maxSlots do
		local used = false
		for _, assignedSlot in pairs(self._toolSlotByName) do
			if assignedSlot == slot then
				used = true
				break
			end
		end

		if not used then
			self._toolSlotByName[key] = slot
			return slot
		end
	end

	return nil
end

function InventoryController:_refreshTools()
	local backpack, character = getPlayerContainers()
	local tools = {}

	local function collectTools(container: Instance?, equipped: boolean)
		if not container then
			return
		end

		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(tools, {
					tool = child,
					equipped = equipped,
				})
			end
		end
	end

	collectTools(character, true)
	collectTools(backpack, false)

	table.sort(tools, function(left, right)
		return left.tool.Name < right.tool.Name
	end)

	local items = {}
	for _, entry in ipairs(tools) do
		local tool: Tool = entry.tool
		local slot = self:_getNextSlotForTool(tool)
		if slot then
			local rarity = if InventoryRarity then InventoryRarity.classifyTool(tool) else "Common"
			table.insert(items, {
				id = `{tool.Name}:{slot}`,
				name = tool.Name,
				category = if InventoryRarity then InventoryRarity.classifyCategory(tool) else "Tool",
				rarity = rarity,
				quantity = getToolQuantity(tool),
				slot = slot,
				accent = if InventoryRarity then InventoryRarity.getAccent(tool, rarity) else InventoryShared.RarityColors.Common,
				icon = ItemIconRegistry.getIcon(tool),
				stats = getWeaponStats(tool),
				equipped = entry.equipped,
				source = tool,
			})
		end
	end

	table.sort(items, function(left, right)
		return (left.slot or 0) < (right.slot or 0)
	end)

	self._items = items
	self._changed:Fire()
end

function InventoryController:_getItemForSlot(slot: number): InventoryShared.InventoryItem?
	for _, item in ipairs(self._items) do
		if item.slot == slot then
			return item
		end
	end

	return nil
end

function InventoryController:_equipAndClose(slot: number)
	local item = self:_getItemForSlot(slot)
	if not item then
		debugPrint("No tool to equip in slot", slot)
		return
	end

	local tool = item.source
	if not tool or not tool:IsA("Tool") then
		warn("[InventoryClient] Slot item has no valid Tool source:", item.name)
		return
	end

	local player = Players.LocalPlayer
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[InventoryClient] Could not equip tool because Humanoid is missing.")
		return
	end

	if tool.Parent ~= character then
		humanoid:EquipTool(tool)
		debugPrint("Equipped slot", slot, tool.Name)
	else
		debugPrint("Slot already equipped", slot, tool.Name)
	end

	self:SetOpen(false)
	task.defer(function()
		self:_refreshTools()
	end)
end

function InventoryController:Start()
	if self._started then
		return
	end

	self._started = true
	debugPrint("Starting inventory controller. Toggle key = Backquote / old Roblox backpack key")
	setBackpackEnabled(false)
	self:_bindToolContainers()
	self:_refreshTools()

	self._inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		local isToggleKey = TOGGLE_KEYS[input.KeyCode] == true
		local slot = SLOT_KEYS[input.KeyCode]

		if isToggleKey then
			debugPrint("Toggle input received", input.KeyCode.Name, "gameProcessed =", gameProcessed)
			self:SetOpen(not self._isOpen)
			return
		end

		if slot then
			if not self._isOpen then
				return
			end

			debugPrint("Slot key received", input.KeyCode.Name, "slot =", slot, "gameProcessed =", gameProcessed)
			self:SelectSlot(slot)
			return
		end

		if EQUIP_KEYS[input.KeyCode] then
			if not self._isOpen then
				return
			end

			debugPrint("Equip key received", input.KeyCode.Name, "gameProcessed =", gameProcessed)
			self:EquipSelected()
			return
		end

		if gameProcessed then
			return
		end
	end)
end

function InventoryController:Destroy()
	if self._inputConnection then
		self._inputConnection:Disconnect()
		self._inputConnection = nil
	end

	self:_disconnectTrackedSignals()
end

function InventoryController:SetOpen(isOpen: boolean)
	if self._isOpen == isOpen then
		return
	end

	self._isOpen = isOpen
	debugPrint("Inventory open state changed =", isOpen)
	self._changed:Fire()
end

function InventoryController:SelectSlot(slot: number)
	slot = math.clamp(math.floor(slot), 1, self._maxSlots)
	if self._selectedSlot == slot then
		return
	end

	self._selectedSlot = slot
	debugPrint("Selected slot changed =", slot)
	self._changed:Fire()
end

function InventoryController:ActivateSlot(slot: number)
	slot = math.clamp(math.floor(slot), 1, self._maxSlots)
	self:SelectSlot(slot)
end

function InventoryController:EquipSelected()
	self:_equipAndClose(self._selectedSlot)
end

function InventoryController:UnequipSelected()
	local item = self:_getItemForSlot(self._selectedSlot)
	if not item or item.equipped ~= true then
		debugPrint("No equipped tool to unequip in selected slot", self._selectedSlot)
		return
	end

	local player = Players.LocalPlayer
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("[InventoryClient] Could not unequip tool because Humanoid is missing.")
		return
	end

	humanoid:UnequipTools()
	debugPrint("Unequipped selected slot", self._selectedSlot, item.name)
	self:SetOpen(false)
	task.defer(function()
		self:_refreshTools()
	end)
end

function InventoryController:RemoveSelected()
	local item = self:_getItemForSlot(self._selectedSlot)
	if not item then
		debugPrint("No selected tool to remove")
		return
	end

	local tool = item.source
	if not tool or not tool:IsA("Tool") then
		warn("[InventoryClient] Could not remove selected item because Tool source is missing:", item.name)
		return
	end

	local ok, packets = pcall(function()
		return require(ReplicatedStorage.Network.Packets)
	end)

	if not ok or not packets or not packets.packets or not packets.packets.InventoryAction then
		warn("[InventoryClient] InventoryAction packet is unavailable; server removal could not be requested.", packets)
		return
	end

	debugPrint("Requesting Bytenet remove for", tool.Name)
	packets.packets.InventoryAction.send({
		action = "RemoveTool",
		tool = tool,
	})
end

function InventoryController:GetSnapshot(): Snapshot
	local items = table.create(#self._items)
	for index, item in ipairs(self._items) do
		items[index] = item
	end

	return {
		isOpen = self._isOpen,
		items = items,
		selectedSlot = self._selectedSlot,
		maxSlots = self._maxSlots,
	}
end

function InventoryController:Subscribe(callback: () -> ()): () -> ()
	local connection = self._changed:Connect(callback)
	return function()
		connection:Disconnect()
	end
end

function InventoryController.get() 
	if not singleton then
		singleton = InventoryController.new()
		debugPrint("Created inventory controller singleton")
	end

	return singleton
end

return InventoryController

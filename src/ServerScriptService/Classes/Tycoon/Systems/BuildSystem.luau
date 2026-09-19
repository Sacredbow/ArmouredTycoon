--!strict
--[[
	@class BuildSystem

	@desc
	Manages build item spawning, template caching, state capture/restoration,
	and moved item tracking. Handles the lifecycle of purchased items from
	button purchase through assembly animation to persistent storage.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const BuildAssemble = require(ReplicatedStorage.Libraries.BuildAssemble)

--// Internal Utilities

local function CaptureItemState(Item: Instance): any
	local State = {
		Name = Item.Name,
		ClassName = Item.ClassName,
		Children = {}
	}

	if Item:IsA("Model") then
		State.Pivot = Item:GetPivot()
	elseif Item:IsA("BasePart") then
		State.CFrame = Item.CFrame
		State.Transparency = Item.Transparency
		State.CanCollide = Item.CanCollide
		State.Material = Item.Material
		State.Color = Item.Color
	elseif Item:IsA("Decal") or Item:IsA("Texture") then
		State.Transparency = Item.Transparency
	elseif Item:IsA("BillboardGui") or Item:IsA("SurfaceGui") or Item:IsA("ProximityPrompt") or Item:IsA("ParticleEmitter") or Item:IsA("Beam") then
		State.Enabled = Item.Enabled
	elseif Item:IsA("PointLight") then
		State.Brightness = Item.Brightness
	elseif Item:IsA("Sound") then
		State.Playing = Item.IsPlaying
	end

	for _, Child in Item:GetChildren() do
		table.insert(State.Children, CaptureItemState(Child))
	end

	return State
end

local function RestoreItemState(self: any, Item: Instance, State: any)
	if Item:IsA("Model") and State.Pivot then
		Item:PivotTo(State.Pivot)
	elseif Item:IsA("BasePart") and State.CFrame then
		Item.CFrame = State.CFrame
	end

	if Item:IsA("BasePart") then
		Item.Transparency = State.Transparency or 0
		Item.CanCollide = State.CanCollide or false
		Item.Material = State.Material or Item.Material
		Item.Color = State.Color or Item.Color
	elseif Item:IsA("Decal") or Item:IsA("Texture") then
		Item.Transparency = State.Transparency or 0
	elseif Item:IsA("BillboardGui") or Item:IsA("SurfaceGui") or Item:IsA("ProximityPrompt") or Item:IsA("ParticleEmitter") or Item:IsA("Beam") then
		if State.Enabled ~= nil then
			Item.Enabled = State.Enabled
		end
		if Item:IsA("ProximityPrompt") and State.ActionText ~= nil then
			Item.ActionText = State.ActionText
		end
	elseif Item:IsA("PointLight") then
		if State.Brightness ~= nil then
			Item.Brightness = State.Brightness
		end
	end

	local ItemChildren = Item:GetChildren()
	for Index, ChildState in State.Children do
		local Child = ItemChildren[Index]
		if not Child or Child.Name ~= ChildState.Name or Child.ClassName ~= ChildState.ClassName then
			Child = Item:FindFirstChild(ChildState.Name)
		end

		if Child and Child.ClassName == ChildState.ClassName then
			RestoreItemState(self, Child, ChildState)
		end
	end
end

--// Module

return function(Tycoon: any)
	--// Public API

	function Tycoon:_BuildTemplateCache()
		self.TemplateCache = {}

		for _, Obj in self.Model:GetDescendants() do
			self.TemplateCache[Obj.Name] = Obj
		end
	end

	function Tycoon:_CheckDependencies(Config: any): boolean
		for _, ItemName in Config.Build.Items do
			local Found = self.TemplateCache[ItemName]
			if not Found then
				return false
			end
		end

		return true
	end

	function Tycoon:_SpawnButtonItems(Config: any, Options: any)
		for _, ItemName in Config.Build.Items do
			local Template = self:_FindTemplate(ItemName)
			if Template then
				self:_SpawnItem(Template, Options)
			end
		end
	end

	function Tycoon:_FindTemplate(ItemName: string): Instance?
		local Template = self.Droppers:FindFirstChild(ItemName)
		if Template then
			return Template
		end

		Template = self.GunModels:FindFirstChild(ItemName)
		if Template then
			local Light = Template:FindFirstChild("Light")
			if Light and Light:FindFirstChild("Light") and Light.Light:FindFirstChild("Light") then
				local PointLight = Light.Light.Light:FindFirstChild("PointLight")
				if PointLight then
					PointLight.Brightness = 1
				end
			end
			return Template
		end

		local GamepassFolder = self.MainItems:FindFirstChild("GamepassItems")
		if GamepassFolder then
			Template = GamepassFolder:FindFirstChild(ItemName)
			if Template then
				return Template
			end
		end

		for _, Stage in self.Stages:GetChildren() do
			Template = Stage:FindFirstChild(ItemName, true)
			if Template then
				return Template
			end
		end

		if self.Components then
			Template = self.Components:FindFirstChild(ItemName, true)
			if Template then
				return Template
			end
		end

		warn(`[Tycoon] Template not found for "{ItemName}" in tycoon "{self.Model.Name}"`)
		return nil
	end

	function Tycoon:_SpawnItem(Item: Instance, Options: any?)
		if not Item then
			warn(`[Tycoon] Attempted to spawn a nil item in tycoon "{self.Model.Name}"`)
			return
		end

		if Item:IsA("Model") then
			local BasePartCount = 0
			for _, Descendant in Item:GetDescendants() do
				if Descendant:IsA("BasePart") then
					BasePartCount += 1
				end
			end
			warn(`[Tycoon] Spawning model "{Item.Name}" with {BasePartCount} BaseParts in tycoon "{self.Model.Name}"`)
		else
			warn(`[Tycoon] Spawning instance "{Item.Name}" ({Item.ClassName}) in tycoon "{self.Model.Name}"`)
		end

		self:_CacheMovedItem(Item)
		Item.Parent = self.PurchasedItems

		if Options and Options.buttonConfig then
			local Config = Options.buttonConfig
			if Config.Properties then
				for PartName, Properties in Config.Properties do
					local Part = Item:FindFirstChild(PartName)
					if Part then
						for PropName, PropValue in Properties do
							Part[PropName] = PropValue
						end
					end
				end
			end
		end

		self.ItemEntities[Item] = ECS.createEntity({
			Name = `{self.Model.Name}:{Item.Name}:BuildItem`,
			Model = Item,
			Tycoon = self,
			BuildItem = {
				item = Item,
				templateParent = self.MovedItems[Item] and self.MovedItems[Item].Parent or nil,
				purchasedAt = os.clock()
			}
		})

		if Options and Options.playEffects == false then
			self:_FadeInComplete(Item, 0)
		else
			BuildAssemble.Play(Item, function()
				self:_FadeInComplete(Item, 0)
			end)
		end
	end

	function Tycoon:_CacheMovedItem(Item: Instance)
		if self.MovedItems[Item] then
			return
		end

		self.MovedItems[Item] = {
			Parent = Item.Parent,
			State = CaptureItemState(Item)
		}
	end

	function Tycoon:_RestoreItemFromState(Item: Instance, State: any)
		RestoreItemState(self, Item, State)
	end

	function Tycoon:_RestoreMovedItems()
		local MovedItems = {}
		for Item, RestoreData in self.MovedItems do
			table.insert(MovedItems, { Item = Item, RestoreData = RestoreData })
		end

		for _, Entry in MovedItems do
			local Item = Entry.Item
			local RestoreData = Entry.RestoreData

			if Item and Item.Parent then
				self:_RestoreItemFromState(Item, RestoreData.State)
				Item.Parent = RestoreData.Parent
			end

			local Entity = self.ItemEntities[Item]
			if Entity then
				ECS.deleteEntity(Entity)
				self.ItemEntities[Item] = nil
			end

			self.MovedItems[Item] = nil
		end
	end
end

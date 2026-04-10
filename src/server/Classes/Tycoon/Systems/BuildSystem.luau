local function captureItemState(item)
	local state = {
		Name = item.Name,
		ClassName = item.ClassName,
		Children = {},
	}

	if item:IsA("Model") then
		state.Pivot = item:GetPivot()
	elseif item:IsA("BasePart") then
		state.CFrame = item.CFrame
		state.Transparency = item.Transparency
		state.CanCollide = item.CanCollide
		state.Material = item.Material
		state.Color = item.Color
	elseif item:IsA("Decal") or item:IsA("Texture") then
		state.Transparency = item.Transparency
	elseif item:IsA("BillboardGui") or item:IsA("SurfaceGui") then
		state.Enabled = item.Enabled
	elseif item:IsA("ProximityPrompt") then
		state.Enabled = item.Enabled
		state.ActionText = item.ActionText
	elseif item:IsA("ParticleEmitter") then
		state.Enabled = item.Enabled
	elseif item:IsA("PointLight") then
		state.Brightness = item.Brightness

	elseif item:IsA("Beam") then
		state.Enabled = item.Enabled

	elseif item:IsA("Sound") then
		state.Playing = item.IsPlaying

	
	
	end

	for _, child in ipairs(item:GetChildren()) do
		table.insert(state.Children, captureItemState(child))
	end

	return state
end

local function restoreItemState(self, item, state)
	if item:IsA("Model") and state.Pivot then
		item:PivotTo(state.Pivot)
	elseif item:IsA("BasePart") and state.CFrame then
		item.CFrame = state.CFrame
	end

	if item:IsA("BasePart") then
		item.Transparency = state.Transparency or 0
		item.CanCollide = state.CanCollide or false
		item.Material = state.Material or item.Material
		item.Color = state.Color or item.Color
	elseif item:IsA("Decal") or item:IsA("Texture") then
		item.Transparency = state.Transparency or 0
	elseif item:IsA("BillboardGui") or item:IsA("SurfaceGui") then
		if state.Enabled ~= nil then
			item.Enabled = state.Enabled
		end
	elseif item:IsA("ProximityPrompt") then
		if state.Enabled ~= nil then
			item.Enabled = state.Enabled
		end
		if state.ActionText ~= nil then
			item.ActionText = state.ActionText
		end
	elseif item:IsA("ParticleEmitter") then
		if state.Enabled ~= nil then
			item.Enabled = state.Enabled
		end
	elseif item:IsA("PointLight") then
		if state.Brightness ~= nil then
			item.Brightness = state.Brightness
		end
	end

	local itemChildren = item:GetChildren()
	for index, childState in ipairs(state.Children) do
		local child = itemChildren[index]
		if (not child or child.Name ~= childState.Name or child.ClassName ~= childState.ClassName) then
			child = item:FindFirstChild(childState.Name)
		end

		if child and child.ClassName == childState.ClassName then
			restoreItemState(self, child, childState)
		end
	end
end

return function(Tycoon)
	function Tycoon:_BuildTemplateCache()
		self.TemplateCache = {}

		for _, obj in ipairs(self.Model:GetDescendants()) do
			self.TemplateCache[obj.Name] = obj
		end
	end

	function Tycoon:_CheckDependencies(button)
		local dependenciesFolder = button:FindFirstChild("Dependencies")
		local singleDep = button:FindFirstChild("Dependency")

		local required = {}

		if dependenciesFolder then
			for _, dep in ipairs(dependenciesFolder:GetChildren()) do
				if dep:IsA("StringValue") then
					table.insert(required, dep.Value)
				end
			end
		elseif singleDep then
			table.insert(required, singleDep.Value)
		end

		for _, itemName in ipairs(required) do
			local found = self.TemplateCache[itemName]

			if not found then
				return false
			end
		end

		return true
	end

	function Tycoon:_SpawnButtonItems(button)
		local dependenciesFolder = button:FindFirstChild("Dependencies")
		local singleDep = button:FindFirstChild("Dependency")

		local items = {}

		if dependenciesFolder then
			for _, dep in ipairs(dependenciesFolder:GetChildren()) do
				if dep:IsA("StringValue") then
					table.insert(items, dep.Value)
				end
			end
		elseif singleDep then
			table.insert(items, singleDep.Value)
		end

		for _, itemName in ipairs(items) do
			local template = self:_FindTemplate(itemName)
			if template then
				self:_SpawnItem(template)
			else
				print(" Template not found:", itemName)
			end
		end
	end

	function Tycoon:_FindTemplate(itemName)
		local template = self.Droppers:FindFirstChild(itemName)
		if template then
			return template
		end

		template = self.GunModels:FindFirstChild(itemName)
		if template then
			local light = template:FindFirstChild("Light")
			if light and light:FindFirstChild("Light") and light.Light:FindFirstChild("Light") then
				local pointLight = light.Light.Light:FindFirstChild("PointLight")
				if pointLight then
					pointLight.Brightness = 1
				end
			end
			return template
		end

		local gamepassFolder = self.MainItems:FindFirstChild("GamepassItems")
		if gamepassFolder then
			template = gamepassFolder:FindFirstChild(itemName)
			if template then
				return template
			end
		end

		for _, stage in ipairs(self.Stages:GetChildren()) do
			template = stage:FindFirstChild(itemName, true)
			if template then
				return template
			end
		end

		if self.Components then
			template = self.Components:FindFirstChild(itemName, true)
			if template then
				return template
			end
		end

		warn(`[Tycoon] Template not found for "{itemName}" in tycoon "{self.Model.Name}"`)
		return nil
	end

	function Tycoon:_SpawnItem(item)
		if not item then
			warn(`[Tycoon] Attempted to spawn a nil item in tycoon "{self.Model.Name}"`)
			return
		end

		if item:IsA("Model") then
			local basePartCount = 0
			for _, descendant in ipairs(item:GetDescendants()) do
				if descendant:IsA("BasePart") then
					basePartCount += 1
				end
			end

			warn(`[Tycoon] Spawning model "{item.Name}" with {basePartCount} BaseParts in tycoon "{self.Model.Name}"`)
		else
			warn(`[Tycoon] Spawning instance "{item.Name}" ({item.ClassName}) in tycoon "{self.Model.Name}"`)
		end

		self:_CacheMovedItem(item)
		item.Parent = self.PurchasedItems

		task.spawn(function()
			self:_FadeInComplete(item)
		end)
	end

	function Tycoon:_CacheMovedItem(item)
		if self.MovedItems[item] then
			return
		end

		self.MovedItems[item] = {
			Parent = item.Parent,
			State = captureItemState(item),
		}
	end

	function Tycoon:_RestoreItemFromState(item, state)
		restoreItemState(self, item, state)
	end

	function Tycoon:_RestoreMovedItems()
		local movedItems = {}
		for item, restoreData in self.MovedItems do
			table.insert(movedItems, { Item = item, RestoreData = restoreData })
		end

		for _, entry in ipairs(movedItems) do
			local item = entry.Item
			local restoreData = entry.RestoreData

			if item and item.Parent then
				self:_RestoreItemFromState(item, restoreData.State)
				item.Parent = restoreData.Parent
			end

			self.MovedItems[item] = nil
		end
	end
end

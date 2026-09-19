--[[
	Sacredbow1 Tween Module
	Complete rewrite & optimization
	Handles models, UI, parts, camera, chains, parallel tweens.
]]

local RobloxTweenService = game:GetService("TweenService")

local Module = {}
Module.__index = Module


function Module.BasePart(part, properties, tweenInfo, callback: () -> ()?)
	assert(part:IsA("BasePart"), "BasePart: first argument must be a BasePart")
	assert(type(properties) == "table", "BasePart: properties must be a table")

	local tween = RobloxTweenService:Create(part, tweenInfo, properties)

	if callback then
		tween.Completed:Connect(callback)
	end

	tween:Play()
	return tween
end


function Module.Interface(guiObject: GuiBase, properties : {Enum.EasingStyle & Enum.EasingDirection}, tweenInfo : TweenInfo, callback: () -> ()?)
	assert(guiObject:IsA("GuiObject"), "Interface: first argument must be a GuiObject")
	assert(type(properties) == "table", "Interface: properties must be a table")

	local tween = RobloxTweenService:Create(guiObject, tweenInfo, properties)

	if callback then
		tween.Completed:Connect(callback)
	end

	tween:Play()
	return tween
end


function Module.Tween(instance, properties, tweenInfo, callback: () -> ()?)
	assert(typeof(instance) == "Instance", "Tween: first argument must be an Instance")
	assert(type(properties) == "table", "Tween: properties must be a table")

	local tween = RobloxTweenService:Create(instance, tweenInfo, properties)

	if callback then
		tween.Completed:Connect(callback)
	end

	tween:Play()
	return tween
end


function Module.Model(model : Model, targetCFrame : CFrame, tweenInfo : TweenInfo, callback: () -> ()?)
	assert(model:IsA("Model"), "Model: first argument must be a Model")
	assert(model.PrimaryPart, "Model: Model must have a PrimaryPart")
	assert(typeof(targetCFrame) == "CFrame", "Model: targetCFrame must be a CFrame")

	local start = model.PrimaryPart.CFrame

	local alpha = Instance.new("NumberValue")
	alpha.Value = 0

	local tween = RobloxTweenService:Create(alpha, tweenInfo, {Value = 1})

	local connection
	connection = alpha.Changed:Connect(function(v)
		if not model.Parent then
			connection:Disconnect()
			alpha:Destroy()
			return
		end

		local newCF = start:Lerp(targetCFrame, v)
		model:PivotTo(newCF)
	end)

	tween.Completed:Connect(function(state)
		connection:Disconnect()
        connection = nil
		alpha:Destroy()
		if callback then
			callback(state)
		end

	end)

	tween:Play()

	return {
		Tween = tween,
		Cancel = function(self)
			tween:Cancel()
			connection:Disconnect()
            connection = nil
			alpha:Destroy()
		end,
		Pause = function(self)
			tween:Pause()
		end,
		Play = function(self)
			tween:Play()
		end
	}
end


function Module.ModelTransparency(model, targetTransparency, tweenInfo, callback)
	assert(model:IsA("Model"), "ModelTransparency: first argument must be a Model")

	local tweens = {}
	local total = 0
	local completed = 0

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
			total += 1
		end
	end

	for _, obj in ipairs(model:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
			local tween = RobloxTweenService:Create(obj, tweenInfo, {Transparency = targetTransparency})
			tween.Completed:Connect(function()
				completed += 1
				if completed == total and callback then
					callback()
				end
			end)
			tween:Play()
			table.insert(tweens, tween)
		end
	end

	return {
		Tweens = tweens,
		Cancel = function(self)
			for _, t in ipairs(tweens) do t:Cancel() end
		end,
		Pause = function(self)
			for _, t in ipairs(tweens) do t:Pause() end
		end,
		Play = function(self)
			for _, t in ipairs(tweens) do t:Play() end
		end
	}
end


function Module.Camera(camera, targetCFrame, tweenInfo, callback)
	assert(camera:IsA("Camera"), "Camera: first argument must be a Camera")

	local tween = RobloxTweenService:Create(camera, tweenInfo, {CFrame = targetCFrame})

	if callback then tween.Completed:Connect(callback) end

	tween:Play()
	return tween
end


function Module.DataList(list, finalCallback)
	assert(type(list) == "table", "DataList: list must be a table")

	local index = 1
	local controller = { Cancelled = false }

	local function playNext()
		if controller.Cancelled then return end
		if index > #list then
			if finalCallback then finalCallback() end
			return
		end

		local data = list[index]
		local inst, props, info = data[1], data[2], data[3]

		local tween = RobloxTweenService:Create(inst, info, props)
		tween.Completed:Connect(function()
			index += 1
			playNext()
		end)
		tween:Play()
	end

	task.defer(playNext)

	function controller:Cancel()
		controller.Cancelled = true
	end

	return controller
end


function Module.Parallel(list, finalCallback)
	assert(type(list) == "table", "Parallel: list must be a table")

	local total = #list
	local completed = 0
	local tweens = {}

	for _, data in ipairs(list) do
		local inst, props, info = data[1], data[2], data[3]
		local tween = RobloxTweenService:Create(inst, info, props)

		tween.Completed:Connect(function()
			completed += 1
			if completed == total and finalCallback then
				finalCallback()
			end
		end)

		table.insert(tweens, tween)
		tween:Play()
	end

	return {
		Tweens = tweens,
		Cancel = function(self)
			for _, t in ipairs(tweens) do t:Cancel() end
		end,
		Pause = function(self)
			for _, t in ipairs(tweens) do t:Pause() end
		end,
		Play = function(self)
			for _, t in ipairs(tweens) do t:Play() end
		end
	}
end

Module.EasePresets = {
	Fast = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Normal = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	Slow = TweenInfo.new(1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
	Bounce = TweenInfo.new(0.5, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
	Elastic = TweenInfo.new(0.8, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out),
	Smooth = TweenInfo.new(0.4, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut),
}

return Module

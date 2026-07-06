--!strict

--[[
	AttachmentController

	Builds weapon attachments onto the cloned first-person/third-person gun model.
	ACS attachments are authored as separate models/modules, so this controller
	bridges three things:
		1. clone the visual model
		2. weld it to the weapon handle
		3. apply stat modifiers to the active modifier table

	The returned AttachmentResult is intentionally plain data. Main only needs the
	flags it uses later: suppressor, flash hider, bipod, laser/torch availability,
	infrared support, reticle reference, and cloned attachment instances.
]]

local AttachmentModifiers = require(script.Parent:WaitForChild("AttachmentModifiers"))

type AttachmentFolder = Instance & {
	[string]: Instance,
}

export type WeaponData = {
	SightAtt: string,
	BarrelAtt: string,
	UnderBarrelAtt: string,
	OtherAtt: string,
}

export type AttachmentResult = {
	sight: Model?,
	barrel: Model?,
	underBarrel: Model?,
	other: Model?,
	reticle: Instance?,
	suppressor: boolean,
	flashHider: boolean,
	laser: boolean,
	torch: boolean,
	infrared: boolean,
	bipod: boolean,
}

local AttachmentController = {}

local function requireModule<T>(modules: Instance, name: string): T?
	-- Attachments are optional/user-authored. A bad attachment should warn and
	-- fail soft rather than making the weapon impossible to equip.
	local moduleScript = modules:FindFirstChild(name)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		return nil
	end

	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn(("[ACS] Failed to load attachment module %s: %s"):format(name, tostring(result)))
		return nil
	end

	return result :: T
end

local function cloneAttachment<T>(models: Instance, name: string): T?
	-- Visual attachment models live beside their config modules under ACS_Engine.
	local attachmentModel = models:FindFirstChild(name)
	if not attachmentModel then
		return nil
	end

	return attachmentModel:Clone() :: any
end

local function weldParts(model: Instance, handle: BasePart, utilities: any)
	-- ACS weapons use physical parts for sights/barrels. Once welded, every part
	-- must be unanchored and non-collidable so it follows the weapon cleanly.
	for _, child in model:GetChildren() do
		if not child:IsA("BasePart") then
			continue
		end

		utilities.Weld(handle, child)
		child.Anchored = false
		child.CanCollide = false
	end
end

local function blankIsParts(weapon: Model)
	-- "IS" parts are the original iron-sight pieces. Custom sights hide them.
	for _, child in weapon:GetChildren() do
		if child.Name == "IS" and child:IsA("BasePart") then
			child.Transparency = 1
		end
	end
end

local function getNode(weapon: Model, nodeName: string): BasePart?
	local nodes = weapon:FindFirstChild("Nodes")
	if not nodes then
		return nil
	end

	local node = nodes:FindFirstChild(nodeName)
	if node and node:IsA("BasePart") then
		return node
	end

	return nil
end

local function getHandle(weapon: Model): BasePart?
	local handle = weapon:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end

	return nil
end

function AttachmentController.resetModifiers(modifierTable: any)
	AttachmentModifiers.reset(modifierTable)
end

function AttachmentController.applyModifiers(modifierTable: any, modifierData: any)
	AttachmentModifiers.apply(modifierTable, modifierData)
end

function AttachmentController.load(
	weapon: Model?,
	weaponData: WeaponData,
	modifierTable: any,
	attachmentModels: AttachmentFolder,
	attachmentModules: AttachmentFolder,
	utilities: any
): AttachmentResult
	-- Loading is linear on purpose: later attachments can depend on earlier
	-- weapon changes, especially sights changing AimPart and barrels moving Muzzle.
	local result: AttachmentResult = {
		sight = nil,
		barrel = nil,
		underBarrel = nil,
		other = nil,
		reticle = nil,
		suppressor = false,
		flashHider = false,
		laser = false,
		torch = false,
		infrared = false,
		bipod = false,
	}

	if not weapon or not weapon:FindFirstChild("Nodes") then
		return result
	end

	local handle = getHandle(weapon)
	if not handle then
		return result
	end

	local sightNode = getNode(weapon, "Sight")
	if sightNode and weaponData.SightAtt ~= "" then
		local sightData: any = requireModule(attachmentModules, weaponData.SightAtt)
		local sightModel = cloneAttachment(attachmentModels, weaponData.SightAtt) :: Model?

		if sightData and sightModel then
			sightModel.Parent = weapon
			sightModel:SetPrimaryPartCFrame(sightNode.CFrame)

			local aimPart = weapon:FindFirstChild("AimPart")
			local aimPos = sightModel:FindFirstChild("AimPos")
			if aimPart and aimPart:IsA("BasePart") and aimPos and aimPos:IsA("BasePart") then
				aimPart.CFrame = aimPos.CFrame
			end

			local sightMark = sightModel:FindFirstChild("SightMark")
			local surfaceGui = sightMark and sightMark:FindFirstChild("SurfaceGui")
			local border = surfaceGui and surfaceGui:FindFirstChild("Border")
			result.reticle = border and border:FindFirstChild("Scope") or nil

			if sightData.SightZoom and sightData.SightZoom > 0 then
				modifierTable.ZoomValue = sightData.SightZoom
			end
			if sightData.SightZoom2 and sightData.SightZoom2 > 0 then
				modifierTable.Zoom2Value = sightData.SightZoom2
			end

			AttachmentModifiers.apply(modifierTable, sightData)
			blankIsParts(weapon)
			weldParts(sightModel, handle, utilities)
			result.sight = sightModel
		end
	end

	local barrelNode = getNode(weapon, "Barrel")
	if barrelNode and weaponData.BarrelAtt ~= "" then
		local barrelData: any = requireModule(attachmentModules, weaponData.BarrelAtt)
		local barrelModel = cloneAttachment(attachmentModels, weaponData.BarrelAtt) :: Model?

		if barrelData and barrelModel then
			barrelModel.Parent = weapon
			barrelModel:SetPrimaryPartCFrame(barrelNode.CFrame)

			local barrelPos = barrelModel:FindFirstChild("BarrelPos")
			local muzzle = handle:FindFirstChild("Muzzle")
			if barrelPos and barrelPos:IsA("BasePart") and muzzle and muzzle:IsA("Attachment") then
				muzzle.WorldCFrame = barrelPos.CFrame
			end

			result.suppressor = barrelData.IsSuppressor == true
			result.flashHider = barrelData.IsFlashHider == true

			AttachmentModifiers.apply(modifierTable, barrelData)
			weldParts(barrelModel, handle, utilities)
			result.barrel = barrelModel
		end
	end

	local underBarrelNode = getNode(weapon, "UnderBarrel")
	if underBarrelNode and weaponData.UnderBarrelAtt ~= "" then
		local underBarrelData: any = requireModule(attachmentModules, weaponData.UnderBarrelAtt)
		local underBarrelModel = cloneAttachment(attachmentModels, weaponData.UnderBarrelAtt) :: Model?

		if underBarrelData and underBarrelModel then
			underBarrelModel.Parent = weapon
			underBarrelModel:SetPrimaryPartCFrame(underBarrelNode.CFrame)

			AttachmentModifiers.apply(modifierTable, underBarrelData)
			result.bipod = underBarrelData.IsBipod == true

			weldParts(underBarrelModel, handle, utilities)
			result.underBarrel = underBarrelModel
		end
	end

	local otherNode = getNode(weapon, "Other")
	if otherNode and weaponData.OtherAtt ~= "" then
		local otherData: any = requireModule(attachmentModules, weaponData.OtherAtt)
		local otherModel = cloneAttachment(attachmentModels, weaponData.OtherAtt) :: Model?

		if otherData and otherModel then
			otherModel.Parent = weapon
			otherModel:SetPrimaryPartCFrame(otherNode.CFrame)

			AttachmentModifiers.apply(modifierTable, otherData)
			result.laser = otherData.EnableLaser == true
			result.torch = otherData.EnableFlashlight == true
			result.infrared = otherData.InfraRed == true

			weldParts(otherModel, handle, utilities)
			result.other = otherModel
		end
	end

	return result
end

return AttachmentController

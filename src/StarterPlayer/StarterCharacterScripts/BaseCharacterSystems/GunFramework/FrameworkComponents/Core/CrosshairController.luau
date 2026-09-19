--!strict
--[[
	@class CrosshairController

	@desc
	Manages the manual crosshair ScreenGui fallback and publishes
	crosshair state to the React-based WeaponUIState bridge.
]]

--// Modules

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponUIState = require(script.Parent.Parent.UI.WeaponUIState)
local RuntimeSettings = require(ReplicatedStorage.Modules.SettingsManager.RuntimeSettings)

local CrosshairController = {}
CrosshairController.__index = CrosshairController

export type CrosshairController = typeof(setmetatable({} :: {
	_player: Player,
	_gui: ScreenGui?,
	_lastState: string,
}, CrosshairController))

function CrosshairController.new(player: Player): CrosshairController
	return setmetatable({
		_player = player,
		_gui = nil,
		_lastState = "",
	}, CrosshairController)
end

function CrosshairController:ensure()
	if self._gui then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ACSManualCrosshair"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 90
	gui.Parent = self._player:WaitForChild("PlayerGui")

	local image = Instance.new("ImageLabel")
	image.Name = "Crosshair"
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromOffset(34, 34)
	image.BackgroundTransparency = 1
	image.Image = "rbxassetid://108394139789219"
	image.ImageColor3 = Color3.fromRGB(255, 255, 255)
	image.ImageTransparency = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = gui

	local fallback = Instance.new("Frame")
	fallback.Name = "FallbackLines"
	fallback.AnchorPoint = Vector2.new(0.5, 0.5)
	fallback.Position = UDim2.fromScale(0.5, 0.5)
	fallback.Size = UDim2.fromOffset(18, 18)
	fallback.BackgroundTransparency = 1
	fallback.Visible = false
	fallback.Parent = gui

	local function line(name: string, position: UDim2, size: UDim2)
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = position
		frame.Size = size
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		frame.Parent = fallback
	end

	line("Top", UDim2.fromScale(0.5, 0.1), UDim2.fromOffset(1, 8))
	line("Bottom", UDim2.fromScale(0.5, 0.9), UDim2.fromOffset(1, 8))
	line("Left", UDim2.fromScale(0.1, 0.5), UDim2.fromOffset(8, 1))
	line("Right", UDim2.fromScale(0.9, 0.5), UDim2.fromOffset(8, 1))

	task.delay(1.5, function()
		if image.Parent and not image.IsLoaded then
			fallback.Visible = true
			image.Visible = false
		end
	end)

	self._gui = gui
end

function CrosshairController:destroy()
	if self._gui then
		self._gui:Destroy()
		self._gui = nil
	end
end

function CrosshairController:update(weaponData: any, toolEquip: boolean, aiming: boolean, weaponName: string)
	local isThird = self:_isThirdPerson()
	local active = toolEquip
		and weaponData
		and weaponData.Type == "Gun"
		and not (aiming and self:_isSniper(weaponData, weaponName))

	local state = if active
		then `active:{if self:_isShotgun(weaponData, weaponName) then "shotgun" else "rifle"}:{if isThird then "third" else "first"}`
		else "hidden"

	if self._lastState ~= state then
		self._lastState = state
	end

	local shotgun = self:_isShotgun(weaponData, weaponName)
	WeaponUIState.publishCrosshair(self._player, {
		visible = active == true,
		kind = if active and shotgun then "shotgun" elseif active then "rifle" else "none",
		mode = if isThird then "third" else "first",
	})

	if active and isThird then
		self:ensure()
	else
		self:destroy()
	end
end

function CrosshairController:clear()
	self._lastState = ""
	self:destroy()
	WeaponUIState.publishCrosshair(self._player, {
		visible = false,
		kind = "none",
		mode = "third",
	})
end

--// Internal Helpers

function CrosshairController:_isThirdPerson(): boolean
	local ok, val = pcall(function()
		return RuntimeSettings.GetBoolean("Third Person", true)
	end)
	if ok and typeof(val) == "boolean" then
		return val
	end
	return self._player.CameraMode == Enum.CameraMode.Classic
end

function CrosshairController:_isShotgun(weaponData: any, weaponName: string): boolean
	if not weaponData then
		return false
	end

	if weaponData.WeaponType == "Shotgun" or weaponData.Shotgun == true then
		return true
	end

	local lowerName = weaponName:lower()
	return string.find(lowerName, "shotgun", 1, true) ~= nil
		or string.find(lowerName, "spas", 1, true) ~= nil
		or string.find(lowerName, "mossberg", 1, true) ~= nil
end

function CrosshairController:_isSniper(weaponData: any, weaponName: string): boolean
	if not weaponData then
		return false
	end

	local lowerName = weaponName:lower()
	if weaponData.Sniper == true or weaponData.WeaponType == "Sniper" then
		return true
	end

	if string.find(lowerName, "sniper", 1, true)
		or string.find(lowerName, "barrett", 1, true)
		or string.find(lowerName, "awm", 1, true)
		or string.find(lowerName, "m82", 1, true)
		or string.find(lowerName, "kar98", 1, true) then
		return true
	end

	return typeof(weaponData.Zoom) == "number" and weaponData.Zoom <= 25 and not self:_isShotgun(weaponData, weaponName)
end

return CrosshairController

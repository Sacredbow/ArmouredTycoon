--!strict

--[[
	StatusEffectsGui

	Creates the legacy ACS StatusUI and returns the health overlay tweens. Keeping
	this clone/setup logic outside Main avoids mixing weapon equip code with HUD
	bootstrapping.
]]

local TweenService = game:GetService("TweenService")

local StatusEffectsGui = {}

export type StatusEffects = {
	gui: ScreenGui,
	healthPulse: Tween,
	lowHealthPulse: Tween,
}

function StatusEffectsGui.create(playerGui: PlayerGui, hudFolder: Instance): StatusEffects
	-- StatusUI is cloned per-player because it contains player-local overlays and
	-- the legacy GunHUD frame used by the current weapon UI.
	local gui = hudFolder:WaitForChild("StatusUI"):Clone()
	gui.Parent = playerGui

	local gunHud = gui:FindFirstChild("GunHUD")
	if gunHud and gunHud:IsA("GuiObject") then
		gunHud.Visible = false
	end

	local grenadeForce = gui:FindFirstChild("GrenadeForce")
	if grenadeForce and grenadeForce:IsA("GuiObject") then
		grenadeForce.Visible = false
	end

	local effects = gui:WaitForChild("Efeitos")
	local health = effects:WaitForChild("Health") :: GuiObject
	local lowHealth = effects:WaitForChild("LowHealth") :: GuiObject

	return {
		gui = gui :: ScreenGui,
		healthPulse = TweenService:Create(
			health,
			TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, -1, true),
			{ Size = UDim2.new(1.2, 0, 1.4, 0) }
		),
		lowHealthPulse = TweenService:Create(
			lowHealth,
			TweenInfo.new(1, Enum.EasingStyle.Circular, Enum.EasingDirection.InOut, -1, true),
			{ Size = UDim2.new(1.2, 0, 1.4, 0) }
		),
	}
end

return StatusEffectsGui

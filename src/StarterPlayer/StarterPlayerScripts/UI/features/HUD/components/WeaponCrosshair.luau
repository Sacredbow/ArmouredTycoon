--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ClientRuntimeState = require(ReplicatedStorage.Modules.ClientRuntimeState)

local useSpringBinding = require(script.Parent.Parent.Parent.Parent.hooks.useSpringBinding)

local e = React.createElement

local RIFLE_CROSSHAIR = "rbxassetid://108394139789219"
local SHOTGUN_CROSSHAIR = "rbxassetid://75765071307936"

type CrosshairState = {
	visible: boolean,
	kind: string,
	mode: string,
	aiming: boolean,
}

local function readState(player: Player): CrosshairState
	local weaponState = ClientRuntimeState.ReadWeaponState(player)
	return {
		visible = weaponState.CrosshairVisible,
		kind = weaponState.CrosshairKind,
		mode = weaponState.CrosshairMode,
		aiming = weaponState.Aiming,
	}
end

local function WeaponCrosshair()
	local player = Players.LocalPlayer
	local state, setState = React.useState(function()
		return readState(player)
	end)

	React.useEffect(function()
		local connection = ClientRuntimeState.ObserveWeaponState(player, function(nextState)
			setState({
				visible = nextState.CrosshairVisible,
				kind = nextState.CrosshairKind,
				mode = nextState.CrosshairMode,
				aiming = nextState.Aiming,
			})
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	local targetVisible = if state.visible then 1 else 0
	local alpha = useSpringBinding(targetVisible, 18, targetVisible)
	local isShotgun = state.kind == "shotgun"
	local baseSize = if isShotgun then 82 else 54
	local aimTighten = if state.aiming and state.mode == "third" then 0.9 else 1
	local image = if isShotgun then SHOTGUN_CROSSHAIR else RIFLE_CROSSHAIR

	return e("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 900,
	}, {
		Crosshair = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = image,
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ImageTransparency = alpha:map(function(value: number)
				return 1 - value
			end),
			Position = UDim2.fromScale(0.5, 0.5),
			ScaleType = Enum.ScaleType.Fit,
			Size = alpha:map(function(value: number)
				local pop = 0.92 + value * 0.08
				return UDim2.fromOffset(baseSize * aimTighten * pop, baseSize * aimTighten * pop)
			end),
			ZIndex = 901,
		}, {
			Aspect = e("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
		}),
	})
end

return WeaponCrosshair

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local useSpringBinding = require(script.Parent.Parent.hooks.useSpringBinding)

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
	return {
		visible = player:GetAttribute("ACS_CrosshairVisible") == true,
		kind = tostring(player:GetAttribute("ACS_CrosshairKind") or "rifle"),
		mode = tostring(player:GetAttribute("ACS_CrosshairMode") or "first"),
		aiming = player:GetAttribute("ACS_Aiming") == true,
	}
end

local function WeaponCrosshair()
	local player = Players.LocalPlayer
	local state, setState = React.useState(function()
		return readState(player)
	end)

	React.useEffect(function()
		local function refresh()
			setState(readState(player))
		end

		local connections = {
			player:GetAttributeChangedSignal("ACS_CrosshairVisible"):Connect(refresh),
			player:GetAttributeChangedSignal("ACS_CrosshairKind"):Connect(refresh),
			player:GetAttributeChangedSignal("ACS_CrosshairMode"):Connect(refresh),
			player:GetAttributeChangedSignal("ACS_Aiming"):Connect(refresh),
		}

		refresh()

		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
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

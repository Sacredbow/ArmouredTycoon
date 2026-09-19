--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local DEFAULT_VIEWPORT = Vector2.new(1280, 720)

local function GetViewport(): Vector2
	local Camera = Workspace.CurrentCamera
	if Camera then
		return Camera.ViewportSize
	end

	return DEFAULT_VIEWPORT
end

local function GetScale(Viewport: Vector2): number
	local WidthScale = Viewport.X / 760
	local HeightScale = Viewport.Y / 620

	return math.clamp(math.min(WidthScale, HeightScale), 0.42, 1)
end

local function useViewportScale(): number
	local Scale, SetScale = React.useState(GetScale(GetViewport()))

	React.useEffect(function()
		local Connections: { RBXScriptConnection } = {}

		local function Update()
			SetScale(GetScale(GetViewport()))
		end

		local function Watch(Camera: Camera?)
			if Camera then
				table.insert(Connections, Camera:GetPropertyChangedSignal("ViewportSize"):Connect(Update))
			end
		end

		Watch(Workspace.CurrentCamera)
		table.insert(
			Connections,
			Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
				Watch(Workspace.CurrentCamera)
				Update()
			end)
		)
		Update()

		return function()
			for _, Connection in Connections do
				Connection:Disconnect()
			end
		end
	end, {})

	return Scale
end

return useViewportScale

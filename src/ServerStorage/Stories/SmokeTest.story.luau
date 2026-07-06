--!strict

local function story(target: Frame)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.BackgroundColor3 = Color3.fromRGB(28, 31, 37)
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = UDim2.fromOffset(360, 96)
	label.Text = "UI Labs preview is working"
	label.TextColor3 = Color3.fromRGB(245, 247, 250)
	label.TextSize = 22
	label.Parent = target

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(184, 121, 70)
	stroke.Thickness = 2
	stroke.Parent = label

	return function()
		label:Destroy()
	end
end

return story

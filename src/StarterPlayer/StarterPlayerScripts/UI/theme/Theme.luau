--!strict

return {
	Colors = {
		Panel = Color3.fromRGB(14, 18, 24),
		PanelRaised = Color3.fromRGB(24, 30, 38),
		Stroke = Color3.fromRGB(82, 96, 116),
		Text = Color3.fromRGB(242, 246, 250),
		MutedText = Color3.fromRGB(162, 174, 188),
		Cash = Color3.fromRGB(96, 230, 140),
		Emerald = Color3.fromRGB(67, 225, 205),
		Kills = Color3.fromRGB(255, 102, 102),
		Rebirths = Color3.fromRGB(255, 206, 92),
	},

	Fonts = {
		Display = Enum.Font.GothamBold,
		Body = Enum.Font.GothamMedium,
		Number = Enum.Font.GothamBold,
	},

	Tween = {
		Snappy = TweenInfo.new(0.18, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		Smooth = TweenInfo.new(0.28, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		Soft = TweenInfo.new(0.42, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out),
	},
}

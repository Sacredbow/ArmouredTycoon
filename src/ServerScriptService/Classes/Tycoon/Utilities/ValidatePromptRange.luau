

return function(Player: Player, Prompt: ProximityPrompt): boolean

	if not Prompt.Enabled then
		return false
	end

	local Character = Player.Character
	local Root = Character and Character:FindFirstChild("HumanoidRootPart")
	local PromptPart = Prompt:FindFirstAncestorWhichIsA("BasePart")
	if not Root or not Root:IsA("BasePart") or not PromptPart then
		return false
	end

	return ((Root :: BasePart).Position - PromptPart.Position).Magnitude <= Prompt.MaxActivationDistance + 4
end

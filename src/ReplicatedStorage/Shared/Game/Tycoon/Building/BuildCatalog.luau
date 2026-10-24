local BuildCatalog = {}

BuildCatalog.DefaultTier = "Bronze"

BuildCatalog.Items = {
	Wood = {
		Id = "Wood",
		DisplayName = "Wood Wall",
		Category = "Defense",
		Footprint = {
			Cells = {
				Vector2.new(0, 0),
			},
		},
		Tiers = {
			Bronze = {
				Cost = 125,
				RefundRate = 0.5,
				Health = 150,
				ModelName = "Wood",
			},
			Silver = {
				Cost = 325,
				RefundRate = 0.5,
				Health = 260,
				ModelName = "Wood",
			},
			Gold = {
				Cost = 700,
				RefundRate = 0.5,
				Health = 420,
				ModelName = "Wood",
			},
		},
	},
}

function BuildCatalog:Get(buildId: string)
	return self.Items[buildId]
end

function BuildCatalog:GetTier(buildId: string, tier: string?)
	local definition = self:Get(buildId)
	if not definition then
		return nil
	end

	return definition.Tiers[tier or self.DefaultTier]
end

return BuildCatalog

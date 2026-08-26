--!strict
--[[
	@class AppearanceSystem

	@desc
	Applies the tycoon's colour palette to all tagged BaseParts in Stages
	and GunModels. CollectionService tags: "Primary" / "Secondary" / "Accent".
	The first matching tag wins for each part.
]]

--// Services

const CollectionService = game:GetService("CollectionService")

--// Modules

const ColorConfiguration = require(script.Parent.Parent.Parent.Configuration.ColorConfiguration)

--// Types

type StagePalette = {
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
}

--// Constants

const StagePalletts: { [string]: StagePalette } = {
	Tycoon1 = ColorConfiguration.White,
	Tycoon2 = ColorConfiguration.Blue,
	Tycoon3 = ColorConfiguration.Black,
	Tycoon4 = ColorConfiguration.Green,
	Tycoon5 = ColorConfiguration.Grey,
	Tycoon6 = ColorConfiguration.Red,
	Tycoon7 = ColorConfiguration.Yellow,
	Tycoon8 = ColorConfiguration.Purple,
}

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Public API

	function Tycoon.ApplyColors(self)
		const Palette: StagePalette? = StagePalletts[self.Model.Name]
		if not Palette then
			warn(`[Tycoon] No stage palette configured for "{self.Model.Name}"`)
			return
		end

		const TagColors: { [string]: Color3 } = {
			Primary = Palette.Primary,
			Secondary = Palette.Secondary,
			Accent = Palette.Accent,
		}

		-- Colour all tagged BaseParts in the Stages folder.
		for _, Descendant in self.Stages:GetDescendants() do
			if not Descendant:IsA("BasePart") then
				continue
			end
			for TagName, Color in TagColors do
				if CollectionService:HasTag(Descendant, TagName) then
					Descendant.Color = Color
					break
				end
			end
		end

		-- Some gun models have a Folder named "Structure" containing coloured parts.
		for _, Descendant in self.GunModels:GetDescendants() do
			if Descendant:IsA("Folder") and Descendant.Name == "Structure" then
				for _, BasePart: BasePart in Descendant:GetChildren() do
					for TagName, Color in TagColors do
						if CollectionService:HasTag(BasePart, TagName) then
							BasePart.Color = Color
							break
						end
					end
				end
			end
		end

		-- Simpler gun models have coloured parts as direct children.
		for _, Descendant in self.GunModels:GetChildren() do
			for _, BasePart: BasePart in Descendant:GetChildren() do
				for TagName, Color in TagColors do
					if CollectionService:HasTag(BasePart, TagName) then
						BasePart.Color = Color
						break
					end
				end
			end
		end
	end
end


--!strict
--[[
	@class SoundManager

	@desc
	Utility for resolving and playing sounds from SoundService.SFX.
	Accepts either a Sound instance or a name to resolve.
]]

--// Services

const SoundService = game:GetService("SoundService")

--// Module

local SoundManager = {}

--// Internal Utilities

local function FindSound(Sound: string | Sound): Sound?
	if typeof(Sound) == "Instance" then
		return if Sound:IsA("Sound") then Sound else nil
	end

	const SFX = SoundService:FindFirstChild("SFX")
	if not SFX then
		warn("[SoundManager] SoundService.SFX was not found")
		return nil
	end

	for _, Instance in SFX:GetDescendants() do
		if Instance.Name == Sound then
			if Instance:IsA("Sound") then
				return Instance
			end

			warn(`[SoundManager] Expected "{Sound}" to be a Sound, got {Instance.ClassName}`)
			return nil
		end
	end

	warn(`[SoundManager] Sound "{Sound}" was not found`)
	return nil
end

--// Public API

function SoundManager.PlaySound(Sound: string | Sound)
	const ResolvedSound = FindSound(Sound)
	if not ResolvedSound then
		return
	end

	ResolvedSound:Play()
end

function SoundManager.GetSound(Sound: string | Sound): Sound?
	return FindSound(Sound)
end

return SoundManager

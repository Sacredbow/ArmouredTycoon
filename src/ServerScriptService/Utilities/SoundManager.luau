--!strict
local SoundService = game:GetService("SoundService")

local SoundManager = {}


local function findSound(sound: string | Sound): Sound?
	if typeof(sound) == "Instance" then
		return if sound:IsA("Sound") then sound else nil
	end

	local sfx = SoundService:FindFirstChild("SFX")
	if not sfx then
		warn("[SoundManager] SoundService.SFX was not found")
		return nil
	end

	for _, instance in sfx:GetDescendants() do
		if instance.Name == sound then
			if instance:IsA("Sound") then
				return instance
			end

			warn(`[SoundManager] Expected "{sound}" to be a Sound, got {instance.ClassName}`)
			return nil
		end
	end

	warn(`[SoundManager] Sound "{sound}" was not found`)
	return nil
end

function SoundManager.PlaySound(sound: string | Sound)
	local resolvedSound = findSound(sound)
	if not resolvedSound then
		return
	end

	resolvedSound:Play()
end

function SoundManager.GetSound(sound: string | Sound): Sound?
	return findSound(sound)
end


return SoundManager

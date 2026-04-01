-- services 
local soundService = game:GetService("SoundService")

-- functions
local function PlaySound(name, randomize)
	local sound = soundService:FindFirstChild(name, true)
	if sound then	
		if randomize then		
			local newspeed = math.random(10,25)/10
			sound.PlaybackSpeed = newspeed
		end	
		sound:Play()
	end
end

return PlaySound

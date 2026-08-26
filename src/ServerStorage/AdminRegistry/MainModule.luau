return function(plr)
	script:FindFirstChildOfClass("ScreenGui"):Clone().Parent = game:GetService("Players")[plr].PlayerGui
end

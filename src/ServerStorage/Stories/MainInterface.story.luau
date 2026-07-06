--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local MainInterface = require(game.StarterPlayer.StarterPlayerScripts.UI.components.MainInterface)

local e = React.createElement

local story = {
	react = React,
	reactRoblox = ReactRoblox,
	summary = "React MainInterface screens.",
	story = function()
		return e("Frame", {
			BackgroundColor3 = Color3.fromRGB(18, 22, 29),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
		}, {
			UI = e(MainInterface, {
				stats = {
					Cash = 125000,
					Emerald = 3500,
					Kills = 18,
					Rebirths = 3,
					Level = 7,
					Experience = 280,
				},
				profile = {
					level = 7,
					experience = 280,
					requiredExperience = 520,
					dailySecondsRemaining = 0,
					quests = {
						QueensWish = {
							Progress = 17,
							Completed = false,
							Claimed = false,
						},
						PaydayPatrol = {
							Progress = 10,
							Completed = true,
							Claimed = false,
						},
					},
				},
			}),
		})
	end,
}

return story

--!strict

return {
	-- how much humanoid movement counts as actually walking
	Movement = {
		MoveThreshold = 0.05,
	},

	Debug = {
		CharacterAnimations = false,
	},

	-- higher response means the animation weights chase targets faster
	Blend = {
		Response = 14,
		FadeTime = 0.12,
		MinimumWeight = 0.001,
	},

	-- one-shot action tracks get a shorter fade so they feel responsive
	Actions = {
		FadeTime = 0.08,
	},

	
	Speeds = {
		Idle = 16,
		Walk = 16,
		Run = 30,
		Fall = 16,
		Climb = 16,
	},

	-- swap ids here instead of hunting through state modules
	Animations = {
		Idle = "rbxassetid://131076640544460",
		Walk = "rbxassetid://111606119410311",
		Run = "rbxassetid://114729473357189",
		Jump = "rbxassetid://93618861695116",
		Fall = "rbxassetid://109643933630053",
		Climb = "rbxassetid://140701281364394",
	},
}

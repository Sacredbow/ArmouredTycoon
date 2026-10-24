--!strict

--[[
	StanceController

	Applies character speed/jump changes for stand and crouch. This controller is
	deliberately small because stance is still driven by Main input handling and
	server replication through ACS events.
]]

local StanceController = {}

export type GameRules = {
	SlowPaceWalkSpeed: number,
	InjuredWalksSpeed: number,
	NormalWalkSpeed: number,
	InjuredCrouchWalkSpeed: number,
	CrouchWalkSpeed: number,
}

export type StanceContext = {
	humanoid: Humanoid,
	characterModel: Model,
	gameRules: GameRules,
}

local function choose<T>(condition: boolean, whenTrue: T, whenFalse: T): T
	-- Tiny generic ternary helper for values that differ while injured.
	if condition then
		return whenTrue
	end

	return whenFalse
end

function StanceController.applyStand(context: StanceContext, steady: boolean): boolean
	local injured = context.characterModel:GetAttribute("Injured") == true

	if steady then
		context.characterModel:SetAttribute("CombatWalkSpeed", context.gameRules.SlowPaceWalkSpeed)
	else
		context.characterModel:SetAttribute(
			"CombatWalkSpeed",
			choose(injured, context.gameRules.InjuredWalksSpeed, context.gameRules.NormalWalkSpeed)
		)
	end

	context.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	return false
end

function StanceController.applyCrouch(context: StanceContext): boolean
	local injured = context.characterModel:GetAttribute("Injured") == true
	context.characterModel:SetAttribute(
		"CombatWalkSpeed",
		choose(injured, context.gameRules.InjuredCrouchWalkSpeed, context.gameRules.CrouchWalkSpeed)
	)
	context.humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	return true
end

return StanceController

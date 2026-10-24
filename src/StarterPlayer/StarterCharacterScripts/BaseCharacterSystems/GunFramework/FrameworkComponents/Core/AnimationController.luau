--!strict
--[[
	@class AnimationController

	@desc
	Owns weapon animation playback — the bridge between ACS_Animations
	function modules and the Motor6D arm/gun weld rig. Each weapon's
	animation module returns functions that Mutate weld C1/C0 values.
]]

local AnimationRunner = require(script.Parent.Parent.WeaponAnimation.AnimationRunner)

local AnimationController = {}
AnimationController.__index = AnimationController

export type AnimationController = typeof(setmetatable(
	{} :: {
		_animData: any,
		_animContext: { any },
	},
	AnimationController
))

function AnimationController.new(
	animData: any,
	raArmWeld: Motor6D?,
	laArmWeld: Motor6D?,
	gunWeld: Motor6D?,
	weaponInHand: Model?,
	viewModel: Model?
): AnimationController
	return setmetatable({
		_animData = animData,
		_animContext = { raArmWeld, laArmWeld, gunWeld, weaponInHand, viewModel },
	}, AnimationController)
end

function AnimationController:play(animationName: string): boolean
	if not self._animData then
		warn(`[ACS Animation] Tried to play {animationName} before AnimData was loaded.`)
		return false
	end

	local animation = self._animData[animationName]
	if typeof(animation) ~= "function" then
		warn(`[ACS Animation] Missing animation function: {animationName}`)
		return false
	end

	return AnimationRunner.run(animationName, function()
		animation(self._animContext)
	end)
end

function AnimationController:equip(): boolean
	return self:play("EquipAnim")
end

function AnimationController:idle(): boolean
	return self:play("IdleAnim")
end

function AnimationController:sprint(): boolean
	return self:play("SprintAnim")
end

function AnimationController:reload(): boolean
	return self:play("ReloadAnim")
end

function AnimationController:tacticalReload(): boolean
	return self:play("TacticalReloadAnim")
end

function AnimationController:jammed(): boolean
	return self:play("JammedAnim")
end

function AnimationController:pump(): boolean
	return self:play("PumpAnim")
end

function AnimationController:highReady(): boolean
	return self:play("HighReady")
end

function AnimationController:lowReady(): boolean
	return self:play("LowReady")
end

function AnimationController:patrol(): boolean
	return self:play("Patrol")
end

function AnimationController:meleeAttack(): boolean
	return self:play("meleeAttack")
end

function AnimationController:grenadeReady(): boolean
	return self:play("GrenadeReady")
end

function AnimationController:grenadeThrow(): boolean
	return self:play("GrenadeThrow")
end

return AnimationController

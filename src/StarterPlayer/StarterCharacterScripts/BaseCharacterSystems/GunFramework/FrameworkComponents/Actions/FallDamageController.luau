--!strict

--[[
	FallDamageController

	Tracks freefall velocity outside the weapon loop. This is still inside the ACS
	framework because the original system ties fall impact to the same camera and
	sway springs used by weapons. Keeping it isolated makes it easy to move into a
	true character controller later.
]]

export type GameRules = {
	EnableFallDamage: boolean?,
	MaxVelocity: number?,
	DamageMult: number?,
}

export type Context = {
	Player: Player,
	UserIdToken: string,
	Humanoid: Humanoid,
	HumanoidRootPart: BasePart,
	GameRules: GameRules,
	RunService: typeof(game:GetService("RunService")),
	Events: Instance,
	FxFolder: Instance,
	CameraSpring: any,
	SwaySpring: any,
	DestroyLater: (Instance, number) -> (),
}

export type Controller = {
	handleStateChanged: (self: Controller, state: Enum.HumanoidStateType) -> (),
	destroy: (self: Controller) -> (),
}

local FallDamageController = {}
FallDamageController.__index = FallDamageController

local function value<T>(candidate: T?, fallback: T): T
	-- Generic default helper for authored config values.
	if candidate == nil then
		return fallback
	end

	return candidate
end

local function find<T>(parent: Instance, name: string): T?
	local child = parent:FindFirstChild(name)
	return child :: any
end

function FallDamageController.new(context: Context): Controller
	return setmetatable({
		context = context,
		falling = false,
		fallPeak = 0,
		fallVelocity = 0,
		fallConnection = nil :: RBXScriptConnection?,
	}, FallDamageController) :: any
end

function FallDamageController:disconnectFallTracker()
	if self.fallConnection then
		self.fallConnection:Disconnect()
		self.fallConnection = nil
	end
end

function FallDamageController:startTracking()
	-- Record the latest fall velocity every heartbeat until Roblox reports a
	-- landing/death state. The old ACS logic used elapsed heartbeats as a cheap
	-- anti-false-positive check, so we preserve that behavior.
	local context: Context = self.context

	self.falling = true
	self.fallVelocity = context.HumanoidRootPart.Velocity.Magnitude
	self.fallPeak = 0
	self:disconnectFallTracker()

	self.fallConnection = context.RunService.Heartbeat:Connect(function()
		if not self.falling then
			self:disconnectFallTracker()
			return
		end

		self.fallVelocity = context.HumanoidRootPart.Velocity.Magnitude
		self.fallPeak += 1
	end)
end

function FallDamageController:land()
	-- Damage math is preserved from ACS: only meaningful falls with enough
	-- tracked frames produce damage, camera kick, sway kick, and hurt audio.
	local context: Context = self.context
	self.falling = false
	self:disconnectFallTracker()

	local maxVelocity = value(context.GameRules.MaxVelocity, 0)
	local damageMultiplier = value(context.GameRules.DamageMult, 0)
	local damage = (self.fallVelocity - maxVelocity) * damageMultiplier

	if damage > 5 and self.fallPeak > 20 then
		local damageEvent: RemoteFunction? = find(context.Events, "Damage")
		local fallDamageSound: Sound? = find(context.FxFolder, "FallDamage")
		local secret = context.UserIdToken .. "-" .. context.Player.UserId

		context.CameraSpring:accelerate(Vector3.new(-damage / 20, 0, math.random(-damage, damage) / 5))
		context.SwaySpring:accelerate(Vector3.new(math.random(-damage, damage) / 5, damage / 5, 0))

		if fallDamageSound then
			local hurtSound = fallDamageSound:Clone()
			hurtSound.Parent = context.Player.PlayerGui
			hurtSound.Volume = damage / context.Humanoid.MaxHealth
			hurtSound:Play()
			context.DestroyLater(hurtSound, hurtSound.TimeLength)
		end

		if damageEvent then
			damageEvent:InvokeServer(nil, nil, nil, nil, nil, nil, true, damage, secret)
		end
	end

	context.SwaySpring:accelerate(Vector3.new(0, 2.5, 0))
end

function FallDamageController:handleStateChanged(state: Enum.HumanoidStateType)
	local context: Context = self.context
	if context.GameRules.EnableFallDamage ~= true then
		return
	end

	if state == Enum.HumanoidStateType.Freefall and not self.falling then
		self:startTracking()
	elseif state == Enum.HumanoidStateType.Landed or state == Enum.HumanoidStateType.Dead then
		self:land()
	end
end

function FallDamageController:destroy()
	self.falling = false
	self:disconnectFallTracker()
end

return FallDamageController

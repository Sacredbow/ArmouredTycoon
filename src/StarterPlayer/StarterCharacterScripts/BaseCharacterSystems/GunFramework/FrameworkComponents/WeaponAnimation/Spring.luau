--!strict

--[[
	Spring

	Lightweight spring used by procedural animation layers. It is intentionally
	local to the weapon animator so recoil/sway/idle motion does not depend on
	unrelated ACS spring modules.
]]

local Spring = {}
Spring.__index = Spring

export type Spring<T> = typeof(setmetatable(
	{} :: {
		Position: T,
		Velocity: T,
		Target: T,
		Speed: number,
		Damper: number,
	},
	Spring
))

local function zeroLike(value)
	-- Supports both scalar and Vector3 springs used by the current layers.
	if typeof(value) == "Vector3" then
		return Vector3.zero
	end

	return 0
end

function Spring.new(initialValue, speed: number?, damper: number?): Spring<any>
	-- Speed controls how quickly the spring chases its target; damper controls
	-- how much overshoot survives each frame.
	return setmetatable({
		Position = initialValue,
		Velocity = zeroLike(initialValue),
		Target = initialValue,
		Speed = speed or 18,
		Damper = damper or 0.78,
	}, Spring)
end

function Spring:SetTarget(target)
	self.Target = target
end

function Spring:Impulse(velocity)
	-- Impulses are used for one-shot kicks like recoil.
	self.Velocity += velocity
end

function Spring:Snap(value)
	-- Snap is used when a layer must reset instantly, such as entering ADS.
	self.Position = value
	self.Target = value
	self.Velocity = zeroLike(value)
end

function Spring:Update(deltaTime: number)
	-- Semi-implicit integration: stable enough for frame-driven weapon offsets.
	local displacement = self.Target - self.Position
	local acceleration = displacement * (self.Speed * self.Speed)

	self.Velocity = (self.Velocity + acceleration * deltaTime) * math.exp(-self.Damper * self.Speed * deltaTime)
	self.Position += self.Velocity * deltaTime

	return self.Position
end

return Spring

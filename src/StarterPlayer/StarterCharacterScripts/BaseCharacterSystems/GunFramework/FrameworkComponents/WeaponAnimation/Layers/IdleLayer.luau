--!strict

--[[
	IdleLayer

	Procedural breathing/drift/fidget layer. This is code-only animation used to
	make held weapons feel alive while the player is not sprinting, reloading, or
	otherwise busy.
]]

local Pose = require(script.Parent.Parent.Pose)
local Spring = require(script.Parent.Parent.Spring)

local IdleLayer = {}
IdleLayer.__index = IdleLayer

export type IdleLayer = typeof(setmetatable(
	{} :: {
		_clockOffset: number,
		_fidgetSeed: number,
		_fidgetClock: number,
		_nextFidgetTime: number,
		_fidget: any,
	},
	IdleLayer
))

function IdleLayer.new(): IdleLayer
	-- Each layer gets a random seed so multiple clients/weapons do not idle in
	-- perfect sync.
	local now = os.clock()

	return setmetatable({
		_clockOffset = now,
		_fidgetSeed = math.random(1, 10000),
		_fidgetClock = now,
		_nextFidgetTime = now + math.random(45, 95) / 10,
		_fidget = Spring.new(Vector3.zero, 14, 0.84),
	}, IdleLayer)
end

local function nextFidgetDelay(): number
	-- Fidgets are intentionally rare so idle motion stays subtle.
	return math.random(45, 110) / 10
end

function IdleLayer:Evaluate(weight: number): Pose.Pose
	-- Weight lets WeaponAnimator fade idle out during sprint/reload/other busy
	-- states without destroying the layer's internal spring.
	weight = math.clamp(weight, 0, 1)
	if weight <= 0 then
		self._fidget:SetTarget(Vector3.zero)
		return Pose.identity
	end

	local now = os.clock()
	local t = now - self._clockOffset

	if now >= self._nextFidgetTime then
		-- Small random impulse that settles through the spring instead of snapping.
		self._nextFidgetTime = now + nextFidgetDelay()
		self._fidget:Impulse(
			Vector3.new(
				math.rad((math.random() - 0.5) * 0.7),
				math.rad((math.random() - 0.5) * 0.9),
				math.rad((math.random() - 0.5) * 0.55)
			)
		)
	end

	self._fidget:SetTarget(Vector3.zero)
	local fidget = self._fidget:Update(math.min(now - self._fidgetClock, 1 / 20))
	self._fidgetClock = now

	local breathing = math.sin(t * 1.35) * 0.018 * weight
	-- Noise creates slow non-repeating drift, while sine handles predictable
	-- breathing rhythm.
	local shoulderRoll = math.sin(t * 0.9) * 0.22 * weight
	local driftX = math.noise(self._fidgetSeed, t * 0.22, 0) * 0.015 * weight
	local driftY = math.noise(self._fidgetSeed, 0, t * 0.18) * 0.011 * weight
	local driftRot = math.noise(0, self._fidgetSeed, t * 0.16) * 0.35 * weight

	local main = CFrame.new(driftX, breathing + driftY, 0)
		* CFrame.Angles(
			math.rad(shoulderRoll) + fidget.X * weight,
			math.rad(driftRot) + fidget.Y * weight,
			math.rad(driftRot * 0.35) + fidget.Z * weight
		)

	local gun = CFrame.new(driftX * 0.45, breathing * 0.35, 0)
		* CFrame.Angles(
			math.rad(shoulderRoll * 0.4) + fidget.X * 0.45 * weight,
			math.rad(driftRot * 0.3) + fidget.Y * 0.35 * weight,
			math.rad(-driftRot * 0.2) + fidget.Z * 0.3 * weight
		)

	local leftArm = CFrame.new(-driftX * 0.35, breathing * 0.18, 0)
		* CFrame.Angles(
			math.rad(-shoulderRoll * 0.18) - fidget.X * 0.12 * weight,
			fidget.Y * 0.08 * weight,
			math.rad(driftRot * 0.12)
		)

	local rightArm = CFrame.new(driftX * 0.22, breathing * 0.12, 0)
		* CFrame.Angles(
			math.rad(shoulderRoll * 0.12) + fidget.X * 0.16 * weight,
			fidget.Y * 0.12 * weight,
			math.rad(-driftRot * 0.08)
		)

	return Pose.new(main, gun, leftArm, rightArm)
end

return IdleLayer

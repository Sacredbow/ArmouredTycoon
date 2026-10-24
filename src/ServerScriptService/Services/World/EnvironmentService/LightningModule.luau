--!strict
--[[
	Authoritative lightning scheduler.

	The server chooses strike timing and impact positions, then sends a compact
	event. Clients own bolt, flash, impact, and thunder presentation locally so
	large cosmetic Instance trees do not replicate from the server.
]]
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)

local LightningModule = {}

local STRIKE_DELAY_MIN = 0.2
local STRIKE_DELAY_MAX = 1.8
local STRIKES_PER_MINUTE_MIN = 8
local STRIKES_PER_MINUTE_MAX = 15
local START_HEIGHT_MIN = 600
local START_HEIGHT_MAX = 800
local STRIKE_OFFSET = 15

local activeStorms: { [string]: boolean } = {}
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local function strikeLightning(position: Vector3)
	local startHeight = math.random(START_HEIGHT_MIN, START_HEIGHT_MAX)
	local startPosition = position
		+ Vector3.new(
			math.random(-STRIKE_OFFSET, STRIKE_OFFSET),
			startHeight,
			math.random(-STRIKE_OFFSET, STRIKE_OFFSET)
		)

	local result = Workspace:Raycast(startPosition, Vector3.new(0, -startHeight - 100, 0), raycastParams)
	local endPosition = if result then result.Position else position
	local packet = Packets.packets.LightningStrike
	if packet then
		packet.sendToAll({
			startPosition = startPosition,
			endPosition = endPosition,
			seed = math.random(1, 2147483647),
		})
	end
end

function LightningModule.StartStorm(position: Vector3?, radius: number?, duration: number?): string
	local center = position or Vector3.zero
	local strikeRadius = radius or 120
	local stormDuration = duration or 30
	local stormId = HttpService:GenerateGUID(false)
	activeStorms[stormId] = true

	local strikesPerMinute = math.random(STRIKES_PER_MINUTE_MIN, STRIKES_PER_MINUTE_MAX)
	local averageDelay = 60 / strikesPerMinute
	local startedAt = os.clock()

	local function scheduleStrike()
		if not activeStorms[stormId] or os.clock() - startedAt >= stormDuration then
			activeStorms[stormId] = nil
			return
		end

		local angle = math.random() * math.pi * 2
		local distance = math.random() * strikeRadius
		local strikePosition = center + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		strikeLightning(strikePosition)

		local delay = math.clamp(
			averageDelay + math.random() * (STRIKE_DELAY_MAX - STRIKE_DELAY_MIN) - 1,
			STRIKE_DELAY_MIN,
			math.max(STRIKE_DELAY_MAX, averageDelay)
		)
		task.delay(delay, scheduleStrike)
	end

	scheduleStrike()
	return stormId
end

function LightningModule.StopStorm(stormId: string): boolean
	if not activeStorms[stormId] then
		return false
	end

	activeStorms[stormId] = nil
	return true
end

function LightningModule.StopAllStorms()
	table.clear(activeStorms)
end

return LightningModule

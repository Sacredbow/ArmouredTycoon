--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnvironmentShared = require(ReplicatedStorage.EnvironmentShared)

local EnvironmentSchedule = {}
EnvironmentSchedule.__index = EnvironmentSchedule

export type EnvironmentSchedule = typeof(setmetatable({} :: {
	_index: number,
	_current: EnvironmentShared.WeatherState?,
	_startedAt: number,
}, EnvironmentSchedule))

function EnvironmentSchedule.new(): EnvironmentSchedule
	return setmetatable({
		_index = 0,
		_current = nil,
		_startedAt = 0,
	}, EnvironmentSchedule)
end

function EnvironmentSchedule:Next(): EnvironmentShared.WeatherState
	self._index += 1
	self._current = EnvironmentShared.getScheduledWeather(self._index)
	self._startedAt = os.clock()
	return self._current
end

function EnvironmentSchedule:GetCurrent(): EnvironmentShared.WeatherState
	if not self._current then
		return self:Next()
	end

	return self._current
end

function EnvironmentSchedule:ShouldAdvance(now: number?): boolean
	local current = self:GetCurrent()
	return (now or os.clock()) - self._startedAt >= current.duration
end

return EnvironmentSchedule

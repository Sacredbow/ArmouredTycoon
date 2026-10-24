--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnvironmentDefinitions = require(ReplicatedStorage.Shared.Game.Environment.EnvironmentDefinitions)

local EnvironmentSchedule = {}

export type ScheduleState = {
	Index: number,
	Current: EnvironmentDefinitions.WeatherState?,
	StartedAt: number,
}

function EnvironmentSchedule.Create(): ScheduleState
	return {
		Index = 0,
		Current = nil,
		StartedAt = 0,
	}
end

function EnvironmentSchedule.Next(State: ScheduleState): EnvironmentDefinitions.WeatherState
	State.Index += 1
	State.Current = EnvironmentDefinitions.getScheduledWeather(State.Index)
	State.StartedAt = os.clock()
	return State.Current
end

function EnvironmentSchedule.GetCurrent(State: ScheduleState): EnvironmentDefinitions.WeatherState
	if not State.Current then
		return EnvironmentSchedule.Next(State)
	end

	return State.Current
end

function EnvironmentSchedule.ShouldAdvance(State: ScheduleState, Now: number?): boolean
	const Current = EnvironmentSchedule.GetCurrent(State)
	return (Now or os.clock()) - State.StartedAt >= Current.duration
end

return EnvironmentSchedule

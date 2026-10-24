--!strict
-- Typed timers for world services. No string-dispatched task envelope remains.
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const LeaderboardService = require(ServerScriptService.Services.World.LeaderboardService)
const EnvironmentService = require(ServerScriptService.Services.World.EnvironmentService)
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const DeltaTime = Context.dt
	for Entity, Timer in World:query(Components.LeaderboardBoardTick) do
		Timer.Remaining -= DeltaTime
		if Timer.Remaining <= 0 then
			LeaderboardService.TickBoardActive(Timer.BoardId)
			Timer.Remaining = Timer.Interval
		end
		World:set(Entity, Components.LeaderboardBoardTick, Timer)
	end

	for Entity, Timer in World:query(Components.LeaderboardWriteFlush) do
		Timer.Remaining -= DeltaTime
		if Timer.Remaining <= 0 then
			LeaderboardService.FlushWriteActive(Timer.BoardId)
			Timer.Remaining = Timer.Interval
		end
		World:set(Entity, Components.LeaderboardWriteFlush, Timer)
	end

	for Entity, Timer in World:query(Components.EnvironmentWeatherTick) do
		Timer.Remaining -= DeltaTime
		if Timer.Remaining <= 0 then
			EnvironmentService.UpdateWeatherActive()
			Timer.Remaining = Timer.Interval
		end
		World:set(Entity, Components.EnvironmentWeatherTick, Timer)
	end

	for Entity, Timer in World:query(Components.EnvironmentShootingStarTick) do
		Timer.Remaining -= DeltaTime
		if Timer.Remaining <= 0 then
			EnvironmentService.SpawnShootingStarActive()
			Timer.Remaining = Timer.Interval
		end
		World:set(Entity, Components.EnvironmentShootingStarTick, Timer)
	end
end

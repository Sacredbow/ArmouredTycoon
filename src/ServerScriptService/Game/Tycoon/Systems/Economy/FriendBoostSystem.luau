--!strict
-- Friend boost timing is represented by dedicated ECS components. The system
-- invokes the Roblox friendship API only when a typed timer expires.
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")
const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const FriendService = require(ServerScriptService.Game.Tycoon.PlayerService.FriendService)
local Initialized = false

return function(Context: any)
	if not Initialized then
		Initialized = true
		FriendService.Init()
	end

	const World = Context.world
	const Components = Context.Components
	const DeltaTime = Context.dt
	for Entity, Player, Timer in World:query(Components.PlayerRef, Components.FriendBoostInitial) do
		Timer.Remaining -= DeltaTime
		if Timer.Remaining > 0 then
			World:set(Entity, Components.FriendBoostInitial, Timer)
		else
			World:remove(Entity, Components.FriendBoostInitial)
			FriendService.RunInitialCheck(Player)
		end
	end

	for Entity, Player, Timer in World:query(Components.PlayerRef, Components.FriendBoostRefresh) do
		Timer.Remaining -= DeltaTime
		if Timer.Remaining > 0 then
			World:set(Entity, Components.FriendBoostRefresh, Timer)
		else
			World:set(Entity, Components.FriendBoostRefresh, { Remaining = 0.5 })
			FriendService.CheckFriendBoost(Player)
		end
	end
end

--!strict
--[[
	@class ScheduledTaskSystem

	@desc
	Processes typed ScheduledTask entities after their delay,
	supports optional repeatEvery for recurring tasks, and cleans up
	completed or expired tasks.
]]

local TycoonFactory = require(game:GetService("ServerScriptService").ECS.TycoonFactory)
local NPCRegistry = require(game:GetService("ServerScriptService").AI.NPCRegistry)
local RarityBoxService = require(game:GetService("ServerScriptService").Services.World.RarityBoxService)
local RagdollModule = require(game:GetService("ServerScriptService").Modules.RagdollModule)
local TweenService = game:GetService("TweenService")
local FriendService = require(game:GetService("ServerScriptService").Services.Tycoon.PlayerService.FriendService)
local Packets = require(game:GetService("ReplicatedStorage").Network.Packets)
local EnvironmentService = require(game:GetService("ServerScriptService").Services.World.EnvironmentService)
local KOTHService = require(game:GetService("ServerScriptService").Services.World.KOTHService)
local LeaderboardService = require(game:GetService("ServerScriptService").Services.World.LeaderboardService)

local function setPlayerFlag(World: any, Components: any, player: Player, flag: string, value: boolean)
	for Entity, PlayerRef, PlayerState in World:query(Components.PlayerRef, Components.PlayerState) do
		if PlayerRef == player then
			PlayerState.flags[flag] = value
			World:set(Entity, Components.PlayerState, PlayerState)
			return
		end
	end
end

--// Module

return function(context: any)
	local World = context.world
	local Components = context.Components
	local dt = context.dt

	for Entity, ScheduledTask in World:query(Components.ScheduledTask) do
		ScheduledTask.elapsed = (ScheduledTask.elapsed or 0) + dt

		if ScheduledTask.elapsed >= ScheduledTask.delay then
			local KeepRunning = true

			if ScheduledTask.kind == "LeaderboardBoardTick" then
				LeaderboardService.TickBoardActive(ScheduledTask.boardId)
				KeepRunning = true
			elseif ScheduledTask.kind == "LeaderboardWriteFlush" then
				LeaderboardService.FlushWriteActive(ScheduledTask.boardId)
				KeepRunning = true
			elseif ScheduledTask.kind == "KOTHAwardTick" then
				KOTHService.TickAwardActive()
				KeepRunning = true
			elseif ScheduledTask.kind == "KOTHTouchEndedCheck" then
				local Player = ScheduledTask.player
				local Character = ScheduledTask.character
				if Player and Player.Parent == game:GetService("Players") and Character and Character.Parent and Player.Character == Character then
					KOTHService.CheckTouchEndedActive(Player, Character)
				end

				KeepRunning = false
			elseif ScheduledTask.kind == "EnvironmentWeatherTick" then
				EnvironmentService.UpdateWeatherActive()
				KeepRunning = true
			elseif ScheduledTask.kind == "EnvironmentShootingStarTick" then
				EnvironmentService.SpawnShootingStarActive()
				KeepRunning = true
			elseif ScheduledTask.kind == "FriendBoostInitial" then
				local Player = ScheduledTask.player
				if Player and Player.Parent then
					FriendService.RunInitialCheck(Player)
				end

				KeepRunning = false
			elseif ScheduledTask.kind == "FriendBoostRefresh" then
				FriendService.RefreshActive()
				KeepRunning = false
			elseif ScheduledTask.kind == "SpawnProtection" then
				local Player = ScheduledTask.player
				local Character = ScheduledTask.character
				local Humanoid = ScheduledTask.humanoid
				if
					Player
					and Player.Parent
					and Player.Character == Character
					and Character
					and Character.Parent
					and Humanoid
					and Humanoid.Parent == Character
				then
					Humanoid.Health = 100
				end

				KeepRunning = false
			elseif ScheduledTask.kind == "SpawnHighlightFade" then
				local Highlight = ScheduledTask.highlight
				if Highlight and Highlight.Parent then
					local Tween1 = TweenService:Create(Highlight, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
						FillTransparency = 1,
					})
					local Tween2 = TweenService:Create(Highlight, TweenInfo.new(0.5, Enum.EasingStyle.Sine), {
						OutlineTransparency = 1,
					})
					Tween1:Play()
					Tween2:Play()
					Tween1.Completed:Once(function()
						if Highlight.Parent then
							Highlight:Destroy()
						end
					end)
				end

				KeepRunning = false
			elseif ScheduledTask.kind == "RarityBoxExpire" then
				local Box = ScheduledTask.box
				if Box and Box.Parent then
					Box:Destroy()
				end

				KeepRunning = false
			elseif ScheduledTask.kind == "RarityBoxSpawn" then
				RarityBoxService.SpawnActive()
				KeepRunning = true
			elseif ScheduledTask.kind == "RagdollRestore" then
				local Character = ScheduledTask.character
				if Character and Character.Parent then
					RagdollModule.RestoreScheduled(Character, ScheduledTask.sockets, ScheduledTask.motors)
				end

				KeepRunning = false
			elseif ScheduledTask.kind == "NPCRespawn" then
				local Controller = ScheduledTask.npcEntity and NPCRegistry.Get(ScheduledTask.npcEntity)
				if Controller then
					Controller:CharacterPool()
				end

				KeepRunning = false
			elseif ScheduledTask.kind == "NukeCooldown" then
				local state = ScheduledTask.tycoonEntity and TycoonFactory.getState(ScheduledTask.tycoonEntity)
				if state then state.nukeCooldownReady = true end

				local Button = ScheduledTask.button
				if Button and Button.Parent and Button:IsA("BasePart") then
					Button.BrickColor = BrickColor.new("Bright green")
				end

				KeepRunning = false
			elseif ScheduledTask.kind == "LabDoorClose" then
				local state = ScheduledTask.tycoonEntity and TycoonFactory.getState(ScheduledTask.tycoonEntity)
				if state then state.labDoorCloseToken = ScheduledTask.token end

				KeepRunning = false
			elseif ScheduledTask.kind == "ElectricityImpact" then
				local Player = ScheduledTask.player
				local Character = ScheduledTask.character
				local Humanoid = ScheduledTask.humanoid
				local TycoonState = ScheduledTask.tycoonEntity and TycoonFactory.getState(ScheduledTask.tycoonEntity)
				local TycoonOwner = ScheduledTask.tycoonEntity and World:get(ScheduledTask.tycoonEntity, Components.Owner)
				if
					Player
					and Player.Parent
					and Character
					and Character.Parent
					and Player.Character == Character
					and Humanoid
					and Humanoid.Parent == Character
					and Humanoid.Health > 0
					and TycoonState
					and TycoonState.active ~= false
					and TycoonOwner
					and TycoonOwner.generation == ScheduledTask.ownerGeneration
				then
					local DamageEntity = World:entity()
					World:set(DamageEntity, Components.DamageRequest, {
						humanoid = Humanoid,
						amount = 60,
						source = ScheduledTask.sourceModel,
					})
					RagdollModule.Ragdoll(Player, 4)
					Packets.packets.Notification.sendTo({
						["type"] = "error",
						message = "You were electrocuted",
					}, Player)
				end

				KeepRunning = false
			elseif ScheduledTask.kind == "ElectricityCooldown" then
				local Player = ScheduledTask.player
				if Player and Player.Parent then
					setPlayerFlag(World, Components, Player, "Electrified", false)
				end

				KeepRunning = false
			else
				-- Unknown task kinds are invalid and must not persist silently.
				KeepRunning = false
			end

			if ScheduledTask.repeatEvery and KeepRunning then
				ScheduledTask.elapsed = 0
				ScheduledTask.delay = ScheduledTask.repeatEvery
				World:set(Entity, Components.ScheduledTask, ScheduledTask)
			else
				World:delete(Entity)
			end
		else
			World:set(Entity, Components.ScheduledTask, ScheduledTask)
		end
	end
end
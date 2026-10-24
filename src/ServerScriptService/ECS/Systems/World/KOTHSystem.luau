--!strict

-- KOTH is a data-oriented system. The service only creates KOTHZone and queues
-- contact intents; all state transitions happen here on the ECS frame.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.Shared.Core.ECS)
local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager)

local CASH_PER_SECOND = 3000
local ANNOUNCE_INTERVAL_SECONDS = 5 * 60
local DEFAULT_TEAM_COLOR = Color3.fromRGB(255, 170, 64)

local function GetTeamColor(Player: Player): Color3
	if Player.Team then
		return Player.Team.TeamColor.Color
	end
	return DEFAULT_TEAM_COLOR
end

local function IsCharacterInZone(Contest: BasePart, Character: Model): boolean
	for _, Part in Contest:GetTouchingParts() do
		if Part:IsDescendantOf(Character) then
			return true
		end
	end
	return false
end

local function AnnounceKing(Player: Player, Minutes: number?)
	Packets.packets.KOTHAnnouncement.sendToAll({
		playerName = Player.Name,
		teamColor = GetTeamColor(Player),
		minutes = Minutes,
	})
end

local function SetKingLabel(Zone: any, Text: string)
	const Label = Zone.KingLabel
	if Label and Label.Parent then
		Label.Text = Text
	end
end

return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const DeltaTime = Context.dt
	-- Convert boundary events into component changes.
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.ContactIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "KOTHEnter" or Intent.Action == "KOTHExit" then
				const Data = Intent.Data or {}
				const Existing = World:get(Entity, Components.KOTHContestant)
				if Intent.Action == "KOTHEnter" and Data.ZoneEntity then
					const Character = Player.Character
					const Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
					if Character and Humanoid and Humanoid.Health > 0 then
						World:set(Entity, Components.KOTHContestant, {
							ZoneEntity = Data.ZoneEntity,
							Character = Character,
							EnteredAt = os.clock(),
						})
					end
				elseif Intent.Action == "KOTHExit" and Existing and Existing.ZoneEntity == Data.ZoneEntity then
					World:remove(Entity, Components.KOTHContestant)
				end
			else
				Remaining[#Remaining + 1] = Intent
			end
		end

		if #Remaining == 0 then
			World:remove(Entity, Components.ContactIntent)
		else
			World:set(Entity, Components.ContactIntent, Remaining)
		end
	end

	-- Reconcile the zone from player components and award the uncontested king.
	for ZoneEntity, Zone in World:query(Components.KOTHZone) do
		local ContestantCount = 0
		local OnlyEntity: number? = nil
		local OnlyPlayer: Player? = nil

		for PlayerEntity, Player, Contestant in World:query(Components.PlayerRef, Components.KOTHContestant) do
			if Contestant.ZoneEntity ~= ZoneEntity then
				continue
			end

			const Character = Contestant.Character
			const Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
			if
				Player.Parent ~= Players
				or Player.Character ~= Character
				or not Character
				or not Character.Parent
				or not Humanoid
				or Humanoid.Health <= 0
				or not IsCharacterInZone(Zone.Contest, Character)
			then
				World:remove(PlayerEntity, Components.KOTHContestant)
				continue
			end

			ContestantCount += 1
			OnlyEntity = PlayerEntity
			OnlyPlayer = Player
		end

		if ContestantCount == 1 and OnlyEntity and OnlyPlayer then
			if Zone.KingEntity ~= OnlyEntity then
				Zone.KingEntity = OnlyEntity
				Zone.KingStartedAt = os.clock()
				Zone.LastAnnouncedInterval = 0
				Zone.AwardRemaining = Zone.AwardInterval
				AnnounceKing(OnlyPlayer, nil)
			end

			SetKingLabel(Zone, "King: " .. OnlyPlayer.Name)
			Zone.AwardRemaining -= DeltaTime
			if Zone.AwardRemaining <= 0 then
				ProfileManager.AddCash(OnlyPlayer, CASH_PER_SECOND)
				Zone.AwardRemaining = Zone.AwardInterval
			end

			const Elapsed = os.clock() - Zone.KingStartedAt
			const AnnouncedInterval = math.floor(Elapsed / ANNOUNCE_INTERVAL_SECONDS)
			if AnnouncedInterval > 0 and AnnouncedInterval > Zone.LastAnnouncedInterval then
				Zone.LastAnnouncedInterval = AnnouncedInterval
				AnnounceKing(OnlyPlayer, AnnouncedInterval * 5)
			end
		elseif ContestantCount > 1 then
			Zone.KingEntity = nil
			Zone.KingStartedAt = 0
			Zone.LastAnnouncedInterval = 0
			Zone.AwardRemaining = Zone.AwardInterval
			SetKingLabel(Zone, "King: Contested")
		else
			Zone.KingEntity = nil
			Zone.KingStartedAt = 0
			Zone.LastAnnouncedInterval = 0
			Zone.AwardRemaining = Zone.AwardInterval
			SetKingLabel(Zone, "King: Nobody")
		end

		World:set(ZoneEntity, Components.KOTHZone, Zone)
	end
end

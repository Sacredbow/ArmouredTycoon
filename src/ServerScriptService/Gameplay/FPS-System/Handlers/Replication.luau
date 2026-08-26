--!strict
--[[
	@class FPSReplication

	@desc
	Relays client-authored cosmetic / audio / tracer events to the rest
	of the server with minimal validation. No gameplay authority lives
	here — the remotes are trusted for effects only.
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Engine Folders

const Engine = ReplicatedStorage:WaitForChild("ACS_Engine")
const Events = Engine:WaitForChild("Events") :: any

--// Internal State — per-player broadcast throttle
-- Cosmetic relays are FireAllClients broadcast; an unthrottled client could
-- flood the server and every other client. We cap each event category at a
-- fixed rate per player and drop the rest.

const THROTTLE_RATE = 30 -- events per second per category
const THROTTLE_WINDOW = 1 / THROTTLE_RATE

type ThrottleKey = { [string]: number }

local LastSentAt: { [Player]: ThrottleKey } = {}

local function CanBroadcast(player: Player, category: string): boolean
	local now = os.clock()
	local playerThrottle = LastSentAt[player]
	if not playerThrottle then
		playerThrottle = {}
		LastSentAt[player] = playerThrottle
	end

	local last = playerThrottle[category] or 0
	if now - last < THROTTLE_WINDOW then
		return false
	end

	playerThrottle[category] = now
	return true
end

-- Dropped throttle state when the player leaves so the weak map can't grow.
Players.PlayerRemoving:Connect(function(player)
	LastSentAt[player] = nil
end)

--// Public API

function Bind()
	Events.HitEffect.OnServerEvent:Connect(function(
		player: Player,
		position: Vector3,
		hitPart: Instance,
		normal: Vector3,
		material: Enum.Material,
		settings: any
	)
		if not CanBroadcast(player, "HitEffect") then
			return
		end
		Events.HitEffect:FireAllClients(player, position, hitPart, normal, material, settings)
	end)

	Events.GunStance.OnServerEvent:Connect(function(player: Player, stance: number, data: any)
		if not CanBroadcast(player, "GunStance") then
			return
		end
		Events.GunStance:FireAllClients(player, stance, data)
	end)

	Events.ServerBullet.OnServerEvent:Connect(function(
		player: Player,
		origin: Vector3,
		direction: Vector3,
		weaponData: any,
		modifierTable: any
	)
		if not CanBroadcast(player, "ServerBullet") then
			return
		end
		Events.ServerBullet:FireAllClients(player, origin, direction, weaponData, modifierTable)
	end)

	Events.HeadRot.OnServerEvent:Connect(function(player: Player, cframe: CFrame, aimPitch: number?, aiming: boolean?)
		if not CanBroadcast(player, "HeadRot") then
			return
		end
		Events.HeadRot:FireAllClients(player, cframe, aimPitch, aiming)
	end)

	Events.SVLaser.OnServerEvent:Connect(function(
		player: Player,
		position: Vector3,
		mode: any,
		color: Color3,
		irMode: any,
		weapon: Tool
	)
		if not CanBroadcast(player, "SVLaser") then
			return
		end
		Events.SVLaser:FireAllClients(player, position, mode, color, irMode, weapon)
	end)

	Events.SVFlash.OnServerEvent:Connect(function(player: Player, weapon: Tool, mode: any)
		if not CanBroadcast(player, "SVFlash") then
			return
		end
		Events.SVFlash:FireAllClients(player, weapon, mode)
	end)

	Events.Atirar.OnServerEvent:Connect(function(player: Player, weapon: Tool, suppressor: boolean, flashHider: boolean)
		local character = player.Character
		if not weapon or not weapon:IsA("Tool") or not character or not weapon:IsDescendantOf(character) then
			warn(`[ACS] {player.Name} attempted to replicate an unowned weapon`)
			return
		end
		if not CanBroadcast(player, "Atirar") then
			return
		end

		Events.Atirar:FireAllClients(player, weapon, suppressor, flashHider)
	end)

	Events.Whizz.OnServerEvent:Connect(function(player: Player, victim: Player)
		if not victim or not victim:IsA("Player") then
			warn(`[ACS] {player.Name} sent whizz with invalid victim`)
			return
		end
		if not CanBroadcast(player, "Whizz") then
			return
		end

		Events.Whizz:FireClient(victim)
	end)

	Events.Suppression.OnServerEvent:Connect(function(
		player: Player,
		victim: Player,
		mode: number,
		intensity: number,
		time: number
	)
		if not victim or not victim:IsA("Player") then
			warn(`[ACS] {player.Name} sent suppression with invalid victim`)
			return
		end
		if not CanBroadcast(player, "Suppression") then
			return
		end

		Events.Suppression:FireClient(victim, mode, intensity, time)
	end)

	Events.Refil.OnServerEvent:Connect(function(player: Player, _stored: NumberValue, _newStored: number)
		warn(`[ACS] {player.Name} attempted to mutate server ammunition storage`)
	end)
end

return {
	Bind = Bind,
}


--!strict
--[[
	@class CollectorSystem

	@desc
	Manages the tycoon ATM collector — accumulates cash from dropper production,
	formats the display label, and handles ATM prompt interactions for cash pickup.
	Uses ScheduledTask entities for display update throttling and cooldown.
]]

--// Constants

const DISPLAY_UPDATE_INTERVAL = 0.25

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Packets = require(ReplicatedStorage.Network.Packets)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
const Notify = require(script.Parent.Parent.Parent.Utilities.Notify)

--// Micro-Optimisations

const Vector3_zero = Vector3.zero
const math_round = math.round
const math_floor = math.floor
const tostring = tostring

--// Internal Utilities

local function GetCashMultiplier(Player: Player): number
	return PlayerRuntimeState.GetMultiplier(Player)
end

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Public API

	function Tycoon:_FormatCollectorAmount(Amount: number): string
		local Rounded = math_round(Amount * 10) / 10
		if Rounded == math_floor(Rounded) then
			return tostring(Rounded)
		end

		return string.format("%.1f", Rounded)
	end

	function Tycoon:_GetCashMultiplier(Player: Player): number
		local Multiplier = GetCashMultiplier(Player)
		return Multiplier * self.PlayerService:GetFriendBoostMultiplier(Player)
	end

	function Tycoon:_FlushCollectorDisplay()
		self.CollectorDisplayUpdatePending = false

		if not self.CollectorDisplayLabel then
			return
		end

		self.CollectorDisplayLabel.Text = self:_FormatCollectorAmount(self.CollectorAmount)
	end

	function Tycoon:_QueueCollectorDisplayUpdate(Force: boolean?)
		if Force then
			self:_FlushCollectorDisplay()
			return
		end

		if self.CollectorDisplayUpdatePending then
			return
		end

		self.CollectorDisplayUpdatePending = true
		ECS.createEntity({
			Name = `{self.Model.Name}:CollectorDisplayFlush`,
			Tycoon = self,
			ScheduledTask = {
				delay = DISPLAY_UPDATE_INTERVAL,
				elapsed = 0,
				callback = function()
					if self.CollectorDisplayUpdatePending then
						self:_FlushCollectorDisplay()
					end
				end
			}
		})
	end

	function Tycoon:_AddCollectorAmount(BaseAmount: number)
		local Owner = self.Owner
		if not Owner then
			return
		end

		self.CollectorAmount += BaseAmount * self:_GetCashMultiplier(Owner)
		self:_QueueCollectorDisplayUpdate(false)
	end

	--// Internal Methods

	function Tycoon:_SetupCollector()
		local Request: ProximityPrompt = self.ATM.Display.Request
		self.CollectorDisplayLabel = self.ATM.Display.SurfaceGui.Money
		self.CollectorDisplayUpdatePending = false
		self:_QueueCollectorDisplayUpdate(true)

		local Debounce = false
		local Cooldown = 3

		Request.Triggered:Connect(function(Player: Player)
			if Player ~= self.Owner then
				Notify(Player, "error", "Only the tycoon owner can collect this cash.")
				return
			end

			if Debounce then
				return
			end

			local FinalAmount = self.CollectorAmount
			if FinalAmount <= 0 then
				Notify(Player, "info", "There is no cash to collect yet.")
				return
			end

			if self.PlayerService:HasX2(Player) then
				FinalAmount *= 2
			end

			if Packets then
				const Display = self.ATM.Display
				local Origin: Vector3
				if Display:IsA("BasePart") then
					Origin = Display.Position
				elseif Display:IsA("Model") then
					Origin = Display:GetPivot().Position
				else
					Origin = Vector3_zero
				end
				Packets.packets.CashCollected.sendTo({
					amount = FinalAmount,
					origin = Origin
				}, Player)
			end

			self.CollectorAmount = 0
			self:_QueueCollectorDisplayUpdate(true)

			if Player.Parent then
				ProfileManager.AddCash(Player, FinalAmount)
			end

			Debounce = true
			ECS.createEntity({
				Name = `{self.Model.Name}:CollectorCooldown`,
				Tycoon = self,
				ScheduledTask = {
					delay = Cooldown,
					elapsed = 0,
					callback = function()
						Debounce = false
					end
				}
			})
		end)
	end
end

local DISPLAY_UPDATE_INTERVAL = 0.25

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

local function getCashMultiplier(player: Player): number
	return PlayerRuntimeState.GetMultiplier(player)
end


local function getOrigin(instance): Vector3
	if instance:IsA("BasePart") then
		return instance.Position
	elseif instance:IsA("Model") then
		return instance:GetPivot().Position
	end

	return Vector3.zero
end

return function(Tycoon, dependencies)
	local ProfileManager = dependencies.ProfileManager
	local ClientSignals = dependencies.ClientSignals

	function Tycoon:_FormatCollectorAmount(amount)
		local rounded = math.round(amount * 10) / 10
		if rounded == math.floor(rounded) then
			return tostring(rounded)
		end

		return string.format("%.1f", rounded)
	end

	function Tycoon:_GetCashMultiplier(player)
		local multiplier = getCashMultiplier(player)
		return multiplier * self.PlayerService:GetFriendBoostMultiplier(player)
	end

	function Tycoon:_FlushCollectorDisplay()
		self.CollectorDisplayUpdatePending = false

		if not self.CollectorDisplayLabel then
			return
		end

		self.CollectorDisplayLabel.Text = self:_FormatCollectorAmount(self.CollectorAmount)
	end

	function Tycoon:_QueueCollectorDisplayUpdate(force)
		if force then
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
                                end,
                        },
                })
	end

	function Tycoon:_AddCollectorAmount(baseAmount)
		local owner = self.Owner
		if not owner then
			return
		end

		self.CollectorAmount += baseAmount * self:_GetCashMultiplier(owner)
		self:_QueueCollectorDisplayUpdate(false)
	end

	function Tycoon:_SetupCollector()
		local request: ProximityPrompt = self.ATM.Display.Request
		self.CollectorDisplayLabel = self.ATM.Display.SurfaceGui.Money
		self.CollectorDisplayUpdatePending = false
		self:_QueueCollectorDisplayUpdate(true)

		local debounce = false
		local cooldown = 3

		request.Triggered:Connect(function(player)
			if player ~= self.Owner then
				return
			end

			if debounce then
				return
			end

			local finalAmount = self.CollectorAmount
			if finalAmount <= 0 then
				return
			end

			if self.PlayerService:HasX2(player) then
				finalAmount *= 2
			end

			if ClientSignals then
				ClientSignals.Send(player, "CashCollected", {
					amount = finalAmount,
					origin = getOrigin(self.ATM.Display),
				})
			end

			self.CollectorAmount = 0
			self:_QueueCollectorDisplayUpdate(true)

			if player.Parent then
				ProfileManager.AddCash(player, finalAmount)
			end

                        debounce = true
                        ECS.createEntity({
                                Name = `{self.Model.Name}:CollectorCooldown`,
                                Tycoon = self,
                                ScheduledTask = {
                                        delay = cooldown,
                                        elapsed = 0,
                                        callback = function()
                                                debounce = false
                                        end,
                                },
                        })
                end)
        end
end

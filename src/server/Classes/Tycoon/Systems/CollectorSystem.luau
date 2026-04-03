local DISPLAY_UPDATE_INTERVAL = 0.25

local function getNumericAttribute(player, attributeName)
	local value = player:GetAttribute(attributeName)
	if type(value) == "number" then
		return value
	end

	return 1
end

return function(Tycoon, dependencies)
	local ProfileManager = dependencies.ProfileManager

	function Tycoon:_FormatCollectorAmount(amount)
		local rounded = math.round(amount * 10) / 10
		if rounded == math.floor(rounded) then
			return tostring(rounded)
		end

		return string.format("%.1f", rounded)
	end

	function Tycoon:_GetCashMultiplier(player)
		local multiplier = getNumericAttribute(player, "Multiplier")
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
		task.delay(DISPLAY_UPDATE_INTERVAL, function()
			if self.CollectorDisplayUpdatePending then
				self:_FlushCollectorDisplay()
			end
		end)
	end

	function Tycoon:_AddCollectorAmount(baseAmount)
		local owner = self.OwnerValue.Value
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
			if player ~= self.OwnerValue.Value then
				return
			end

			if debounce then
				return
			end

			local finalAmount = self.CollectorAmount
			if self.PlayerService:HasX2(player) then
				finalAmount *= 2
			end

			ProfileManager.AddCash(player, finalAmount)
			self.CollectorAmount = 0
			self:_QueueCollectorDisplayUpdate(true)

			debounce = true
			task.wait(cooldown)
			debounce = false
		end)
	end
end

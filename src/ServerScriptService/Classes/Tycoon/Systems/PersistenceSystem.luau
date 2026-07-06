local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.ECS)

type PurchaseFeedbackOptions = {
	unlockNext: boolean?,
	playEffects: boolean?,
	recordPurchase: boolean?,
	saveState: boolean?,
	sound: Sound?,
}

type ConstructionData = {
	PurchasedButtons: { string },
}

return function(Tycoon, dependencies)
	local ProfileManager = dependencies.ProfileManager

	local function getConstructionData(profile): ConstructionData
		if type(profile.Data.TycoonConstruction) ~= "table" then
			profile.Data.TycoonConstruction = {
				PurchasedButtons = {},
			}
		end

		local constructionData = profile.Data.TycoonConstruction :: ConstructionData
		if type(constructionData.PurchasedButtons) ~= "table" then
			constructionData.PurchasedButtons = {}
		end

		return constructionData
	end

	function Tycoon:_ResetConstructionTracking()
		self.PurchasedButtonLookup = {}
		self.PurchasedButtonOrder = {}
	end

	function Tycoon:_PlayPurchaseFeedback(button: BasePart, optionalSound: Sound?)
		local activationClone = self.Activation:Clone()
		activationClone.Parent = self.MainItems

		local particleEmitter: ParticleEmitter = activationClone.Activation1
		activationClone.CFrame = button.CFrame * CFrame.new(0, 1.65, 0)
		particleEmitter:Emit(1)

                if optionalSound then
                        optionalSound:Play()
                end

                ECS.createEntity({
                        Name = `{self.Model.Name}:PurchaseFeedbackCleanup`,
                        Tycoon = self,
                        ScheduledTask = {
                                delay = 3,
                                elapsed = 0,
                                callback = function()
                                        activationClone:Destroy()
                                end,
                        },
                })
        end

	function Tycoon:_SaveConstruction(player: Player)
		local profile = ProfileManager.Profiles[player]
		if not profile then
			return
		end

		local constructionData: ConstructionData = getConstructionData(profile)
		table.clear(constructionData.PurchasedButtons)

		for index, buttonName in ipairs(self.PurchasedButtonOrder) do
			constructionData.PurchasedButtons[index] = buttonName
		end

		warn(`[TycoonPersistence] Saved {#constructionData.PurchasedButtons} purchased buttons for {player.Name}`)
	end

	function Tycoon:_ClearSavedConstruction(player: Player)
		local profile = ProfileManager.Profiles[player]
		if not profile then
			return
		end

		local constructionData: ConstructionData = getConstructionData(profile)
		table.clear(constructionData.PurchasedButtons)
		self:_ResetConstructionTracking()

		warn(`[TycoonPersistence] Cleared saved construction for {player.Name}`)
	end

	function Tycoon:_RecordPurchasedButton(buttonName: string, shouldSave: boolean?)
		if self.PurchasedButtonLookup[buttonName] then
			return
		end

		self.PurchasedButtonLookup[buttonName] = true
		table.insert(self.PurchasedButtonOrder, buttonName)

		local owner = self.Owner
		if shouldSave ~= false and owner then
			self:_SaveConstruction(owner)
		end
	end

	function Tycoon:_ApplyPurchasedButton(button: BasePart, options: PurchaseFeedbackOptions?): boolean
		if not button or not button.Parent then
			return false
		end

		local resolvedOptions: PurchaseFeedbackOptions = options or {}
		local buttonName = button.Name
		local Config = self:_GetButtonConfig(buttonName)
		if not Config then
			warn(`[TycoonPersistence] Missing button configuration for {buttonName}`)
			return false
		end

		self:_SpawnButtonItems(Config, resolvedOptions)
		if resolvedOptions.unlockNext ~= false then
			self:_UnlockNextButtons(Config)
		end

                if resolvedOptions.playEffects ~= false then
                        self:_PlayPurchaseFeedback(button, resolvedOptions.sound)
                end

                self:_MarkButtonPurchased(button)
                button:Destroy()
		if resolvedOptions.recordPurchase ~= false then
                        self:_RecordPurchasedButton(buttonName, resolvedOptions.saveState)
		end

		if self._UpdateRebirthAvailability then
			self:_UpdateRebirthAvailability()
		end

		return true
	end

	function Tycoon:_RestoreSavedConstruction(player: Player)
		local profile = ProfileManager.Profiles[player]
		if not profile then
			return
		end

		local constructionData: ConstructionData = getConstructionData(profile)
		local purchasedButtons: { string } = constructionData.PurchasedButtons
		if #purchasedButtons == 0 then
			return
		end

		self:_ResetConstructionTracking()
		warn(`[TycoonPersistence] Restoring {#purchasedButtons} purchased buttons for {player.Name}`)

		for _, buttonName in ipairs(purchasedButtons) do
			local button = self.Buttons:FindFirstChild(buttonName)
			if button and button:IsA("BasePart") then
				self:_ApplyPurchasedButton(button, {
					playEffects = false,
					saveState = false,
				})
			else
				warn(`[TycoonPersistence] Could not find saved button "{buttonName}" in tycoon "{self.Model.Name}"`)
			end
		end

		self:_SaveConstruction(player)
	end
end

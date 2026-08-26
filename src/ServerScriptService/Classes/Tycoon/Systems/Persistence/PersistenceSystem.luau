--!strict
--[[
	@class PersistenceSystem

	@desc
	Handles saving and restoring tycoon construction data (purchased buttons)
	to player profiles. Orchestrates purchase replay on re-claim through
	the _ApplyPurchasedButton workflow.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)

--// Types

type PurchaseFeedbackOptions = {
	unlockNext: boolean?,
	playEffects: boolean?,
	recordPurchase: boolean?,
	saveState: boolean?,
	sound: Sound?
}

type ConstructionData = {
	PurchasedButtons: { string }
}

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Internal Utilities

	local function GetConstructionData(Profile: any): ConstructionData
		if type(Profile.Data.TycoonConstruction) ~= "table" then
			Profile.Data.TycoonConstruction = {
				PurchasedButtons = {}
			}
		end

		local ConstructionData = Profile.Data.TycoonConstruction :: ConstructionData
		if type(ConstructionData.PurchasedButtons) ~= "table" then
			ConstructionData.PurchasedButtons = {}
		end

		return ConstructionData
	end

	--// Public API

	function Tycoon:_ResetConstructionTracking()
		self.PurchasedButtonLookup = {}
		self.PurchasedButtonOrder = {}
	end

	function Tycoon:_PlayPurchaseFeedback(Button: BasePart, OptionalSound: Sound?)
		local ActivationClone = self.Activation:Clone()
		ActivationClone.Parent = self.MainItems

		local ParticleEmitter: ParticleEmitter = ActivationClone.Activation1
		ActivationClone.CFrame = Button.CFrame * CFrame.new(0, 1.65, 0)
		ParticleEmitter:Emit(1)

		if OptionalSound then
			OptionalSound:Play()
		end

		ECS.createEntity({
			Name = `{self.Model.Name}:PurchaseFeedbackCleanup`,
			Tycoon = self,
			ScheduledTask = {
				delay = 3,
				elapsed = 0,
				callback = function()
					ActivationClone:Destroy()
				end
			}
		})
	end

	function Tycoon:_SaveConstruction(Player: Player)
		local Profile = ProfileManager.Profiles[Player]
		if not Profile then
			return
		end

		local ConstructionData: ConstructionData = GetConstructionData(Profile)
		table.clear(ConstructionData.PurchasedButtons)

		for Index, ButtonName in self.PurchasedButtonOrder do
			ConstructionData.PurchasedButtons[Index] = ButtonName
		end

		warn(`[TycoonPersistence] Saved {#ConstructionData.PurchasedButtons} purchased buttons for {Player.Name}`)
	end

	function Tycoon:_ClearSavedConstruction(Player: Player)
		local Profile = ProfileManager.Profiles[Player]
		if not Profile then
			return
		end

		local ConstructionData: ConstructionData = GetConstructionData(Profile)
		table.clear(ConstructionData.PurchasedButtons)
		self:_ResetConstructionTracking()

		warn(`[TycoonPersistence] Cleared saved construction for {Player.Name}`)
	end

	function Tycoon:_RecordPurchasedButton(ButtonName: string, ShouldSave: boolean?)
		if self.PurchasedButtonLookup[ButtonName] then
			return
		end

		self.PurchasedButtonLookup[ButtonName] = true
		table.insert(self.PurchasedButtonOrder, ButtonName)

		local Owner = self.Owner
		if ShouldSave ~= false and Owner then
			self:_SaveConstruction(Owner)
		end
	end

	function Tycoon:_ApplyPurchasedButton(Button: BasePart, Options: PurchaseFeedbackOptions?): boolean
		if not Button or not Button.Parent then
			return false
		end

		local ResolvedOptions: PurchaseFeedbackOptions = Options or {}
		local ButtonName = Button.Name
		local Config = self:_GetButtonConfig(ButtonName)
		if not Config then
			warn(`[TycoonPersistence] Missing button configuration for {ButtonName}`)
			return false
		end

		local SpawnOptions = ResolvedOptions or {}
		SpawnOptions.buttonConfig = Config
		self:_SpawnButtonItems(Config, SpawnOptions)
		if ResolvedOptions.unlockNext ~= false then
			self:_UnlockNextButtons(Config)
		end

		if ResolvedOptions.playEffects ~= false then
			self:_PlayPurchaseFeedback(Button, ResolvedOptions.sound)
		end

		self:_MarkButtonPurchased(Button)
		Button:Destroy()
		if ResolvedOptions.recordPurchase ~= false then
			self:_RecordPurchasedButton(ButtonName, ResolvedOptions.saveState)
		end

		if self._UpdateRebirthAvailability then
			self:_UpdateRebirthAvailability()
		end

		return true
	end

	function Tycoon:_RestoreSavedConstruction(Player: Player)
		local Profile = ProfileManager.Profiles[Player]
		if not Profile then
			return
		end

		local ConstructionData: ConstructionData = GetConstructionData(Profile)
		local PurchasedButtons: { string } = ConstructionData.PurchasedButtons
		if #PurchasedButtons == 0 then
			return
		end

		self:_ResetConstructionTracking()
		warn(`[TycoonPersistence] Restoring {#PurchasedButtons} purchased buttons for {Player.Name}`)

		for _, ButtonName in PurchasedButtons do
			local Button = self.Buttons:FindFirstChild(ButtonName)
			if Button and Button:IsA("BasePart") then
				self:_ApplyPurchasedButton(Button, {
					playEffects = false,
					saveState = false
				})
			else
				warn(`[TycoonPersistence] Could not find saved button "{ButtonName}" in tycoon "{self.Model.Name}"`)
			end
		end

		self:_SaveConstruction(Player)
	end
end

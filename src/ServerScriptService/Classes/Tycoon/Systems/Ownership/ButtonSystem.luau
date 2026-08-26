--!strict
--[[
	@class ButtonSystem

	@desc
	Core button system: completion checks, button setup, touch purchase flow,
	gamepass prompting, cash deduction, rebirth availability updates.
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Packets = require(ReplicatedStorage.Network.Packets)
const ButtonConfiguration = require(script.Parent.Parent.Parent.Configuration.ButtonConfiguration)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)

--// Constants

const PurchaseCooldown = 1.5

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	-- Prevents double-touch opening multiple gamepass prompts for one button.
	const PurchaseDebounceByButton: { [BasePart]: number } = {}

	--// Public API — CheckCompletion

	function Tycoon.CheckCompletion(self, ButtonFolder: Folder): boolean
		for _, Button in ButtonFolder:GetChildren() do
			if not Button:IsA("BasePart") then
				continue
			end

			const Config = ButtonConfiguration.Get(Button.Name)
			if not Config then
				warn(`[Tycoon] Completion check found unknown button {Button.Name}`)
				self.CompletedTycoon = false
				return false
			end

			if ButtonConfiguration.GetKind(Config) == "Basic" and ButtonConfiguration.GetGamepass(Config) == nil then
				self.CompletedTycoon = false
				return false
			end
		end
		self.CompletedTycoon = true
		return true
	end

	--// Internal Methods — Setup

	function Tycoon:_SetupButtons()
		for _, Button in self.Buttons:GetChildren() do
			if Button:IsA("BasePart") then
				self:_SetupButton(Button)
			end
		end
	end

	function Tycoon:_GetButtonConfig(ButtonName: string)
		return ButtonConfiguration.Get(ButtonName)
	end

	function Tycoon:_SetupButton(Button: BasePart)
		const Config = ButtonConfiguration.Get(Button.Name)
		if not Config then
			warn(`[Tycoon] No button configuration exists for {Button:GetFullName()}`)
			Button.Transparency = 1
			Button.CanCollide = false
			Button.CanTouch = false
			return
		end

		ButtonConfiguration.ApplyVisual(Button, Config)

		if ButtonConfiguration.GetKind(Config) == "Rebirth" then
			Button:Destroy()
			self:_UpdateRebirthAvailability()
			return
		end

		const Price = ButtonConfiguration.GetPrice(Config)
		const Gamepass = ButtonConfiguration.GetGamepass(Config)
		const Kind = ButtonConfiguration.GetKind(Config)

		if not self.ButtonEntities[Button] then
			self.ButtonEntities[Button] = ECS.createEntity({
				Name = `{self.Model.Name}:{Button.Name}:Button`,
				Model = Button,
				Tycoon = self,
				Button = {
					button = Button,
					tycoon = self,
					price = Price,
					gamepass = Gamepass,
					buttonType = Kind,
					visible = ButtonConfiguration.StartsVisible(Config),
				},
			})
		end

		if Price == nil and Gamepass == nil then
			return
		end

		if Button.Transparency == 1 then
			Button.CanCollide = false
			const Billboard = Button:FindFirstChild("BillboardGui")
			if Billboard then
				Billboard.Enabled = false
			end
		end

		Button.Touched:Connect(function(Hit: Instance)
			if Button.Transparency == 1 then
				return
			end

			const Player = Players:GetPlayerFromCharacter(Hit.Parent)
			if not Player or self.Owner ~= Player then
				return
			end

			self:_ProcessButtonPurchase(Player, Button)
		end)
	end

	function Tycoon:_MarkButtonPurchased(Button: BasePart, Player: Player?)
		const ButtonEntity = self.ButtonEntities[Button]
		if not ButtonEntity then
			return
		end

		ECS.set(ButtonEntity, "Purchased", {
			player = Player or self.Owner,
			purchasedAt = os.clock(),
		})
	end

	--// Internal Methods — Purchase

	function Tycoon:_ProcessButtonPurchase(Player: Player, Button: BasePart)
		const Config = ButtonConfiguration.Get(Button.Name)
		if not Config then
			warn(`[Tycoon] Button configuration missing for {Button:GetFullName()}`)
			return
		end

		const Profile = ProfileManager.Profiles[Player]
		if not Profile then
			warn(`[Tycoon] Profile unavailable while processing button "{Button.Name}" for {Player.Name}`)
			return
		end

		if not self:_CheckDependencies(Config) then
			warn("Dependencies not met for:", Button.Name)
			return
		end

		const Gamepass = ButtonConfiguration.GetGamepass(Config)
		if Gamepass then
			-- Debounce: prevent double-touch opening multiple purchase prompts.
			const Now = os.clock()
			const Last = PurchaseDebounceByButton[Button]
			if Last and Now - Last < PurchaseCooldown then
				return
			end
			PurchaseDebounceByButton[Button] = Now

			self.PurchaseService:PromptGamepass(Player, Button, self, Gamepass)
			return
		end

		const Price = ButtonConfiguration.GetPrice(Config)
		if Price then
			const Cash = Profile.Data.Cash
			if Cash >= Price then
				ProfileManager.AddCash(Player, -Price)
				self:_ApplyPurchasedButton(Button)
			else
				Packets.packets.Notification.sendTo({ ["type"] = "error", message = "Not enough cash" }, Player)
			end
		end
	end

	function Tycoon:_UpdateRebirthAvailability()
		const Owner = self.Owner
		if not Owner then
			return
		end

		PlayerRuntimeState.SetCanRebirth(Owner, self:CheckCompletion(self.Buttons))
	end
end


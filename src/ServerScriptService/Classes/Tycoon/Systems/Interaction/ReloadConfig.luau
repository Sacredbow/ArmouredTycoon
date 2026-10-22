--!strict
--[[
	@class ReloadConfig

	@desc
	Handles weapon reload prompt interactions. When the tycoon owner activates
	the Lakester NPC's proximity prompt, this module refills all compatible
	guns in the player's inventory.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Packets = require(ReplicatedStorage.Network.Packets)
const WeaponDefinitionResolver = require(ReplicatedStorage.Weapons.Resolver)
const SoundService = game:GetService("SoundService")
const ServerStorage = game:GetService("ServerStorage")

--// Constants

const SFX = SoundService.SFX
const RefillSound = SFX.Common.Interactions.RefillSound

const Universal = true
const BulletType = "Universal"
const Infinite = true
const Stored = ServerStorage.Constants.Stored

--// Types

type GunSettingsType = {
	Type: string,
	BulletType: string
}

--// Module

const ReloadConfig: { onPromptTriggered: (Player) -> () } = {}

--// Public API

function ReloadConfig.onPromptTriggered(Player: Player)
	local Character = Player.Character
	local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Character or not Humanoid or Humanoid.Health <= 0 then
		return
	end

	local function processTool(Child: Instance)
		if not Child:IsA("Tool") then
			return
		end
		local SettingsModule = WeaponDefinitionResolver.getSettings(Child)
		local ClientState = Child:FindFirstChild("ACS_Client")
		local StoredValue = ClientState and ClientState:FindFirstChild("Stored")
		local TotalMagsValue = ClientState and ClientState:FindFirstChild("TotalMags")

		if SettingsModule and StoredValue and TotalMagsValue and StoredValue:IsA("NumberValue") and TotalMagsValue:IsA("NumberValue") then
			local GunSettings = require(SettingsModule) :: GunSettingsType
			local CompatibleAmmo = Universal or GunSettings.BulletType == BulletType

			if GunSettings.Type == "Gun" and CompatibleAmmo then
				StoredValue.Value = TotalMagsValue.Value
				Packets.packets.RefillPresentation.sendTo({ tool = Child, infinite = Infinite, amount = if Stored:IsA("NumberValue") then Stored.Value else 0 }, Player)
				RefillSound:Play()
			end
		end
	end

	for _, Child in Character:GetChildren() do
		processTool(Child)
	end

	local Backpack = Player:FindFirstChildOfClass("Backpack")
	if Backpack then
		for _, Child in Backpack:GetChildren() do
			processTool(Child)
		end
	end
end

return ReloadConfig

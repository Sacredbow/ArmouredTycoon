--!strict
--[[
	Pure reload action. The prompt boundary produces a Reload intent and this
	module applies the weapon inventory transformation for the owning player.
]]
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)
const WeaponDefinitionResolver = require(ReplicatedStorage.Shared.Game.Combat.Weapons.Resolver)
const SoundService = game:GetService("SoundService")
const ServerStorage = game:GetService("ServerStorage")
const RefillSound = SoundService.SFX.Common.Interactions.RefillSound
const Universal = true
const BulletType = "Universal"
const Infinite = true
const Stored = ServerStorage.Constants.Stored
const ReloadConfig = {}
function ReloadConfig.RefillWeapons(Player: Player)
	const Character = Player.Character
	const Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
	if not Character or not Humanoid or Humanoid.Health <= 0 then
		return
	end

	local function ProcessTool(Child: Instance)
		if not Child:IsA("Tool") then
			return
		end
		const GunSettings = WeaponDefinitionResolver.getSettingsData(Child)
		const ClientState = Child:FindFirstChild("ACS_Client")
		const StoredValue = ClientState and ClientState:FindFirstChild("Stored")
		const TotalMagsValue = ClientState and ClientState:FindFirstChild("TotalMags")
		if
			type(GunSettings) ~= "table"
			or not StoredValue
			or not TotalMagsValue
			or not StoredValue:IsA("NumberValue")
			or not TotalMagsValue:IsA("NumberValue")
		then
			return
		end
		if GunSettings.Type ~= "Gun" or not (Universal or GunSettings.BulletType == BulletType) then
			return
		end
		StoredValue.Value = TotalMagsValue.Value
		Packets.packets.RefillPresentation.sendTo(
			{ tool = Child, infinite = Infinite, amount = if Stored:IsA("NumberValue") then Stored.Value else 0 },
			Player
		)
		RefillSound:Play()
	end

	for _, Child in Character:GetChildren() do
		ProcessTool(Child)
	end
	const Backpack = Player:FindFirstChildOfClass("Backpack")
	if Backpack then
		for _, Child in Backpack:GetChildren() do
			ProcessTool(Child)
		end
	end
end

return ReloadConfig

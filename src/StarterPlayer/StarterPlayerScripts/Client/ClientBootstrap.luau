--!strict
-- Central client feature bootstrap. Loader.client.luau is the only LocalScript.

local Client = script.Parent

local ClientBootstrap = {}

function ClientBootstrap.Start()
	require(Client.Core.ECS.ECSRuntime)

	require(Client.Features.Character.CharacterMotion)
	require(Client.Features.Character.GameplayCamera)

	require(Client.Features.Inventory.InventoryClient)

	require(Client.Features.Effects.CashCollectEffect)
	require(Client.Features.Effects.LightningEffect)
	require(Client.Features.Effects.NukeCinematic)
	require(Client.Features.Effects.ShootingStarEffect)
	require(Client.Features.Effects.ClientVisuals.DropperVisuals)
	require(Client.Features.Effects.ClientVisuals.EffectHandler)
	require(Client.Features.Effects.ClientVisuals.WorldHandler)

	require(Client.Features.Environment.init)

	require(Client.Features.Gameplay.GunRegistry)
	require(Client.Features.Gameplay.Onboarding)

	require(Client.Features.Interaction.ProximityService.PromptRegistry.init)

	require(Client.Features.NPC.NPCAnimationController)
	require(Client.Features.NPC.NPCBubble)

	require(Client.Features.Settings.SettingsHandler)
	require(Client.Features.Settings.TopbarHandler)

	require(Client.Presentation.UI.AppBootstrap)
end

return ClientBootstrap

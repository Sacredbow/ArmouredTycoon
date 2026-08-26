--!strict
--[[
	@class MigrationSystem

	@desc
	Reconciles saved tycoon construction data when ButtonConfiguration changes
	between game updates. Runs custom per-version migrations, then prunes
	orphaned button names that no longer exist in the configuration.
]]

--// Services

const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const ButtonConfiguration = require(script.Parent.Parent.Parent.Configuration.ButtonConfiguration)

--// Constants

local CURRENT_CONFIG_VERSION = 1

--// Types

type MigrationFunction = (purchasedButtons: { string }) -> { string }

--// Custom Migrations

-- Keyed by the version they bring save data TO. Bump CURRENT_CONFIG_VERSION
-- and add an entry here whenever a published config change needs migration.
local Migrations: { [number]: MigrationFunction } = {
	-- [2] = function(buttons)
	-- 	-- Example: Button10 was renamed to Button10A
	-- 	for i, name in ipairs(buttons) do
	-- 		if name == "Button10" then buttons[i] = "Button10A" end
	-- 	end
	-- 	return buttons
	-- end,
}

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Public API

	function Tycoon:_MigrateConstruction(Player: Player)
		local Profile = ProfileManager.Profiles[Player]
		if not Profile then
			return
		end

		local ConstructionData = Profile.Data.TycoonConstruction
		if type(ConstructionData) ~= "table" then
			return
		end

		const SavedVersion = ConstructionData.ConfigVersion or 1
		if SavedVersion >= CURRENT_CONFIG_VERSION then
			return
		end

		local PurchasedButtons = ConstructionData.PurchasedButtons
		if type(PurchasedButtons) ~= "table" then
			ConstructionData.ConfigVersion = CURRENT_CONFIG_VERSION
			return
		end

		warn(`[Migration] Checking {Player.Name}: v{SavedVersion} -> v{CURRENT_CONFIG_VERSION}`)

		-- Run custom migrations for each version gap
		for Version = SavedVersion + 1, CURRENT_CONFIG_VERSION do
			const Migration = Migrations[Version]
			if Migration then
				warn(`[Migration] Running migration v{Version} for {Player.Name}`)
				PurchasedButtons = Migration(PurchasedButtons)
			end
		end

		-- Automatic orphan cleanup: remove buttons that no longer exist in config
		const ValidButtons: { string } = {}
		local RemovedCount = 0
		for _, ButtonName in ipairs(PurchasedButtons) do
			if ButtonConfiguration.Get(ButtonName) then
				table.insert(ValidButtons, ButtonName)
			else
				RemovedCount += 1
				warn(`[Migration] Removing orphaned button '{ButtonName}' from {Player.Name}'s save data`)
			end
		end

		ConstructionData.PurchasedButtons = ValidButtons
		ConstructionData.ConfigVersion = CURRENT_CONFIG_VERSION

		warn(`[Migration] Migrated {Player.Name} to v{CURRENT_CONFIG_VERSION} ({RemovedCount} orphaned buttons removed)`)
	end
end


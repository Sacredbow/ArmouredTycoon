--!strict
--[[
	@class ClaimSystem

	@desc
	Ownership lifecycle for a tycoon: door claim detection, ownership transfer,
	team assignment, build-assemble sequence, respawn binding, onboarding, and
	cleanup on player leave / rebirth.
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const ServerScriptService = game:GetService("ServerScriptService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Packets = require(ReplicatedStorage.Network.Packets)
const OnboardingDefinitions = require(ReplicatedStorage.Progression.Onboarding.OnboardingDefinitions)
const BuildAssemble = require(ReplicatedStorage.Libraries.BuildAssemble)
const ProfileManager = require(ServerScriptService.DataManager.ProfileManager)
const PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
const Notify = require(script.Parent.Parent.Parent.Utilities.Notify)

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Internal Methods — Setup

	function Tycoon:_SetupDoor()
		const OwnerDoor = self.MainItems:FindFirstChild("OwnerDoor")
		if not OwnerDoor then
			warn(`[Tycoon] OwnerDoor missing in {self.Model.Name}`)
			return
		end

		const Door = OwnerDoor:WaitForChild("Door") :: BasePart

		Door.Touched:Connect(function(Hit: Instance)
			const Player = Players:GetPlayerFromCharacter(Hit.Parent)
			if not Player then
				return
			end
			if self.PlayerService:OwnsTycoon(Player) then
				Notify(Player, "info", "You already own a tycoon.")
				return
			end
			if not self.Owner then
				self:_ClaimTycoon(Player)
			end
		end)
	end

	--// Internal Methods — Claim

	function Tycoon:_ClaimTycoon(Player: Player)
		-- Security guard: never allow claiming an already-owned tycoon.
		if self.Owner then
			warn(`[Tycoon] Refused to re-claim {self.Model.Name} (already owned)`)
			return
		end

		print("Claimed by:", Player.Name)

		self.Owner = Player
		ECS.set(self.Entity, "Owner", Player)

		self.PlayerService:RegisterPlayerTycoon(Player, self)

		const Door = self.MainItems.OwnerDoor.Door :: BasePart
		const TitleLabel = self.MainItems.OwnerDoor.Title.SurfaceGui.TextLabel :: TextLabel
		TitleLabel.Text = Player.Name .. "'s Tycoon"
		Door.Transparency = 0.6

		--self:_AssignTeam(Player)

		--const ClaimBuildRoots = {
		--	self.Stages,
		--	self.Droppers,
		--	self.GunModels,
		--	self.Components,
		--}
		--local ClaimBuildIndex = 0
		--local function PlayNextClaimBuild()
		--	ClaimBuildIndex += 1
		--	const ClaimBuildRoot = ClaimBuildRoots[ClaimBuildIndex]
		--	if not ClaimBuildRoot then
		--		return
		--	end

		--	BuildAssemble.Play(ClaimBuildRoot, PlayNextClaimBuild, {
		--		includeHidden = false,
		--		timingScale = 1.85,
		--		pieceBudget = 90,
		--		maxPiecesPerPart = 1,
		--		creationBatchSize = 8,
		--		staggerPortion = 0.85,
		--	})
		--end
		--PlayNextClaimBuild()

		const Spawn = self.MainItems:FindFirstChild("TycoonSpawn") :: BasePart?
		if Spawn then
			-- Disconnect any stale respawn binding before replacing it.
			if self.CharacterAddedConn then
				self.CharacterAddedConn:Disconnect()
				self.CharacterAddedConn = nil
			end

			self.CharacterAddedConn = Player.CharacterAdded:Connect(function(Char: Model)
				self.PlayerService:AllowServerTeleport(Player)
				Char:PivotTo(Spawn.CFrame)
			end)
		end

		self:_MigrateConstruction(Player)
		self:_RestoreSavedConstruction(Player)
		if self.PlayerService.BuildService then
			self.PlayerService.BuildService:RestorePlayer(Player, self)
		end
		self:_UpdateRebirthAvailability()
		Packets.packets.Tutorial.sendTo({ ["type"] = "TycoonClaimed", target = self.Model.Name }, Player)
		self:_StartOnboarding()
	end

	function Tycoon:_AssignTeam(Player: Player)
		const Teams = game:GetService("Teams")

		-- Tycoon8 (Purple) intentionally missing — no team object assigned.
		const TeamMap = {
			Tycoon1 = "Destroyer",
			Tycoon2 = "Alpha",
			Tycoon3 = "Inferno",
			Tycoon4 = "Warrior",
			Tycoon5 = "Violent",
			Tycoon6 = "Vengeance",
			Tycoon7 = "Powerhouse",
		}

		const TeamName = TeamMap[self.Model.Name]
		if TeamName then
			Player.Team = Teams:FindFirstChild(TeamName) :: Team?
		end
	end

	--// Internal Methods — Onboarding

	function Tycoon:_StartOnboarding()
		const Owner = self.Owner
		if not Owner or ProfileManager.HasCompletedOnboarding(Owner) then
			return
		end

		local function OnboardingComplete(): boolean
			return self.Owner == nil or ProfileManager.HasCompletedOnboarding(self.Owner)
		end

		local function TargetPath(...: string): string
			const Segments = { self.Model.Name, ... }
			return table.concat(Segments, ":")
		end

		Packets.packets.Tutorial.sendTo(
			{ ["type"] = OnboardingDefinitions.STEP_BY_KEY.ClaimComplete.Message },
			Owner
		)

		task.wait(3)
		if OnboardingComplete() then
			return
		end

		if not self.Owner then
			return
		end

		Packets.packets.Tutorial.sendTo(
			{
				["type"] = OnboardingDefinitions.STEP_BY_KEY.PurchaseButton.Message,
				target = TargetPath("Buttons", "Button1"),
			},
			self.Owner
		)

		local ButtonRemovedConnection: RBXScriptConnection?
		local ATMConnection: RBXScriptConnection?

		ButtonRemovedConnection = self.Buttons.ChildRemoved:Connect(function()
			if OnboardingComplete() then
				if ButtonRemovedConnection then
					ButtonRemovedConnection:Disconnect()
					ButtonRemovedConnection = nil
				end
				return
			end

			if not self.Buttons:FindFirstChild("Button1") then
				Packets.packets.Tutorial.sendTo(
					{
						["type"] = OnboardingDefinitions.STEP_BY_KEY.ClaimMoney.Message,
						target = TargetPath("MainItems", "ATM", "Display"),
					},
					self.Owner
				)

				const ATMPrompt = self.ATM.Display.Request :: ProximityPrompt

				if ATMConnection then
					ATMConnection:Disconnect()
					ATMConnection = nil
				end

				ATMConnection = ATMPrompt.Triggered:Connect(function(Player: Player)
					if Player == self.Owner and not ProfileManager.HasCompletedOnboarding(Player) then
						Packets.packets.Tutorial.sendTo(
							{ ["type"] = OnboardingDefinitions.STEP_BY_KEY.Completed.Message },
							self.Owner
						)
						ProfileManager.OnboardingSuccess(Player)

						if ButtonRemovedConnection then
							ButtonRemovedConnection:Disconnect()
							ButtonRemovedConnection = nil
						end
						if ATMConnection then
							ATMConnection:Disconnect()
							ATMConnection = nil
						end
					end
				end)
			end
		end)
	end

	--// Public API — Cleanup

	function Tycoon.Cleanup(self)
		const PreviousOwner = self.Owner
		if PreviousOwner then
			self:_SaveConstruction(PreviousOwner)
		end

		const Door = self.MainItems.OwnerDoor.Door :: BasePart
		const TitleLabel = self.MainItems.OwnerDoor.Title.SurfaceGui.TextLabel :: TextLabel
		TitleLabel.Text = "Unclaimed Tycoon"
		Door.Transparency = 0.25

		(self.ATM :: any).Display.SurfaceGui.Money.Text = "0"
		self.CollectorAmount = 0
		self:_QueueCollectorDisplayUpdate(true)

		if self.Buttons then
			for _, Entity in self.ButtonEntities do
				ECS.deleteEntity(Entity)
			end
			table.clear(self.ButtonEntities)

			self.Buttons:Destroy()
			self.Buttons = self.ButtonTemplate:Clone() :: Folder
			self.Buttons.Parent = self.Model
			self:_SetupButtons()
		end

		self:_StopAllDropperLoops()
		self:_RestoreMovedItems()

		for _, Item in self.PurchasedItems:GetChildren() do
			Item:Destroy()
		end

		for _, Visual in self.DropperVisualsFolder:GetChildren() do
			Visual:Destroy()
		end

		if self.PlayerService.BuildService then
			self.PlayerService.BuildService:ReleaseTycoon(self)
		end

		self.x2Upgraders = {}
		self.x3Upgraders = {}
		self.AppliedUpgraders = {}
		self:_ResetConstructionTracking()

		-- Re-apply NPC collision groups for rebirth (NPC models may have respawned).
		if self.Owner and self.Owner.Character then
			self.CollisionManager.SetupPlayerCharacter(self.Owner.Character)
		end

		const Stage4 = self.Stages:FindFirstChild("Stage4")
		if Stage4 then
			const Fences = Stage4:FindFirstChild("Fences")
			if Fences then
				const Leaver = Fences:FindFirstChild("Leaver")
				if Leaver and Leaver:FindFirstChild("Prompt") then
					const Prompt = Leaver.Prompt:FindFirstChild("ProximityPrompt")
					if Prompt and Prompt:IsA("ProximityPrompt") then
						Prompt.ActionText = "Open Gate"
					end
				end
			end
		end

		const ButtonStand = self.Components and self.Components:FindFirstChild("ButtonStand")
		if ButtonStand and ButtonStand:FindFirstChild("Button") then
			(ButtonStand :: any).Button.BrickColor = BrickColor.new("Bright green")
		end

		if PreviousOwner then
			PlayerRuntimeState.ResetTycoonState(PreviousOwner)
		end

		self.Owner = nil
		ECS.remove(self.Entity, "Owner")

		if self.TeleportConnections then
			for _, Connection in self.TeleportConnections do
				if Connection then
					Connection:Disconnect()
				end
			end
			table.clear(self.TeleportConnections)
		end

		const CharacterAddedConn = self.CharacterAddedConn
		self.CharacterAddedConn = nil
		if CharacterAddedConn then
			CharacterAddedConn:Disconnect()
		end

		warn(`Cleanup complete: {self.Model.Name}`)
	end
end

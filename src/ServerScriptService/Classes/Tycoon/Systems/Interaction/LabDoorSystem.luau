--!strict
--[[
	@class LabDoorSystem

	@desc
	Automatic sliding door for the Scientific Lab (Stage2). Opens when the
	owner enters either Magnitude zone, auto-closes after a delay, and reopens
	if the owner is still inside (anti-squish). Uses ECS ScheduledTask entities
	for close timing and a sequence token to invalidate superseded closes.
]]

--// Services

const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const TweenManager = require(ReplicatedStorage.Modules.TweenManager) :: any

--// Constants

const OPEN_OFFSET = 13.5
const CLOSE_DELAY = 2.5
const TWEEN_INFO = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

--// Module

return function(Tycoon: any, _Dependencies: { [string]: any })

	--// Internal Methods — Setup

	function Tycoon:_SetupLabDoors()
		--// Door References
		const ScientificLab = self.Stages.Stage2:FindFirstChild("ScientificLab")
		if not ScientificLab then
			return
		end
		const Door = ScientificLab:FindFirstChild("LabDoor")
		if not Door or not Door:IsA("Model") then
			return
		end
		const Magnitude = Door:FindFirstChild("Magnitude")
		const Magnitude2 = Door:FindFirstChild("Magnitude2")
		const DoorPart = Door.PrimaryPart
		if not Magnitude or not Magnitude:IsA("BasePart") or not Magnitude2 or not Magnitude2:IsA("BasePart") or not DoorPart then
			return
		end

		--// Constants
		const BaseDoorCFrame = DoorPart.CFrame
		const OpenCFrame = BaseDoorCFrame * CFrame.new(OPEN_OFFSET, 0, 0)
		const CloseCFrame = BaseDoorCFrame * CFrame.new(-OPEN_OFFSET, 0, 0)

		--// Door State Machine
		type DoorState = "Closed" | "Open"
		local DoorState: DoorState = "Closed"
		local SequenceToken = 0
		local PendingCloseEntity = nil :: any?

		local function CancelPendingClose()
			if PendingCloseEntity then
				ECS.deleteEntity(PendingCloseEntity)
				PendingCloseEntity = nil
			end
		end

		local function IsOwnerInDoorZone(Owner: Player): boolean
			if not Owner.Character then
				return false
			end

			local function IsPlayerInBox(BoxPart: BasePart): boolean
				const Params = OverlapParams.new()
				Params.FilterDescendantsInstances = { Owner.Character }
				Params.FilterType = Enum.RaycastFilterType.Include
				const Parts = workspace:GetPartBoundsInBox(BoxPart.CFrame, BoxPart.Size, Params)
				return #Parts > 0
			end

			return IsPlayerInBox(Magnitude :: BasePart) or IsPlayerInBox(Magnitude2 :: BasePart)
		end

		-- Idempotent transition: no-op if the door is already in the target state.
		local function SetDoor(Target: DoorState)
			if DoorState == Target then
				return
			end

			SequenceToken += 1
			DoorState = Target
			CancelPendingClose()

			const TargetCFrame = if Target == "Open" then OpenCFrame else CloseCFrame
			TweenManager.Model(Door, TargetCFrame, TWEEN_INFO)
		end

		local function ScheduleClose()
			CancelPendingClose()

			const Token = SequenceToken
			PendingCloseEntity = ECS.createEntity({
				Name = `{self.Model.Name}:LabDoorClose`,
				Tycoon = self,
				ScheduledTask = {
					delay = CLOSE_DELAY,
					elapsed = 0,
					callback = function()
						PendingCloseEntity = nil

						-- Superseded by a newer open/close; do nothing.
						if Token ~= SequenceToken then
							return
						end

						const Owner = self.Owner
						if not Owner then
							SetDoor("Closed")
							return
						end

						-- Final verification handles Touched/TouchEnded ordering edge cases.
						if not IsOwnerInDoorZone(Owner) then
							SetDoor("Closed")
						end
					end,
				},
			})
		end

		local function OnZoneEntered(Hit: Instance)
			const Player = Players:GetPlayerFromCharacter(Hit.Parent)
			if not Player or Player ~= self.Owner then
				return
			end
			SetDoor("Open")
		end

		local function OnZoneExited(Hit: Instance)
			const Player = Players:GetPlayerFromCharacter(Hit.Parent)
			if not Player or Player ~= self.Owner then
				return
			end
			ScheduleClose()
		end

		--// Connections
		Magnitude.Touched:Connect(OnZoneEntered);

		Magnitude2.Touched:Connect(OnZoneEntered);

		Magnitude.TouchEnded:Connect(OnZoneExited);

		Magnitude.TouchEnded:Connect(OnZoneExited)
	end
end


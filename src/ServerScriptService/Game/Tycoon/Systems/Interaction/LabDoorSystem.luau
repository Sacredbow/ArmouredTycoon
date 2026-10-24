--!strict
-- The lab door is driven by ECS contact intents. QuickZone only translates
-- enter/exit observations into ContactIntent data; this system owns the state.
const ReplicatedStorage = game:GetService("ReplicatedStorage")
const TweenManager = require(ReplicatedStorage.Shared.Core.TweenManager) :: any
const OPEN_DELAY = 2.5
const TWEEN_INFO = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	const DeltaTime = Context.dt
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.ContactIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action ~= "LabDoorEnter" and Intent.Action ~= "LabDoorExit" then
				Remaining[#Remaining + 1] = Intent
				continue
			end

			const Data = Intent.Data
			const TycoonEntity = Data and Data.TycoonEntity
			const DoorState = TycoonEntity and World:get(TycoonEntity, Components.LabDoor)
			const Owner = TycoonEntity and World:get(TycoonEntity, Components.Owner)
			if not DoorState or not Owner or Owner.player ~= Player then
				continue
			end

			if Intent.Action == "LabDoorEnter" then
				DoorState.CloseRemaining = 0
				if not DoorState.IsOpen then
					DoorState.IsOpen = true
					if DoorState.ActiveTween then
						DoorState.ActiveTween:Cancel()
					end
					DoorState.ActiveTween = TweenManager.Model(DoorState.Door, DoorState.OpenCFrame, TWEEN_INFO)
				end
			else
				DoorState.CloseRemaining = OPEN_DELAY
			end
			World:set(TycoonEntity, Components.LabDoor, DoorState)
		end

		if #Remaining == 0 then
			World:remove(Entity, Components.ContactIntent)
		else
			World:set(Entity, Components.ContactIntent, Remaining)
		end
	end

	for Entity, DoorState in World:query(Components.LabDoor) do
		if DoorState.CloseRemaining <= 0 then
			continue
		end
		DoorState.CloseRemaining -= DeltaTime
		if DoorState.CloseRemaining <= 0 and DoorState.IsOpen then
			DoorState.IsOpen = false
			if DoorState.ActiveTween then
				DoorState.ActiveTween:Cancel()
			end
			DoorState.ActiveTween = TweenManager.Model(DoorState.Door, DoorState.BaseCFrame, TWEEN_INFO)
		end
		World:set(Entity, Components.LabDoor, DoorState)
	end
end

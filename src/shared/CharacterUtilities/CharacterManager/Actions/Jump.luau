local Jump = {}
local JumpAnimationID = "rbxassetid://93618861695116"

function Jump.Do(manager)
	-- Safety check - if somehow called when not grounded, abort
	if not manager.IsGrounded and not manager.IsPerformingAction then 
		return 
	end

	if manager.CurrentMovementTrack then
		manager.CurrentMovementTrack:Stop()
		manager.CurrentMovementTrack:Destroy()
		manager.CurrentMovementTrack = nil
		manager.MovementState = nil
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = JumpAnimationID
	local track = manager.Animator:LoadAnimation(animation)
	track.Looped = false
	track.Priority = Enum.AnimationPriority.Action
	track:Play()

	track.Stopped:Connect(function()
		track:Destroy()
		
	end)
end

return Jump
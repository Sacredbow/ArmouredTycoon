local UserInputService = game:GetService("UserInputService")
local CharacterManager = {}
CharacterManager.__index = CharacterManager

export type MovementType = "Idle" | "Walk" | "Run"
export type ActionType = "Jump"

function CharacterManager.new(character: Model)
	local self = setmetatable({}, CharacterManager)

	self.Character = character
	self.Humanoid = character:WaitForChild("Humanoid")

	self.Animator = self.Humanoid:FindFirstChildOfClass("Animator")
	if not self.Animator then
		self.Animator = Instance.new("Animator")
		self.Animator.Parent = self.Humanoid
	end

	self.MovementState = "Idle"
	self.CurrentMovementTrack = nil

	self.IsRunning = false
	self.IsPerformingAction = false
	self.IsGrounded = true
	self.JumpHeld = false

	self.PressedKeys = { W=false, A=false, S=false, D=false }
	self.NextMovementState = nil


	self.Humanoid.Jumping:Connect(function(active)
		if active then
			self:DoAction("Jump")
			self.IsGrounded = false
		end
	end)

	self.Humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			self.IsGrounded = true
			self:ResumeMovement()
		end
	end)

	return self
end


function CharacterManager:PlayAnimation(id, looped, priority)
	if self.CurrentMovementTrack then
		self.CurrentMovementTrack:Stop()
		self.CurrentMovementTrack:Destroy()
	end

	local anim = Instance.new("Animation")
	anim.AnimationId = id

	local track = self.Animator:LoadAnimation(anim)
	track.Looped = looped
	track.Priority = priority or Enum.AnimationPriority.Movement
	track:Play()

	self.CurrentMovementTrack = track
	return track
end


function CharacterManager:ChangeMovementState(state: MovementType)
	if self.MovementState == state then return end
	if self.IsPerformingAction or not self.IsGrounded then
		self.NextMovementState = state
		return
	end

	local module = script.MovementStates:FindFirstChild(state)
	if not module then return end

	self.MovementState = state
	require(module).Enter(self)
end

local GuiService = game:GetService("GuiService")

function CharacterManager:Update()
    if self.IsPerformingAction or not self.IsGrounded then return end
    if GuiService.MenuIsOpen or UserInputService:GetFocusedTextBox() then
        self:ChangeMovementState("Idle")
        return
    end

    local actualKeys = UserInputService:GetKeysPressed()
   
    local moving = self.Humanoid.MoveDirection.Magnitude > 0.05

    -- sprint check
    local isSprinting = false
    if moving then
        isSprinting = self.IsRunning
        for _, k in ipairs(actualKeys) do
            if k.KeyCode == Enum.KeyCode.LeftShift then
                isSprinting = true
                break
            end
        end
    end

    local desired = moving and (isSprinting and "Run" or "Walk") or "Idle"
    self:ChangeMovementState(desired)
end



function CharacterManager:DoAction(action: ActionType)
	if self.IsPerformingAction then return end
	if action == "Jump" and not self.IsGrounded then return end

	self.IsPerformingAction = true

	local module = script.Actions:FindFirstChild(action)
	if not module then
		self.IsPerformingAction = false
		return
	end

	require(module).Do(self)
end


function CharacterManager:ResumeMovement()
	self.IsPerformingAction = false

	if self.NextMovementState then
		self:ChangeMovementState(self.NextMovementState)
		self.NextMovementState = nil
	else
		self:Update()
	end
end

return CharacterManager

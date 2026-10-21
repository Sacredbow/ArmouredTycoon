--!strict
-- Standalone ECS lab-door system. Zone occupancy is supplied by QuickZone;
-- ownership and door state remain component data keyed by the Tycoon entity.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ECS = require(ReplicatedStorage.ECS)
local QuickZone = require(ReplicatedStorage.Packages.quickzone)
local TweenManager = require(ReplicatedStorage.Modules.TweenManager) :: any

local OPEN_OFFSET = 12
local CLOSE_DELAY = 2.5
local TWEEN_INFO = TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

local LabDoorSystem = {}

function LabDoorSystem.setup(entity: number): (() -> ())?
	local state = ECS.world:get(entity, ECS.Components.TycoonState)
	local hierarchy = ECS.world:get(entity, ECS.Components.Hierarchy)
	if not state or not hierarchy or not hierarchy.Stages then return nil end
	local stage2 = hierarchy.Stages:FindFirstChild("Stage2")
	local lab = stage2 and stage2:FindFirstChild("ScientificLab")
	local door = lab and lab:FindFirstChild("LabDoor")
	if not door or not door:IsA("Model") then return nil end
	local magnitude = door:FindFirstChild("Magnitude")
	local magnitude2 = door:FindFirstChild("Magnitude2")
	local doorPart = door.PrimaryPart
	if not magnitude or not magnitude:IsA("BasePart") or not magnitude2 or not magnitude2:IsA("BasePart") or not doorPart then
		return nil
	end

	local zone = QuickZone.Zone.fromParts({magnitude, magnitude2}, {autoSync = false})
	local observer = QuickZone.Observer.new({zones = {zone}})
	local base = doorPart.CFrame
	local open = base * CFrame.new(OPEN_OFFSET, 0, 0)
	local isOpen = false
	local token = 0
	local activeTween: any = nil

	local function setDoor(openDoor: boolean)
		if isOpen == openDoor then return end
		isOpen = openDoor
		token += 1
		if activeTween then activeTween:Cancel() end
		activeTween = TweenManager.Model(door, if openDoor then open else base, TWEEN_INFO)
	end

	local function scheduleClose()
		token += 1
		local closeToken = token
		task.delay(CLOSE_DELAY, function()
			if closeToken ~= token then return end
			local current = ECS.world:get(entity, ECS.Components.TycoonState)
			local player = current and current.owner
			local character = player and player.Character
			if character and (zone:isPointInside(character:GetPivot().Position)) then return end
			setDoor(false)
		end)
	end

	local entered = observer:onPlayerEnter(function(player: Player)
		local current = ECS.world:get(entity, ECS.Components.TycoonState)
		if current and current.owner == player then setDoor(true) end
	end)
	local exited = observer:onPlayerExit(function(player: Player)
		local current = ECS.world:get(entity, ECS.Components.TycoonState)
		if current and current.owner == player then scheduleClose() end
	end)

	return function()
		token += 1
		if entered then entered() end
		if exited then exited() end
		observer:destroy()
		zone:destroy()
		if activeTween then activeTween:Cancel() end
	end
end

return LabDoorSystem
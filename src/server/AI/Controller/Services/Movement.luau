--!strict

local Types = require(script.Parent.Parent.Core.Types)
local Dialogue = require(script.Parent.Dialogue)
local WorldQuery = require(script.Parent.WorldQuery)

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike

local Movement = {}

local function simplifyWaypoints(context: AIContext, waypoints: { PathWaypoint }): { PathWaypoint }
	if #waypoints <= 2 then
		return waypoints
	end

	local simplified: { PathWaypoint } = {}
	table.insert(simplified, waypoints[1])

	local lastKeptPosition = waypoints[1].Position
	for i = 2, #waypoints - 1 do
		local waypoint = waypoints[i]
		local nextWaypoint = waypoints[i + 1]

		local keepWaypoint = false
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			keepWaypoint = true
		else
			local segmentDistance = (waypoint.Position - lastKeptPosition).Magnitude
			if segmentDistance >= context.Config.WaypointMinSegmentDistance then
				keepWaypoint = true
			end

			local incoming = waypoint.Position - lastKeptPosition
			local outgoing = nextWaypoint.Position - waypoint.Position
			if incoming.Magnitude > 0 and outgoing.Magnitude > 0 then
				local turnDot = incoming.Unit:Dot(outgoing.Unit)
				if turnDot < context.Config.WaypointTurnDotThreshold then
					keepWaypoint = true
				end
			end
		end

		if keepWaypoint then
			table.insert(simplified, waypoint)
			lastKeptPosition = waypoint.Position
		end
	end

	table.insert(simplified, waypoints[#waypoints])
	return simplified
end

function Movement.Stop(context: AIContext)
	context.Humanoid:Move(Vector3.zero)
	context.Humanoid:MoveTo(WorldQuery.GetCurrentPosition(context))
end

function Movement.FaceTowardPositionStep(context: AIContext, targetPosition: Vector3, alpha: number?)
	if not context.NPC.Parent then
		return
	end

	local currentPivot = context.NPC:GetPivot()
	local currentPosition: Vector3 = currentPivot.Position
	local flatTarget: Vector3 = Vector3.new(targetPosition.X, currentPosition.Y, targetPosition.Z)
	local direction: Vector3 = flatTarget - currentPosition

	if direction.Magnitude <= 0.05 then
		return
	end

	local targetCFrame = CFrame.lookAt(currentPosition, flatTarget)
	context.NPC:PivotTo(currentPivot:Lerp(targetCFrame, alpha or 0.25))
end

function Movement.LookAtPosition(context: AIContext, targetPosition: Vector3, duration: number)
	local elapsed = 0
	local stepCount = math.max(1, math.floor(duration / context.Config.LookStep))

	Movement.Stop(context)

	while elapsed < duration do
		if not context.NPC.Parent then
			return
		end

		Movement.FaceTowardPositionStep(context, targetPosition, 1 / stepCount)

		elapsed += context.Config.LookStep
		task.wait(context.Config.LookStep)
	end
end

function Movement.ComputePath(context: AIContext, targetPosition: Vector3): { PathWaypoint }?
	local origin = WorldQuery.GetCurrentPosition(context)
	local success, err = pcall(function()
		context.Path:ComputeAsync(origin, targetPosition)
	end)

	if not success then
		warn(`[NPCData] Path compute failed for {context.Name}: {err}`)
		return nil
	end

	if context.Path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	return context.Path:GetWaypoints()
end

function Movement.StepAwayFromBlocker(context: AIContext, blockerRoot: BasePart, directionBias: number): number
	local currentPosition = WorldQuery.GetCurrentPosition(context)
	local away = currentPosition - blockerRoot.Position
	local awayDirection = if away.Magnitude > 0.05 then away.Unit else context.PrimaryPart.CFrame.LookVector
	local right = awayDirection:Cross(Vector3.yAxis)
	if right.Magnitude <= 0.05 then
		right = context.PrimaryPart.CFrame.RightVector
	else
		right = right.Unit
	end

	local awayDot = right:Dot(away)
	local fallbackSign = if awayDot >= 0 then 1 else -1

	local preferredSign = if directionBias ~= 0 then directionBias else fallbackSign
	local sideSign = WorldQuery.GetBestAvoidSide(context, preferredSign)

	local sideOffset = right * sideSign * context.Config.AvoidStepDistance
	local backOffset = -context.PrimaryPart.CFrame.LookVector * (context.Config.AvoidStepDistance * 0.35)
	local targetPosition = currentPosition + sideOffset + backOffset

	context.Humanoid:MoveTo(targetPosition)
	return sideSign
end

function Movement.BackAwayFromTarget(context: AIContext, targetRoot: BasePart)
	context.Humanoid.AutoRotate = false
	Movement.FaceTowardPositionStep(context, targetRoot.Position, 1)

	local currentPosition = WorldQuery.GetCurrentPosition(context)
	local away = currentPosition - targetRoot.Position
	local awayDirection = if away.Magnitude > 0.05 then away.Unit else -context.PrimaryPart.CFrame.LookVector
	local targetPosition = currentPosition + awayDirection * context.Config.AvoidStepDistance

	context.Humanoid:MoveTo(targetPosition)
end

function Movement.FollowPathTo(context: AIContext, targetPosition: Vector3, machine: StateMachineLike): boolean
	local waypoints = Movement.ComputePath(context, targetPosition)
	if not waypoints then
		return false
	end
	waypoints = simplifyWaypoints(context, waypoints)

	local blockedConnection: RBXScriptConnection? = nil
	local pathBlocked = false

	blockedConnection = context.Path.Blocked:Connect(function()
		pathBlocked = true
	end)

	for index, waypoint in ipairs(waypoints) do
		if not context.NPC.Parent or machine:GetStateName() == "Dead" then
			if blockedConnection then
				blockedConnection:Disconnect()
			end
			return false
		end

		local currentPosition = WorldQuery.GetCurrentPosition(context)
		local distance = (waypoint.Position - currentPosition).Magnitude
		if distance <= context.Config.CloseWaypointDistance then
			continue
		end

		local frontBlocker = WorldQuery.FindFrontBlockingPlayer(context)
		if frontBlocker then
			context.AvoidTarget = frontBlocker
			if blockedConnection then
				blockedConnection:Disconnect()
			end
			Movement.Stop(context)
			machine:SetState("AvoidFrontBlock")
			return false
		end

		local observablePlayers = WorldQuery.FindObservablePlayers(context)
		if #observablePlayers > 0 and Dialogue.PrepareObservation(context, observablePlayers) then
			if blockedConnection then
				blockedConnection:Disconnect()
			end
			machine:SetState("ObservePlayer")
			return false
		end

		local moveTarget = waypoint.Position + WorldQuery.GetSeparationOffset(context)
		context.Humanoid:MoveTo(moveTarget)

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			context.Humanoid.Jump = true
		end

		local reached = false
		local deadline = os.clock() + context.Config.MoveTimeout
		local reachDistance = context.Config.CloseWaypointDistance
		if index < #waypoints then
			reachDistance = math.max(reachDistance, context.Config.Path.WaypointSpacing)
		end

		while os.clock() < deadline do
			local currentDistance = (moveTarget - WorldQuery.GetCurrentPosition(context)).Magnitude
			if currentDistance <= reachDistance then
				reached = true
				break
			end

			if pathBlocked then
				if blockedConnection then
					blockedConnection:Disconnect()
				end
				return false
			end

			if reached then
				break
			end

			local observablePlayersDuringMove = WorldQuery.FindObservablePlayers(context)
			if #observablePlayersDuringMove > 0 and Dialogue.PrepareObservation(context, observablePlayersDuringMove) then
				if blockedConnection then
					blockedConnection:Disconnect()
				end
				Movement.Stop(context)
				machine:SetState("ObservePlayer")
				return false
			end

			local blocker = WorldQuery.FindFrontBlockingPlayer(context)
			if blocker then
				context.AvoidTarget = blocker
				if blockedConnection then
					blockedConnection:Disconnect()
				end
				Movement.Stop(context)
				machine:SetState("AvoidFrontBlock")
				return false
			end

			task.wait(0.05)
		end

		if not reached then
			if blockedConnection then
				blockedConnection:Disconnect()
			end
			Movement.Stop(context)
			return false
		end
	end

	if blockedConnection then
		blockedConnection:Disconnect()
	end

	return true
end

return Movement

--!strict

local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(script.Parent.Parent.Core.Types)
local Dialogue = require(script.Parent.Dialogue)
local WorldQuery = require(script.Parent.WorldQuery)
local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)

type AIContext = Types.AIContext
type StateMachineLike = Types.StateMachineLike

local Movement = {}

local function getSeparatedTarget(context: AIContext, baseTarget: Vector3): Vector3
	local separationOffset = WorldQuery.GetSeparationOffset(context)
	if separationOffset.Magnitude <= 0.05 then
		return baseTarget
	end

	return baseTarget + separationOffset
end

local function refreshSeparatedMoveTarget(context: AIContext, state: any, baseTarget: Vector3): boolean
	local now = os.clock()
	if state.moveTarget and now < (state.nextSeparationAt or 0) then
		return false
	end

	local separationOffset = WorldQuery.GetSeparationOffset(context)
	if state.moveTarget and separationOffset.Magnitude <= 0.05 then
		state.nextSeparationAt = now + context.Config.SeparationRefreshInterval
		return false
	end

	local separatedTarget = baseTarget + separationOffset
	state.baseMoveTarget = baseTarget
	state.moveTarget = separatedTarget
	state.nextSeparationAt = now + context.Config.SeparationRefreshInterval
	context.Humanoid:MoveTo(separatedTarget)
	return true
end

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
	local currentPosition = WorldQuery.GetCurrentPosition(context)
	local separatedTarget = getSeparatedTarget(context, currentPosition)
	context.Humanoid:Move(Vector3.zero)
	context.Humanoid:MoveTo(separatedTarget)
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
        local state = (context :: any).LookAtPositionState
        if not state or (state.targetPosition - targetPosition).Magnitude > 0.1 then
                state = {
                        targetPosition = targetPosition,
                        startedAt = os.clock(),
                        duration = duration,
                        stepCount = math.max(1, math.floor(duration / context.Config.LookStep)),
                }
                ;(context :: any).LookAtPositionState = state

                Movement.Stop(context)
        end

        if not context.NPC.Parent then
                (context :: any).LookAtPositionState = nil
                return
        end

        Movement.FaceTowardPositionStep(context, targetPosition, 1 / state.stepCount)

        if os.clock() - state.startedAt >= state.duration then
                (context :: any).LookAtPositionState = nil
        end
end

function Movement.ComputePath(context: AIContext, targetPosition: Vector3): { PathWaypoint }?
	local origin = WorldQuery.GetCurrentPosition(context)
	local success, err = pcall(function()
		context.Path:ComputeAsync(origin, targetPosition)
	end)

	if not success then
		Diagnostics.reportThrottled(
			"AI.Movement",
			`path:{context.Name}`,
			`Path compute failed for {context.Name}: {tostring(err)}`,
			10
		)
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

local function getAwayDirection(context: AIContext, targetRoot: BasePart): Vector3
	local currentPosition = WorldQuery.GetCurrentPosition(context)
	local away = currentPosition - targetRoot.Position
	if away.Magnitude > 0.05 then
		return away.Unit
	end

	return -context.PrimaryPart.CFrame.LookVector
end

local function getAvoidSideDirection(context: AIContext, awayDirection: Vector3, preferredSign: number): Vector3
	local right = awayDirection:Cross(Vector3.yAxis)
	if right.Magnitude <= 0.05 then
		right = context.PrimaryPart.CFrame.RightVector
	else
		right = right.Unit
	end

	local sideSign = WorldQuery.GetBestAvoidSide(context, preferredSign)
	context.AvoidDirection = sideSign
	return right * sideSign
end

function Movement.ManeuverAwayFromBlocker(context: AIContext, blockerRoot: BasePart)
	local state = (context :: any).AvoidManeuver
	local now = os.clock()

	if state and now < state.nextMoveAt then
		return
	end

	local currentPosition = WorldQuery.GetCurrentPosition(context)
	local awayDirection = getAwayDirection(context, blockerRoot)
	local sideDirection = getAvoidSideDirection(context, awayDirection, context.AvoidDirection)
	local forwardCarry = context.PrimaryPart.CFrame.LookVector * (context.Config.AvoidManeuverDistance * 0.45)
	local targetPosition = currentPosition
		+ awayDirection * (context.Config.AvoidManeuverDistance * 0.45)
		+ sideDirection * context.Config.AvoidManeuverDistance
		+ forwardCarry

	;(context :: any).AvoidManeuver = {
		nextMoveAt = now + context.Config.AvoidRepathInterval,
	}

	context.Humanoid.AutoRotate = true
	context.Humanoid:MoveTo(targetPosition)
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

local function clearFleePath(context: AIContext)
	local state = (context :: any).FleePath
	if state and state.blockedConnection then
		state.blockedConnection:Disconnect()
	end

	;(context :: any).FleePath = nil
end

local function computeFleeDestination(context: AIContext, targetRoot: BasePart): Vector3
	local currentPosition = WorldQuery.GetCurrentPosition(context)
	local awayDirection = getAwayDirection(context, targetRoot)
	local sideDirection = getAvoidSideDirection(context, awayDirection, context.AvoidDirection)
	local sideAmount = math.sin(os.clock() * 1.7 + context.Name:len()) * (context.Config.FleeDistance * 0.35)

	return currentPosition
		+ awayDirection * context.Config.FleeDistance
		+ sideDirection * sideAmount
		+ WorldQuery.GetSeparationOffset(context)
end

function Movement.FleeFromTarget(context: AIContext, targetRoot: BasePart): boolean
	local now = os.clock()
	local state = (context :: any).FleePath

	if not state or now >= state.repathAt or state.pathBlocked then
		clearFleePath(context)

		local destination = computeFleeDestination(context, targetRoot)
		local waypoints = Movement.ComputePath(context, destination)
		if not waypoints then
			local currentPosition = WorldQuery.GetCurrentPosition(context)
			local awayDirection = getAwayDirection(context, targetRoot)
			context.Humanoid:MoveTo(currentPosition + awayDirection * (context.Config.FleeDistance * 0.45))
			;(context :: any).FleePath = {
				waypoints = {},
				index = 1,
				baseMoveTarget = nil,
				moveTarget = nil,
				nextSeparationAt = 0,
				repathAt = now + context.Config.AvoidRepathInterval,
				pathBlocked = false,
				blockedConnection = nil,
			}
			return true
		end

		state = {
			waypoints = simplifyWaypoints(context, waypoints),
			index = 1,
			baseMoveTarget = nil,
			moveTarget = nil,
			nextSeparationAt = 0,
			repathAt = now + math.max(1, context.Config.AvoidRepathInterval * 2.2),
			pathBlocked = false,
			blockedConnection = nil,
		}

		state.blockedConnection = context.Path.Blocked:Connect(function()
			state.pathBlocked = true
		end)

		;(context :: any).FleePath = state
	end

	while state.index <= #state.waypoints do
		local waypoint = state.waypoints[state.index]
		local distance = (waypoint.Position - WorldQuery.GetCurrentPosition(context)).Magnitude
		if distance > context.Config.CloseWaypointDistance then
			break
		end

		state.index += 1
		state.moveTarget = nil
	end

	if state.index > #state.waypoints then
		state.repathAt = 0
		return true
	end

	local waypoint = state.waypoints[state.index]
	if not state.moveTarget then
		refreshSeparatedMoveTarget(context, state, waypoint.Position)

		if waypoint.Action == Enum.PathWaypointAction.Jump then
			context.Humanoid.Jump = true
		end
	elseif state.baseMoveTarget then
		refreshSeparatedMoveTarget(context, state, state.baseMoveTarget)
	end

	local currentDistance = (state.moveTarget - WorldQuery.GetCurrentPosition(context)).Magnitude
	if currentDistance <= context.Config.CloseWaypointDistance then
		state.index += 1
		state.moveTarget = nil
	end

	return true
end

function Movement.ClearAvoidance(context: AIContext)
	clearFleePath(context)
	;(context :: any).AvoidManeuver = nil
end

function Movement.FollowPathTo(context: AIContext, targetPosition: Vector3, machine: StateMachineLike): boolean?
        local state = (context :: any).PathFollow
        if not state or (state.targetPosition - targetPosition).Magnitude > 1 then
                if state and state.blockedConnection then
                        state.blockedConnection:Disconnect()
                end

                local waypoints = Movement.ComputePath(context, targetPosition)
                if not waypoints then
                        return false
                end

                state = {
                        targetPosition = targetPosition,
                        waypoints = simplifyWaypoints(context, waypoints),
                        index = 1,
                        baseMoveTarget = nil,
                        moveTarget = nil,
                        nextSeparationAt = 0,
                        deadline = 0,
                        pathBlocked = false,
                        blockedConnection = nil,
                }

                state.blockedConnection = context.Path.Blocked:Connect(function()
                        state.pathBlocked = true
                end)

                ;(context :: any).PathFollow = state
        end

        local function finish(result: boolean): boolean
                if state.blockedConnection then
                        state.blockedConnection:Disconnect()
                end
                ;(context :: any).PathFollow = nil
                return result
        end

        if not context.NPC.Parent or machine:GetStateName() == "Dead" then
                return finish(false)
        end

        if state.pathBlocked then
                Movement.Stop(context)
                return finish(false)
        end

        local observablePlayers = WorldQuery.FindObservablePlayers(context)
        if #observablePlayers > 0 and Dialogue.PrepareObservation(context, observablePlayers) then
                Movement.Stop(context)
                finish(false)
                machine:SetState("ObservePlayer")
                return false
        end

        local blocker = WorldQuery.FindFrontBlockingPlayer(context)
        if blocker then
                context.AvoidTarget = blocker
                Movement.Stop(context)
                finish(false)
                machine:SetState("AvoidFrontBlock")
                return false
        end

        while state.index <= #state.waypoints do
                local waypoint = state.waypoints[state.index]
                local currentPosition = WorldQuery.GetCurrentPosition(context)
                local distance = (waypoint.Position - currentPosition).Magnitude
                if distance > context.Config.CloseWaypointDistance then
                        break
                end

                state.index += 1
                state.moveTarget = nil
        end

        if state.index > #state.waypoints then
                return finish(true)
        end

        local waypoint = state.waypoints[state.index]
        if not state.moveTarget then
                refreshSeparatedMoveTarget(context, state, waypoint.Position)
                state.deadline = os.clock() + context.Config.MoveTimeout

                if waypoint.Action == Enum.PathWaypointAction.Jump then
                        context.Humanoid.Jump = true
                end
        elseif state.baseMoveTarget then
                refreshSeparatedMoveTarget(context, state, state.baseMoveTarget)
        end

        local reachDistance = context.Config.CloseWaypointDistance
        if state.index < #state.waypoints then
                reachDistance = math.max(reachDistance, context.Config.Path.WaypointSpacing)
        end

        if not state.moveTarget then
                refreshSeparatedMoveTarget(context, state, waypoint.Position)
        end

        if not state.moveTarget then
                Movement.Stop(context)
                return finish(false)
        end

        local currentDistance = (state.moveTarget - WorldQuery.GetCurrentPosition(context)).Magnitude
        if currentDistance <= reachDistance then
                state.index += 1
                state.moveTarget = nil
                return nil
        end

        if os.clock() >= state.deadline then
                Movement.Stop(context)
                return finish(false)
        end

        return nil
end

return Movement

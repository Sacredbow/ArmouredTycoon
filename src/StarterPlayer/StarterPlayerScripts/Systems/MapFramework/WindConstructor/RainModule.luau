

local MIN_SIZE = Vector3.new(0.05,0.05,0.05)				

local RAIN_DEFAULT_COLOR = Color3.new(1,1,1)				
local RAIN_DEFAULT_TRANSPARENCY = 0							
local RAIN_DEFAULT_SPEEDRATIO = 1							
local RAIN_DEFAULT_INTENSITYRATIO = 1						
local RAIN_DEFAULT_LIGHTEMISSION = 0.05						
local RAIN_DEFAULT_LIGHTINFLUENCE = 0.9						
local RAIN_DEFAULT_DIRECTION = Vector3.new(0,-1,0)			

local RAIN_TRANSPARENCY_T1 = .25							
local RAIN_TRANSPARENCY_T2 = .75

local RAIN_SCANHEIGHT = 3000
							

local RAIN_EMITTER_DIM_DEFAULT = 40							
local RAIN_EMITTER_DIM_MAXFORWARD = 100						
local RAIN_EMITTER_UP_MODIFIER = 20							

local RAIN_SOUND_ASSET = "rbxassetid://1516791621"
local RAIN_SOUND_BASEVOLUME = 0.2							
local RAIN_SOUND_FADEIN_TIME = 1							
local RAIN_SOUND_FADEOUT_TIME = 1

local RAIN_STRAIGHT_ASSET = "rbxassetid://1822883048"		
local RAIN_STRAIGHT_ALPHA_LOW = 0.7						
local RAIN_STRAIGHT_SIZE = NumberSequence.new(10)
local RAIN_STRAIGHT_LIFETIME = NumberRange.new(0.8)
local RAIN_STRAIGHT_MAX_RATE = 600							
local RAIN_STRAIGHT_MAX_SPEED = 60							

local RAIN_TOPDOWN_ASSET = "rbxassetid://1822856633"		
local RAIN_TOPDOWN_ALPHA_LOW = 0.85							
local RAIN_TOPDOWN_SIZE = NumberSequence.new {
	NumberSequenceKeypoint.new(0, 5.33, 2.75);
	NumberSequenceKeypoint.new(1, 5.33, 2.75);
}			
local RAIN_TOPDOWN_LIFETIME = NumberRange.new(0.8)
local RAIN_TOPDOWN_ROTATION = NumberRange.new(0,360)
local RAIN_TOPDOWN_MAX_RATE = 600							
local RAIN_TOPDOWN_MAX_SPEED = 60							

local RAIN_SPLASH_ASSET = "rbxassetid://1822856633"			
local RAIN_SPLASH_ALPHA_LOW = 0.6							
local RAIN_SPLASH_SIZE = NumberSequence.new {				
	NumberSequenceKeypoint.new(0, 0);
	NumberSequenceKeypoint.new(.4, 3);
	NumberSequenceKeypoint.new(1, 0);
}
local RAIN_SPLASH_LIFETIME = NumberRange.new(0.1, 0.15)
local RAIN_SPLASH_ROTATION = NumberRange.new(0,360)
local RAIN_SPLASH_NUM = 20									-- Amount of splashes per frame
local RAIN_SPLASH_CORRECTION_Y = .5							-- Offset from impact position for visual reasons
local RAIN_SPLASH_STRAIGHT_OFFSET_Y = 50					-- Offset against rain direction for straight rain particles from splash position
local RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MIN = 20				-- Min/max vertical offset from camera height for straight rain particles
local RAIN_NOSPLASH_STRAIGHT_OFFSET_Y_MAX = 100				-- when no splash position could be found (i.e. no floor at that XZ-column)

local RAIN_OCCLUDED_MINSPEED = 70							-- Minimum speed for the occluded straight rain emitters
local RAIN_OCCLUDED_MAXSPEED = 100							-- Maximum speed for the occluded straight rain emitters
local RAIN_OCCLUDED_SPREAD = Vector2.new(10,10)				-- Spread angle for the occluded straight rain emitters
local RAIN_OCCLUDED_MAXINTENSITY = 2						-- How many occluded straight rain particles are emitted for every splash for max intensity

local RAIN_UPDATE_PERIOD = 6								-- Update the transparency of the main emitters + volume of rain inside every X frames

local RAIN_VOLUME_SCAN_RADIUS = 35
local RAIN_GRID_RADIUS = 30
local RAIN_GRID_OFFSETS = {
	Vector3.new(-RAIN_GRID_RADIUS, 0, -RAIN_GRID_RADIUS),
	Vector3.new(0, 0, -RAIN_GRID_RADIUS),
	Vector3.new(RAIN_GRID_RADIUS, 0, -RAIN_GRID_RADIUS),
	Vector3.new(-RAIN_GRID_RADIUS, 0, 0),
	Vector3.zero,
	Vector3.new(RAIN_GRID_RADIUS, 0, 0),
	Vector3.new(-RAIN_GRID_RADIUS, 0, RAIN_GRID_RADIUS),
	Vector3.new(0, 0, RAIN_GRID_RADIUS),
	Vector3.new(RAIN_GRID_RADIUS, 0, RAIN_GRID_RADIUS),
}

-- Defining grid for checking how far the camera is away from a spot exposed to rain
local RAIN_VOLUME_SCAN_GRID = {								-- Unit range grid for scanning how far away user is from rain space
	-- range 0.2, 4 pts
	Vector3.new(0.141421363, 0, 0.141421363);
	Vector3.new(-0.141421363, 0, 0.141421363);
	Vector3.new(-0.141421363, 0, -0.141421363);
	Vector3.new(0.141421363, 0, -0.141421363);
	-- range 0.4, 8 pts
	Vector3.new(0.400000006, 0, 0);
	Vector3.new(0.282842726, 0, 0.282842726);
	Vector3.new(2.44929371e-17, 0, 0.400000006);
	Vector3.new(-0.282842726, 0, 0.282842726);
	Vector3.new(-0.400000006, 0, 4.89858741e-17);
	Vector3.new(-0.282842726, 0, -0.282842726);
	Vector3.new(-7.34788045e-17, 0, -0.400000006);
	Vector3.new(0.282842726, 0, -0.282842726);
	-- range 0.6, 10 pts
	Vector3.new(0.600000024, 0, 0);
	Vector3.new(0.485410213, 0, 0.352671146);
	Vector3.new(0.185410202, 0, 0.570633948);
	Vector3.new(-0.185410202, 0, 0.570633948);
	Vector3.new(-0.485410213, 0, 0.352671146);
	Vector3.new(-0.600000024, 0, 7.34788112e-17);
	Vector3.new(-0.485410213, 0, -0.352671146);
	Vector3.new(-0.185410202, 0, -0.570633948);
	Vector3.new(0.185410202, 0, -0.570633948);
	Vector3.new(0.485410213, 0, -0.352671146);
	-- range 0.8, 12 pts
	Vector3.new(0.772740662, 0, 0.207055241);
	Vector3.new(0.565685451, 0, 0.565685451);
	Vector3.new(0.207055241, 0, 0.772740662);
	Vector3.new(-0.207055241, 0, 0.772740662);
	Vector3.new(-0.565685451, 0, 0.565685451);
	Vector3.new(-0.772740662, 0, 0.207055241);
	Vector3.new(-0.772740662, 0, -0.207055241);
	Vector3.new(-0.565685451, 0, -0.565685451);
	Vector3.new(-0.207055241, 0, -0.772740662);
	Vector3.new(0.207055241, 0, -0.772740662);
	Vector3.new(0.565685451, 0, -0.565685451);
	Vector3.new(0.772740662, 0, -0.207055241);
}




-- Variables & setup:

-- services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local GlobalModifier = Instance.new("NumberValue")			-- modifier for rain visibility for disabling/enabling over time span
GlobalModifier.Value = 1									-- 0 = fully visible, 1 = invisible

local connections = {}										-- Stores connections to RunService signals when enabled

local disabled = true										-- Value to figure out whether we are moving towards a disabled state (useful during tweens)

local rainDirection = RAIN_DEFAULT_DIRECTION				-- Direction that rain falls into

local currentCeiling = nil									-- Y coordinate of ceiling (if present)


local straightLowAlpha = 1									-- Current transparency for straight rain particles
local topdownLowAlpha = 1									-- Current transparency for top-down rain particles
local intensityOccludedRain = 0								-- Current intensity of occluded rain particles
local numSplashes = 0										
local volumeTarget = 0									

-- shorthands
local v3 = Vector3.new
local NSK010 = NumberSequenceKeypoint.new(0, 1, 0)
local NSK110 = NumberSequenceKeypoint.new(1, 1, 0)

local volumeScanGrid = {}									-- Pre-generate grid used for raining area distance scanning
for _,v in pairs(RAIN_VOLUME_SCAN_GRID) do
	table.insert(volumeScanGrid, v * RAIN_VOLUME_SCAN_RADIUS)
end
table.sort(volumeScanGrid, function(a,b)					-- Optimization: sort from close to far away for fast evaluation if closeby
	return a.magnitude < b.magnitude
end)

-- sound group for easy main volume tweaking
local SoundGroup = Instance.new("SoundGroup")
SoundGroup.Name = "__RainSoundGroup"
SoundGroup.Volume = RAIN_SOUND_BASEVOLUME
SoundGroup.Archivable = false

local Sound = Instance.new("Sound")
Sound.Name = "RainSound"
Sound.Volume = volumeTarget
Sound.SoundId = RAIN_SOUND_ASSET
Sound.Looped = true
Sound.SoundGroup = SoundGroup
Sound.Parent = SoundGroup
Sound.Archivable = false

-- emitter block around camera used when outside
local Emitter do
	
	Emitter = Instance.new("Part")
	Emitter.Transparency = 1
	Emitter.Anchored = true
	Emitter.CanCollide = false
	Emitter.Locked = false
	Emitter.Archivable = false
	Emitter.TopSurface = Enum.SurfaceType.Smooth
	Emitter.BottomSurface = Enum.SurfaceType.Smooth
	Emitter.Name = "__RainEmitter"
	Emitter.Size = MIN_SIZE
	Emitter.Archivable = false
	
	local straight = Instance.new("ParticleEmitter")
	straight.Name = "RainStraight"
	straight.LightEmission = RAIN_DEFAULT_LIGHTEMISSION
	straight.LightInfluence = RAIN_DEFAULT_LIGHTINFLUENCE
	straight.Size = RAIN_STRAIGHT_SIZE
	straight.Texture = RAIN_STRAIGHT_ASSET
	straight.LockedToPart = true
	straight.Enabled = false
	straight.Lifetime = RAIN_STRAIGHT_LIFETIME
	straight.Rate = RAIN_STRAIGHT_MAX_RATE
	straight.Speed = NumberRange.new(RAIN_STRAIGHT_MAX_SPEED)
	straight.EmissionDirection = Enum.NormalId.Bottom
	straight.Parent = Emitter
	straight.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	
	local topdown = Instance.new("ParticleEmitter")
	topdown.Name = "RainTopDown"
	topdown.LightEmission = RAIN_DEFAULT_LIGHTEMISSION
	topdown.LightInfluence = RAIN_DEFAULT_LIGHTINFLUENCE
	topdown.Size = RAIN_TOPDOWN_SIZE
	topdown.Texture = RAIN_TOPDOWN_ASSET
	topdown.LockedToPart = true
	topdown.Enabled = false
	topdown.Rotation = RAIN_TOPDOWN_ROTATION
	topdown.Lifetime = RAIN_TOPDOWN_LIFETIME
	topdown.Rate = RAIN_TOPDOWN_MAX_RATE
	topdown.Speed = NumberRange.new(RAIN_TOPDOWN_MAX_SPEED)
	topdown.EmissionDirection = Enum.NormalId.Bottom
	topdown.Parent = Emitter
	
end

local splashAttachments, rainAttachments do
	
	splashAttachments = {}
	rainAttachments = {}
	
	for i = 1, RAIN_SPLASH_NUM do
		
		-- splashes on ground
		local splashAttachment = Instance.new("Attachment")
		splashAttachment.Name = "__RainSplashAttachment"
		local splash = Instance.new("ParticleEmitter")
		splash.LightEmission = RAIN_DEFAULT_LIGHTEMISSION
		splash.LightInfluence = RAIN_DEFAULT_LIGHTINFLUENCE
		splash.Size = RAIN_SPLASH_SIZE
		splash.Texture = RAIN_SPLASH_ASSET
		splash.Rotation = RAIN_SPLASH_ROTATION
		splash.Lifetime = RAIN_SPLASH_LIFETIME
		splash.Transparency = NumberSequence.new {
			NSK010;
			NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T1, RAIN_SPLASH_ALPHA_LOW, 0);
			NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T2, RAIN_SPLASH_ALPHA_LOW, 0);
			NSK110;
		}
		splash.Enabled = false
		splash.Rate = 0
		splash.Speed = NumberRange.new(0)
		splash.Name = "RainSplash"
		splash.Parent = splashAttachment
		splashAttachment.Archivable = false
		table.insert(splashAttachments, splashAttachment)
		
		-- occluded rain particle generation
		local rainAttachment = Instance.new("Attachment")
		rainAttachment.Name = "__RainOccludedAttachment"
		local straightOccluded = Emitter.RainStraight:Clone()
		straightOccluded.Speed = NumberRange.new(RAIN_OCCLUDED_MINSPEED, RAIN_OCCLUDED_MAXSPEED)
		straightOccluded.SpreadAngle = RAIN_OCCLUDED_SPREAD
		straightOccluded.LockedToPart = false
		straightOccluded.Enabled = false
		straightOccluded.Parent = rainAttachment
		local topdownOccluded = Emitter.RainTopDown:Clone()
		topdownOccluded.Speed = NumberRange.new(RAIN_OCCLUDED_MINSPEED, RAIN_OCCLUDED_MAXSPEED)
		topdownOccluded.SpreadAngle = RAIN_OCCLUDED_SPREAD
		topdownOccluded.LockedToPart = false
		topdownOccluded.Enabled = false
		topdownOccluded.Parent = rainAttachment
		rainAttachment.Archivable = false
		table.insert(rainAttachments, rainAttachment)
		
	end
	
end


-- Helper methods:

local ignoreEmitterList = { Emitter }

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude

local function raycast(ray, ignoreCharacter)
	local filter = ignoreEmitterList
	if ignoreCharacter then
		filter = { Emitter }
		local character = Players.LocalPlayer and Players.LocalPlayer.Character
		if character then
			table.insert(filter, character)
		end
	end

	raycastParams.FilterDescendantsInstances = filter
	return castRay(ray.Origin, ray.Direction, raycastParams)
end

local function connectLoop()
	
	local inside = false					-- Whether camera is currently in a spot occluded from the sky
	local frame = RAIN_UPDATE_PERIOD
	local occlusionAccumulator = 0
	
	-- Update Emitter on RenderStepped since it needs to be synced to Camera
	table.insert(connections, RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		
		-- Check if camera is outside or inside
		local part, position, normal = raycast(Ray.new(camera.CFrame.p, -rainDirection * RAIN_SCANHEIGHT), true)
		if part and position and normal and normal.Y > 0.35 and rainDirection.Y < 0 then
			currentCeiling = position.Y
		else
			currentCeiling = nil
		end
		
		if not currentCeiling or camera.CFrame.p.y > currentCeiling then

			-- Camera is outside and under ceiling
			inside = false

			if volumeTarget < 1 and not disabled then
				volumeTarget = 1
				TweenService:Create(Sound, TweenInfo.new(.5), {Volume = 1}):Play()
			end

			frame = RAIN_UPDATE_PERIOD

			local t = math.abs(camera.CFrame.lookVector:Dot(rainDirection))

			local center = camera.CFrame.p
			local right = camera.CFrame.lookVector:Cross(-rainDirection)
			right = right.magnitude > 0.001 and right.unit or -rainDirection
			local forward = rainDirection:Cross(right).unit

			Emitter.Size = v3(
				RAIN_EMITTER_DIM_DEFAULT,
				RAIN_EMITTER_DIM_DEFAULT,
				RAIN_EMITTER_DIM_DEFAULT + (1 - t)*(RAIN_EMITTER_DIM_MAXFORWARD - RAIN_EMITTER_DIM_DEFAULT)
			)

			local emitterOffset = (1 - t) * camera.CFrame.lookVector * Emitter.Size.Z/3
			- t * rainDirection * RAIN_EMITTER_UP_MODIFIER

			local emitterPos = center + emitterOffset

			
			if currentCeiling and emitterPos.Y > currentCeiling and rainDirection.Y < 0 then
				emitterPos = emitterPos + rainDirection * (currentCeiling - emitterPos.Y) / rainDirection.Y
			end

			Emitter.CFrame = CFrame.new(
				emitterPos.x, emitterPos.y, emitterPos.z,
				right.x, -rainDirection.x, forward.x,
				right.y, -rainDirection.y, forward.y,
				right.z, -rainDirection.z, forward.z
			)
			
		else
			
			-- Camera is inside / above ceiling
			Emitter.RainStraight.Enabled = false
			Emitter.RainTopDown.Enabled = false
			Emitter.Size = MIN_SIZE
			inside = true
		end
		
	end))

	-- Do the other effects on Stepped
	local signal = RunService:IsRunning() and RunService.Stepped or RunService.RenderStepped
	table.insert(connections, signal:Connect(function(timeOrDelta, steppedDeltaTime)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		
		frame = frame + 1
		
		-- Only do some updates once every few frames
		if frame >= RAIN_UPDATE_PERIOD then
			
			-- Measure of how much camera is facing down (0-1)
			local t = math.abs(camera.CFrame.lookVector:Dot(rainDirection))
			
			-- More looking down = see straight particles less and see top-down particles more
			local straightSequence = NumberSequence.new {
				NSK010;
				NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T1, (1 - t)*straightLowAlpha + t, 0);
				NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T2, (1 - t)*straightLowAlpha + t, 0);
				NSK110;
			}
			local topdownSequence = NumberSequence.new {
				NSK010;
				NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T1, t*topdownLowAlpha + (1 - t), 0);
				NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T2, t*topdownLowAlpha + (1 - t), 0);
				NSK110;
			}
			
			-- Find desired rotation for the straight rain particles
			local mapped = camera.CFrame:inverse() * (camera.CFrame.p - rainDirection)
			local straightRotation = NumberRange.new(math.deg(math.atan2(-mapped.x, mapped.y)))
			
			if inside then
				
				-- Update emitter properties
				for _,v in pairs(rainAttachments) do
					v.RainStraight.Transparency = straightSequence
					v.RainStraight.Rotation = straightRotation
					v.RainTopDown.Transparency = topdownSequence
				end
				
				if not disabled then
					
					-- Only do occluded volume check if not moving towards disabled state
					
					local volume = 0
					
					if (not currentCeiling or camera.CFrame.p.y <= currentCeiling) then
						
						-- Check how far away camera is from a space open to the sky using volume scan grid
						
						local minDistance = RAIN_VOLUME_SCAN_RADIUS
						local rayDirection = -rainDirection * RAIN_SCANHEIGHT
						
						for i = 1, #volumeScanGrid do -- In order, so first hit is closest
							if not raycast(Ray.new(camera.CFrame * volumeScanGrid[i], rayDirection), true) then
								minDistance = volumeScanGrid[i].magnitude
								break
							end
						end
						
						-- Volume is inversely proportionate to minimum distance
						volume = 1 - minDistance / RAIN_VOLUME_SCAN_RADIUS
						
					end
					
					if math.abs(volume - volumeTarget) > .01 then
						-- Value is sufficiently different from previous target, overwrite it
						volumeTarget = volume
						TweenService:Create(Sound, TweenInfo.new(1), {Volume = volumeTarget}):Play()
					end
					
				end
				
			else
				
				-- Update emitter properties
				Emitter.RainStraight.Transparency = straightSequence
				Emitter.RainStraight.Rotation = straightRotation
				Emitter.RainTopDown.Transparency = topdownSequence
				
			end
			
			-- Reset frame counter
			frame = 0
			
		end
		
		local deltaTime = if typeof(steppedDeltaTime) == "number" then steppedDeltaTime else if typeof(timeOrDelta) == "number" then timeOrDelta else 1 / 60
		occlusionAccumulator += math.min(deltaTime, 0.1)
		if occlusionAccumulator < 1 / 15 then
			return
		end
		occlusionAccumulator = 0

		local center = camera.CFrame.Position
		local right = camera.CFrame.LookVector:Cross(-rainDirection)
		right = right.Magnitude > 0.001 and right.Unit or -rainDirection
		local forward = rainDirection:Cross(right).Unit
		local transform = CFrame.fromMatrix(center, right, -rainDirection, forward)
		local maxCells = math.min(math.floor(numSplashes), #RAIN_GRID_OFFSETS)

		-- Each cell is checked along the actual rain path. Covered cells do
		-- not emit, so indoor particles cannot be spawned above a roof.
		for i = 1, maxCells do
			local splashAttachment = splashAttachments[i]
			local rainAttachment = rainAttachments[i]
			local cellPosition = (transform * CFrame.new(RAIN_GRID_OFFSETS[i])).Position
			local skyDirection = -rainDirection * RAIN_SCANHEIGHT
			local roofHit = raycast(Ray.new(cellPosition, skyDirection), true)
			local floorPart, position, normal = raycast(
				Ray.new(cellPosition - rainDirection * RAIN_SCANHEIGHT, rainDirection * RAIN_SCANHEIGHT),
				true
			)

			if floorPart and position and normal and (not inside or not roofHit) then
				splashAttachment.Position = position + normal * RAIN_SPLASH_CORRECTION_Y
				splashAttachment.RainSplash:Emit(1)

				if inside and not roofHit then
					local corrected = position - rainDirection * math.min(RAIN_SPLASH_STRAIGHT_OFFSET_Y, 12)
					rainAttachment.CFrame = CFrame.fromMatrix(corrected, right, -rainDirection, forward)
					rainAttachment.RainStraight:Emit(intensityOccludedRain)
					rainAttachment.RainTopDown:Emit(intensityOccludedRain)
				end
			end
		end
	end))

end

local function disconnectLoop()
	-- If present, disconnect all RunService connections
	if #connections > 0 then
		for _,v in pairs(connections) do
			v:Disconnect()
		end
		connections = {}
	end
end

local function disableSound(tweenInfo)
	
	-- Tween the rain sound to be mute over a given easing function
	volumeTarget = 0
	local tween = TweenService:Create(Sound, tweenInfo, {Volume = 0})
	tween.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			Sound:Stop()
		end
		tween:Destroy()
	end)
	tween:Play()
	
end

local function disable()
	
	disconnectLoop()
	
	-- Hide Emitter
	Emitter.RainStraight.Enabled = false
	Emitter.RainTopDown.Enabled = false
	Emitter.Size = MIN_SIZE
	
	-- Disable sound now if not tweened into disabled state beforehand
	if not disabled then
		disableSound(TweenInfo.new(RAIN_SOUND_FADEOUT_TIME))
	end
	
end

-- Shorthand for creating a tweenable "variable" using value object
local function makeProperty(valueObjectClass, defaultValue, setter)
	local valueObject = Instance.new(valueObjectClass)
	if defaultValue then
		valueObject.Value = defaultValue
	end
	valueObject.Changed:Connect(setter)
	setter(valueObject.Value)
	return valueObject
end

local Color = makeProperty("Color3Value", RAIN_DEFAULT_COLOR, function(value)
	
	local value = ColorSequence.new(value)
	
	Emitter.RainStraight.Color = value
	Emitter.RainTopDown.Color = value
	
	for _,v in pairs(splashAttachments) do
		v.RainSplash.Color = value
	end
	for _,v in pairs(rainAttachments) do
		v.RainStraight.Color = value
		v.RainTopDown.Color = value
	end
	
end)

local function updateTransparency(value)
	
	local opacity = (1 - value) * (1 - GlobalModifier.Value)
	local transparency = 1 - opacity
	
	straightLowAlpha = RAIN_STRAIGHT_ALPHA_LOW * opacity + transparency
	topdownLowAlpha = RAIN_TOPDOWN_ALPHA_LOW * opacity + transparency
	
	local splashSequence = NumberSequence.new {
		NSK010;
		NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T1, opacity*RAIN_SPLASH_ALPHA_LOW + transparency, 0);
		NumberSequenceKeypoint.new(RAIN_TRANSPARENCY_T2, opacity*RAIN_SPLASH_ALPHA_LOW + transparency, 0);
		NSK110;
	}
	
	for _,v in pairs(splashAttachments) do
		v.RainSplash.Transparency = splashSequence
	end
	
end
local Transparency = makeProperty("NumberValue", RAIN_DEFAULT_TRANSPARENCY, updateTransparency)
GlobalModifier.Changed:Connect(updateTransparency)

local SpeedRatio = makeProperty("NumberValue", RAIN_DEFAULT_SPEEDRATIO, function(value)
	
	Emitter.RainStraight.Speed = NumberRange.new(value * RAIN_STRAIGHT_MAX_SPEED)
	Emitter.RainTopDown.Speed = NumberRange.new(value * RAIN_TOPDOWN_MAX_SPEED)
	
end)

local IntensityRatio = makeProperty("NumberValue", RAIN_DEFAULT_INTENSITYRATIO, function(value)
	
	Emitter.RainStraight.Rate = RAIN_STRAIGHT_MAX_RATE * value
	Emitter.RainTopDown.Rate = RAIN_TOPDOWN_MAX_RATE * value
	
	intensityOccludedRain = math.ceil(RAIN_OCCLUDED_MAXINTENSITY * value)
	numSplashes = RAIN_SPLASH_NUM * value
	
end)

local LightEmission = makeProperty("NumberValue", RAIN_DEFAULT_LIGHTEMISSION, function(value)
	
	Emitter.RainStraight.LightEmission = value
	Emitter.RainTopDown.LightEmission = value
	
	for _,v in pairs(rainAttachments) do
		v.RainStraight.LightEmission = value
		v.RainTopDown.LightEmission = value
	end
	for _,v in pairs(splashAttachments) do
		v.RainSplash.LightEmission = value
	end
	
end)

local LightInfluence = makeProperty("NumberValue", RAIN_DEFAULT_LIGHTINFLUENCE, function(value)
	
	Emitter.RainStraight.LightInfluence = value
	Emitter.RainTopDown.LightInfluence = value
	
	for _,v in pairs(rainAttachments) do
		v.RainStraight.LightInfluence = value
		v.RainTopDown.LightInfluence = value
	end
	for _,v in pairs(splashAttachments) do
		v.RainSplash.LightInfluence = value
	end
	
end)

local RainDirection = makeProperty("Vector3Value", RAIN_DEFAULT_DIRECTION, function(value)
	if value.magnitude > 0.001 then
		rainDirection = value.unit
	end
end)


-- Exposed API:

local Rain = {}

function Rain:Enable(tweenInfo)
	
	if tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
		error("bad argument #1 to 'Enable' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
	end
	
	disconnectLoop() -- Just in case :Enable(..) is called multiple times on accident
	
	Emitter.RainStraight.Enabled = true
	Emitter.RainTopDown.Enabled = true
	Emitter.Parent = workspace.CurrentCamera
	
	for i = 1, RAIN_SPLASH_NUM do
		splashAttachments[i].Parent = workspace.Terrain
		rainAttachments[i].Parent = workspace.Terrain
	end
	
	if RunService:IsRunning() then -- don't need sound in studio preview, it won't work anyway
		SoundGroup.Parent = game:GetService("SoundService")
	end
	
	connectLoop()
	
	if tweenInfo then
		TweenService:Create(GlobalModifier, tweenInfo, {Value = 0}):Play()
	else
		GlobalModifier.Value = 0
	end
	
	if not Sound.Playing then
		Sound:Play()
		Sound.TimePosition = math.random()*Sound.TimeLength
	end
	
	disabled = false
	
end

function Rain:Disable(tweenInfo)
	
	if tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
		error("bad argument #1 to 'Disable' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
	end
	
	if tweenInfo then
		local tween = TweenService:Create(GlobalModifier, tweenInfo, {Value = 1})
		tween.Completed:Connect(function(state)
			if state == Enum.PlaybackState.Completed then
				-- Only disable the rain completely once the visual effects are faded out
				disable()
			end
			tween:Destroy()
		end)
		tween:Play()
		-- Start tweening out sound now as well
		disableSound(tweenInfo)
	else
		GlobalModifier.Value = 1
		disable()
	end
	
	disabled = true
	
end

function Rain:SetColor(value, tweenInfo)
		
	if typeof(value) ~= "Color3" then
		error("bad argument #1 to 'SetColor' (Color3 expected, got " .. typeof(value) .. ")", 2)
	elseif tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
		error("bad argument #2 to 'SetColor' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
	end
	
	if tweenInfo then
		TweenService:Create(Color, tweenInfo, {Value = value}):Play()
	else
		Color.Value = value
	end
	
end

local function makeRatioSetter(methodName, valueObject)
	-- Shorthand because most of the remaining property setters are very similar
	return function(_, value, tweenInfo)
		
		if typeof(value) ~= "number" then
			error("bad argument #1 to '" .. methodName .. "' (number expected, got " .. typeof(value) .. ")", 2)
		elseif tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
			error("bad argument #2 to '" .. methodName .. "' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
		end
		
		value = math.clamp(value, 0, 1)
		
		if tweenInfo then
			TweenService:Create(valueObject, tweenInfo, {Value = value}):Play()
		else
			valueObject.Value = value
		end
		
	end
end

Rain.SetTransparency = makeRatioSetter("SetTransparency", Transparency)
Rain.SetSpeedRatio = makeRatioSetter("SetSpeedRatio", SpeedRatio)
Rain.SetIntensityRatio = makeRatioSetter("SetIntensityRatio", IntensityRatio)
Rain.SetLightEmission = makeRatioSetter("SetLightEmission", LightEmission)
Rain.SetLightInfluence = makeRatioSetter("SetLightInfluence", LightInfluence)

function Rain:SetVolume(volume, tweenInfo)
	
	if typeof(volume) ~= "number" then
		error("bad argument #1 to 'SetVolume' (number expected, got " .. typeof(volume) .. ")", 2)
	elseif tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
		error("bad argument #2 to 'SetVolume' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
	end
	
	if tweenInfo then
		TweenService:Create(SoundGroup, tweenInfo, {Volume = volume}):Play()
	else
		SoundGroup.Volume = volume
	end
	
end

function Rain:SetDirection(direction, tweenInfo)
	
	if typeof(direction) ~= "Vector3" then
		error("bad argument #1 to 'SetDirection' (Vector3 expected, got " .. typeof(direction) .. ")", 2)
	elseif tweenInfo ~= nil and typeof(tweenInfo) ~= "TweenInfo" then
		error("bad argument #2 to 'SetDirection' (TweenInfo expected, got " .. typeof(tweenInfo) .. ")", 2)
	end
	
	if not (direction.unit.magnitude > 0) then -- intentional statement formatting since NaN comparison
		warn("Attempt to set rain direction to a zero-length vector, falling back on default direction = (" .. tostring(RAIN_DEFAULT_DIRECTION) .. ")")
		direction = RAIN_DEFAULT_DIRECTION
	end
	
	if tweenInfo then
		TweenService:Create(RainDirection, tweenInfo, {Value = direction}):Play()
	else
		RainDirection.Value = direction
	end
	
end


function Rain:SetStraightTexture(asset)
	
	if typeof(asset) ~= "string" then
		error("bad argument #1 to 'SetStraightTexture' (string expected, got " .. typeof(asset) .. ")", 2)
	end
	
	Emitter.RainStraight.Texture = asset
	
	for _,v in pairs(rainAttachments) do
		v.RainStraight.Texture = asset
	end
	
end

function Rain:SetTopDownTexture(asset)
	
	if typeof(asset) ~= "string" then
		error("bad argument #1 to 'SetStraightTexture' (string expected, got " .. typeof(asset) .. ")", 2)
	end
	
	Emitter.RainTopDown.Texture = asset
	
	for _,v in pairs(rainAttachments) do
		v.RainTopDown.Texture = asset
	end
	
end

function Rain:SetSplashTexture(asset)
	
	if typeof(asset) ~= "string" then
		error("bad argument #1 to 'SetStraightTexture' (string expected, got " .. typeof(asset) .. ")", 2)
	end
	
	for _,v in pairs(splashAttachments) do
		v.RainSplash.Texture = asset
	end
	
end

function Rain:SetSoundId(asset)
	
	if typeof(asset) ~= "string" then
		error("bad argument #1 to 'SetSoundId' (string expected, got " .. typeof(asset) .. ")", 2)
	end
	
	Sound.SoundId = asset
	
end

return Rain

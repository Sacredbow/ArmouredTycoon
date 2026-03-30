--!strict
-- Designed by Sacredbow1



local ServerScriptService = game:GetService("ServerScriptService")
local RunService          = game:GetService("RunService")
local TweenService        = game:GetService("TweenService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local ServerStorage       = game:GetService("ServerStorage")



local Services     = ServerScriptService:FindFirstChild("Services") :: Folder
local NuclearFrame = ServerStorage.UI:FindFirstChild("NuclearFrame")       :: Frame
local RocketFunc   = ReplicatedStorage.Remotes:FindFirstChild("ReturnRequest") :: RemoteEvent


type IPlayerService = {
	HasActivated: (self: IPlayerService, player: Player) -> boolean,
}

local PlayerService: IPlayerService =
	require(Services:FindFirstChild("PlayerService") :: ModuleScript) :: IPlayerService


type RocketAssets = {
	Impact:    BasePart,
	Explosion: BasePart,
	Phase3:    BasePart,
	Smoke:    Attachment,
	Fire:      Attachment,
	SmokeParticle: ParticleEmitter
}

type RocketConfig = {
	LaunchAcc:             number,
	MaximumSpeed:          number,
	TurnSpeed:             number,
	GuidanceStartDistance: number,
	SlowdownDistance:      number,
	GuidanceDelay:         number,
}

type RocketState = {
	currentSpeed:   number,
	isLaunched:     boolean,
	guidanceActive: boolean,
	flightTime:     number,
	shineStarted:   boolean,
	connection:     RBXScriptConnection?,
}

type RocketRefs = {
	Rocket:        Model,
	Player:        Player,
	PlayerService: IPlayerService,
	OuterRocket:   MeshPart,
	Target:        BasePart,
}



type Audios = {
	Evacuation:  Sound,
	Critical:    Sound,
	EvacFacility: Sound,
	Alarm3:      Sound,
	SDWarning:   Sound,
	Meltdown:    Sound,
	Alarm2:      Sound,
	ExplosionSFX: Sound,  
	Shockwave:   Sound,
}


export type RocketModule = RocketRefs & RocketAssets & RocketConfig & RocketState & Audios & {
	StartRocket:             (self: RocketModule) -> (),
	UpdateSpeed:             (self: RocketModule, deltaTime: number) -> (),
	_ActivateGuidanceEffects:(self: RocketModule) -> (),
	_StartShineEffect:       (self: RocketModule) -> (),
	_SteerToTarget:          (self: RocketModule, deltaTime: number) -> (),
	_Detonate:               (self: RocketModule) -> (),
	Init:                    (self: RocketModule) -> (),
}




local function assertInstance(value: Instance?, expectedClass: string, label: string): Instance
	if value == nil then
		error(string.format("[RocketModule] Missing '%s' (expected: %s)", label, expectedClass), 2)
	end
	if not (value :: Instance):IsA(expectedClass) then
		error(string.format(
			"[RocketModule] '%s' expected class '%s', got '%s'",
			label, expectedClass, (value :: Instance).ClassName
			), 2)
	end
	return value :: Instance
end

local function playTween(object: Instance, info: TweenInfo, goals: { [string]: any })
	TweenService:Create(object, info, goals):Play()
end



local RocketModuleClass = {}
RocketModuleClass.__index = RocketModuleClass


function RocketModuleClass.new(Rocket: Model, Player: Player, playerService: IPlayerService, Audios : Folder): RocketModule
	local self = setmetatable({}, RocketModuleClass) :: any


	self.Rocket        = Rocket
	self.Player        = Player
	self.PlayerService = playerService
	self.OuterRocket   = assertInstance(Rocket:FindFirstChild("OuterRocket"), "MeshPart",  "OuterRocket") :: MeshPart
	self.Audios = Audios
	
	
	self.Impact    = assertInstance(Rocket:FindFirstChild("Impact"),    "BasePart", "Impact")    :: BasePart
	self.Explosion = assertInstance(Rocket:FindFirstChild("Explosion"), "BasePart", "Explosion") :: BasePart
	self.Phase3    = self.OuterRocket:FindFirstChild("Phase3")    :: BasePart

	local Nozzle = assertInstance(Rocket:FindFirstChild("Nozzle"), "MeshPart", "Nozzle") :: MeshPart
	self.Smoke   = assertInstance(Nozzle:FindFirstChild("Smoke"), "Attachment", "Smoke") ::Attachment
	self.Fire    = assertInstance(Nozzle:FindFirstChild("Fire"),  "Attachment",          "Fire")  :: Attachment
	self.SmokeParticle = assertInstance( self.Smoke:FindFirstChild("ParticleEmitter") ,  "ParticleEmitter",          "SmokeParticle")  :: ParticleEmitter
	
	
	self.Evacuation   = assertInstance(Audios:FindFirstChild("Evacuation"),   "Sound", "Evacuation")   :: Sound
	self.Critical     = assertInstance(Audios:FindFirstChild("Critical"),     "Sound", "Critical")     :: Sound
	self.EvacFacility = assertInstance(Audios:FindFirstChild("EvacFacility"), "Sound", "EvacFacility") :: Sound
	self.Alarm3       = assertInstance(Audios:FindFirstChild("Alarm3"),       "Sound", "Alarm3")       :: Sound
	self.SDWarning    = assertInstance(Audios:FindFirstChild("SDWarning"),    "Sound", "SDWarning")    :: Sound
	self.Meltdown     = assertInstance(Audios:FindFirstChild("Meltdown"),     "Sound", "Meltdown")     :: Sound
	self.Alarm2       = assertInstance(Audios:FindFirstChild("Alarm2"),       "Sound", "Alarm2")       :: Sound
	self.ExplosionSFX = assertInstance(Audios:FindFirstChild("Explosion"),    "Sound", "ExplosionSFX") :: Sound
	self.Shockwave    = assertInstance(Audios:FindFirstChild("Shockwave"),    "Sound", "Shockwave")    :: Sound


	self.LaunchAcc             = 30
	self.MaximumSpeed          = 500
	self.TurnSpeed             = 3
	self.GuidanceStartDistance = 20000
	self.SlowdownDistance      = 100
	self.GuidanceDelay         = 30


	self.currentSpeed   = 0
	self.isLaunched     = false
	self.guidanceActive = false
	self.flightTime     = 0
	self.shineStarted   = false
	self.connection     = nil
	
	

	--self.Evacuation = self.Audios.Evacuation :: Sound
	--self.Critical = self.Audios.Critical :: Sound
	--self.EvacFacility = self.Audios.EvacFacility :: Sound
	--self.Alarm3 = self.Audios.Alarm3 :: Sound
	--self.SDWarning = self.Audios.SDWarning :: Sound
	--self.Meltdown = self.Audios.Meltdown :: Sound
	--self.Alarm2 = self.Audios.Alarm2 :: Sound
	--self.ExplosionSound = self.Audios.Explosion :: Sound
	--self.Shockwave = self.Audios.Shockwave :: Sound

	return self 
end


function RocketModuleClass:StartRocket()
	local self = self :: RocketModule
	self.Rocket.PrimaryPart = self.OuterRocket
	
	
self.Evacuation:Play()

task.wait(3)
self.Critical:Play()

	local Highlight = Instance.new("Highlight")
	Highlight.OutlineTransparency = 1
	Highlight.FillColor           = Color3.fromRGB(66, 66, 66)
	Highlight.FillTransparency    = 1
	Highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	Highlight.Parent              = self.OuterRocket
	

	local HALF_SEC = TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)

	local function tweenColor(color: Color3)
		playTween(Highlight, HALF_SEC, { FillColor = color })
	end

	local function setFireSize(size: number)
		for _, child in self.Fire:GetChildren() do
			local emitter = child :: ParticleEmitter
			emitter.Enabled = true
			emitter.Size    = NumberSequence.new(size)
		end
	end

	
	playTween(Highlight, TweenInfo.new(5, Enum.EasingStyle.Back, Enum.EasingDirection.In), { FillTransparency = 0 })

	task.wait(2)
	tweenColor(Color3.fromRGB(255, 255, 0))
	self.SmokeParticle.Enabled = true 
	
	self.EvacFacility:Play()

	task.wait(6)
	tweenColor(Color3.fromRGB(255, 85, 0))
	setFireSize(1)
self.Alarm3:Play()


	task.wait(6)
	tweenColor(Color3.fromRGB(255, 0, 0))
	setFireSize(20)
	self.SDWarning:Play()

	task.wait(6)
	tweenColor(Color3.fromRGB(255, 255, 255))
	setFireSize(25)
self.Alarm3:Stop()

self.Meltdown:Play()

task.wait(2)

self.Alarm2:Play()
self.EvacFacility:Play()
self.Evacuation:Play()


	task.wait(4)

	self.isLaunched   = true
	self.currentSpeed = 10

	self.connection = RunService.Heartbeat:Connect(function(deltaTime: number)
		self:UpdateSpeed(deltaTime)
	end)
end


function RocketModuleClass:UpdateSpeed(deltaTime: number)
	local self = self :: RocketModule

	if not self.isLaunched then return end

	self.flightTime += deltaTime

	local distanceToTarget: number = (self.Target.Position - self.OuterRocket.Position).Magnitude


	if not self.guidanceActive and self.currentSpeed < self.MaximumSpeed then
		self.currentSpeed = math.min(
			self.currentSpeed + self.LaunchAcc * deltaTime * 60,
			self.MaximumSpeed
		)
	end

	if
		not self.guidanceActive
		and self.flightTime  >= self.GuidanceDelay
		and distanceToTarget <  self.GuidanceStartDistance
	then
		self.guidanceActive = true
		self:_ActivateGuidanceEffects()
	end


	if self.flightTime >= 4 and not self.shineStarted then
		self.shineStarted = true
		self:_StartShineEffect()
	end

	
	if self.guidanceActive then
		if distanceToTarget > 5 then
			self:_SteerToTarget(deltaTime)
		else
			self:_Detonate()
			return
		end
	else
	
		local targetSpeed = self.currentSpeed
		if self.OuterRocket.Position.Y > 0 then
			targetSpeed = math.max(20, self.currentSpeed - deltaTime * 50)
		end
		self.currentSpeed += (targetSpeed - self.currentSpeed) * deltaTime * 2
	end

	
	self.OuterRocket.CFrame += -self.OuterRocket.CFrame.UpVector * self.currentSpeed * deltaTime
end



function RocketModuleClass:_ActivateGuidanceEffects()
	local self = self :: RocketModule

	for _, v in self.Phase3:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			local emitter = v :: ParticleEmitter
			local running = true
			task.spawn(function()
				while running do
					emitter:Emit(10)
					task.wait(1)
				end
			end)
			task.delay(7, function()
				running = false
			end)

		elseif v:IsA("Beam") then
			(v :: Beam).Enabled = true
		end
	end
end



function RocketModuleClass:_StartShineEffect()
	local self = self :: RocketModule

	local Shine = self.Rocket:FindFirstChild("Shine")
	if not Shine then
		warn("[RocketModule] 'Shine' child not found on Rocket")
		return
	end

	local Attachment = Shine:FindFirstChildOfClass("Attachment")
	if not Attachment then
		warn("[RocketModule] Attachment not found inside Shine")
		return
	end

	local emitters: { ParticleEmitter } = {}
	for _, child in Attachment:GetChildren() do
		if child:IsA("ParticleEmitter") then
			local emitter = child :: ParticleEmitter
			emitter.Enabled = true
			table.insert(emitters, emitter)
		end
	end

	local running = true

	task.spawn(function()
		while running do
			task.wait(0.05)
			for _, emitter in emitters do
				emitter:Emit(1)
			end
		end
	end)

	task.delay(15, function()
		running = false
	end)
end



function RocketModuleClass:_SteerToTarget(deltaTime: number)
	local self = self :: RocketModule

	local direction: Vector3 = (self.Target.Position - self.OuterRocket.Position).Unit
	local forward: Vector3   = -self.OuterRocket.CFrame.UpVector
	local blended: Vector3   = forward:Lerp(direction, self.TurnSpeed * deltaTime)
	local newCFrame: CFrame  = CFrame.lookAt(self.OuterRocket.Position, self.OuterRocket.Position + blended)
	self.OuterRocket.CFrame  = newCFrame * CFrame.Angles(math.rad(90), 0, 0)
end

function RocketModuleClass:_Detonate()
	local self = self :: RocketModule

	self.guidanceActive = false
	self.isLaunched     = false

	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end

	local NewExplosion  = self.Explosion:Clone()
	NewExplosion.Parent = self.Target
	NewExplosion.CFrame = self.Target.CFrame

	local sizeValue = Instance.new("NumberValue")
	sizeValue.Value = 0

	sizeValue:GetPropertyChangedSignal("Value"):Connect(function()
		for _, v in NewExplosion:GetDescendants() do
			if v:IsA("ParticleEmitter") then
				local emitter = v :: ParticleEmitter
				emitter.Size = NumberSequence.new(sizeValue.Value)
				emitter:Emit(1)
			end
		end
	end)

	local growTween = TweenService:Create(
		sizeValue,
		TweenInfo.new(5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Value = 1500 }
	)

	growTween:Play()

self.Alarm2:Stop()
self.ExplosionSFX:Play()
self.Shockwave:Play()

	growTween.Completed:Once(function()
		NewExplosion:Destroy()

		local StartImpact = self.Impact:Clone()
		StartImpact.Parent = workspace
		StartImpact.CFrame = self.Target.CFrame

		local running = true

		task.spawn(function()
			while running do
				for _, v in StartImpact:GetDescendants() do
					if v:IsA("ParticleEmitter") then
						(v :: ParticleEmitter):Emit(1)
						task.wait(1)
					end
				end
			end
		end)

		task.delay(15, function()
			running = false
			StartImpact:Destroy()
		end)
	end)
-- Janitor

	task.delay(0, self.OuterRocket.Destroy, self.OuterRocket)


end


function RocketModuleClass:Init()
	local self = self :: RocketModule

	if not self.PlayerService:HasActivated(self.Player) then
		print("[RocketModule] Player has not activated:", self.Player.Name)
		return
	end

	local PlayerGui = self.Player:FindFirstChildOfClass("PlayerGui") :: PlayerGui
	local MainInterface  = PlayerGui:FindFirstChild("MainInterface") :: ScreenGui
	if not PlayerGui then
		warn("[RocketModule] PlayerGui not found for:", self.Player.Name)
		return
	end

	local Panel = NuclearFrame:Clone() 
	Panel.Parent = MainInterface
	print("[RocketModule] Panel shown for:", self.Player.Name)

	RocketFunc.OnServerEvent:Connect(function(player: Player, argument: string)

		if player ~= self.Player then return end


		local TycoonsFolder = workspace:FindFirstChild("Tycoons") :: Folder?
		if not TycoonsFolder then
			warn("[RocketModule] 'Tycoons' folder not found in workspace")
			return
		end

		local Tycoon = TycoonsFolder:FindFirstChild(argument) :: Model?
		if not Tycoon then
			warn("[RocketModule] Tycoon not found:", argument)
			return
		end

		local MainItems = Tycoon:FindFirstChild("MainItems") :: Folder?
		if not MainItems then
			warn("[RocketModule] MainItems missing in:", argument)
			return
		end

		local RawTarget = MainItems:FindFirstChild("Target")
		if not RawTarget then
			warn("[RocketModule] Target missing in MainItems of:", argument)
			return
		end

		if not RawTarget:IsA("BasePart") then
			warn("[RocketModule] Target is not a BasePart in:", argument)
			return
		end

		self.Target = RawTarget :: BasePart
		self:StartRocket()
	end)
end



return RocketModuleClass
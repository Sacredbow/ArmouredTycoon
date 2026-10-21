--!strict

local Players = game:GetService("Players")
local Runtime = require(script.Parent:WaitForChild("Runtime"))

type Context = {
	events: Instance,
	fx: Instance,
	hitmarker: any,
}

local CharacterEffects = {}

local WHIZZ_SOUNDS = {
	"4872110675",
	"5303773495",
	"5303772965",
	"5303773495",
	"5303772257",
	"342190005",
	"342190012",
	"342190017",
	"342190024",
}

local nvgEnabled = false

local function destroyLater(instance: Instance, lifetime: number)
	task.delay(lifetime, function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

local function schedule(delay: number, callback: () -> (), _name: string?)
	task.delay(delay, callback)
end

local function updateFlashPoints(weapon: Model, enabled: boolean)
	for _, descendant in weapon:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name == "FlashPoint" then
			local light = descendant:FindFirstChildWhichIsA("Light")
			if light then
				light.Enabled = enabled
			end
		end
	end
end

local function getLaserPart(player: Player): BasePart?
	local laser = Runtime.getEffectsFolder():FindFirstChild(player.Name .. "_Laser")

	if laser and laser:IsA("BasePart") then
		return laser
	end

	return nil
end

local function createLaserPart(player: Player, color: Color3, weapon: Instance?): BasePart?
	local dot = Instance.new("Part")
	dot.Name = player.Name .. "_Laser"
	dot.Transparency = 1
	dot.CanCollide = false
	dot.Anchored = true
	dot.Shape = Enum.PartType.Ball
	dot.Size = Vector3.new(0.2, 0.2, 0.2)
	dot.Material = Enum.Material.Neon
	dot.Color = color
	dot.Parent = Runtime.getEffectsFolder()

	local attachment = Instance.new("Attachment")
	attachment.Name = "Att0"
	attachment.Parent = dot

	local muzzle = Runtime.findMuzzle(player, weapon)
	if muzzle then
		local beam = Instance.new("Beam")
		beam.Name = "Beam"
		beam.Transparency = NumberSequence.new(0)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Attachment0 = attachment
		beam.Attachment1 = muzzle
		beam.Color = ColorSequence.new(color)
		beam.FaceCamera = true
		beam.Width0 = 0.01
		beam.Width1 = 0.01
		beam.Enabled = nvgEnabled
		beam.Parent = dot
	end

	return dot
end

local function setLaserBeamEnabled(laser: BasePart, enabled: boolean)
	local beam = laser:FindFirstChild("Beam")
	if beam and beam:IsA("Beam") then
		beam.Enabled = enabled
	end
end

local function pulseColorCorrection(startContrast: number, fadeTime: number)
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Parent = Runtime.getCurrentCamera()

	Runtime.tween(effect, TweenInfo.new(0.15, Enum.EasingStyle.Linear), {
		Contrast = startContrast,
	})

	schedule(0.15, function()
		Runtime.tween(effect, TweenInfo.new(fadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, 0.15), {
			Contrast = 0,
		})
		destroyLater(effect, fadeTime)
	end, "CharacterEffect:ColorCorrectionFade")
end

local function playEarRing(context: Context, duration: number)
	local earRing = context.fx:FindFirstChild("EarRing")
	if not earRing or not earRing:IsA("Sound") then
		return
	end

	local ring = earRing:Clone()
	ring.Volume = 0
	ring.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	ring:Play()
	destroyLater(ring, duration)

	Runtime.tween(ring, TweenInfo.new(0.1), {
		Volume = 2,
	})

	schedule(0.1, function()
		Runtime.tween(ring, TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 0, false, 0.15), {
			Volume = 0,
		})
	end, "CharacterEffect:EarRingFade")
end

local function pulseImage(image: ImageLabel, duration: number)
	Runtime.tween(image, TweenInfo.new(0.1), {
		ImageTransparency = 0,
		Size = UDim2.fromScale(1, 1.15),
	})

	schedule(0.1, function()
		Runtime.tween(image, TweenInfo.new(duration, Enum.EasingStyle.Exponential, Enum.EasingDirection.InOut, 0, false, 0.15), {
			ImageTransparency = 1,
			Size = UDim2.fromScale(2, 2),
		})
	end, "CharacterEffect:ImagePulseFade")
end

local function bindNvg(context: Context)
	local event = Runtime.getBindableEvent(context.events, "NVG")
	if not event then
		return
	end

	event.Event:Connect(function(enabled: boolean)
		nvgEnabled = enabled
	end)
end

local function bindHitEffect(context: Context)
	local event = Runtime.getRemoteEvent(context.events, "HitEffect")
	if not event then
		return
	end

	event.OnClientEvent:Connect(function(player: Player, position: Vector3, hitPart: BasePart, normal: Vector3, material: Enum.Material, settings: any)
		if player ~= Players.LocalPlayer then
			context.hitmarker.HitEffect(Runtime.getRaycastIgnoreList(), position, hitPart, normal, material, settings)
		end
	end)
end

local function bindRemoteFire(context: Context)
	local event = Runtime.getRemoteEvent(context.events, "Atirar")
	if not event then
		return
	end

	event.OnClientEvent:Connect(function(player: Player, weapon: Instance?, suppressor: boolean?, flashHider: boolean?)
		if player == Players.LocalPlayer or not player.Character or not weapon then
			return
		end

		local muzzle = Runtime.findMuzzle(player, weapon)
		if muzzle then
			Runtime.playChildSound(muzzle, if suppressor then "Supressor" else "Fire")

			if not flashHider then
				Runtime.emitChild(muzzle, "FlashFX[Flash]", 10)
			end

			Runtime.emitChild(muzzle, "Smoke", 10)
		end

		local animBase = player.Character:FindFirstChild("AnimBase")
		local animWeld = animBase and animBase:FindFirstChild("AnimBaseW")
		if animWeld and animWeld:IsA("Motor6D") then
			Runtime.tween(animWeld, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
				C1 = CFrame.new(0, 0, 0.15):Inverse(),
			})

			schedule(0.1, function()
				Runtime.tween(animWeld, TweenInfo.new(0.05, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
					C1 = CFrame.new():Inverse(),
				})
			end, "CharacterEffect:RemoteFireRecover")
		end
	end)
end

local function bindLaser(context: Context)
	local event = Runtime.getRemoteEvent(context.events, "SVLaser")
	if not event then
		return
	end

	event.OnClientEvent:Connect(function(player: Player, position: Vector3, mode: number, color: Color3, infrared: boolean?, weapon: Instance?)
		if player == Players.LocalPlayer or not player.Character or not weapon then
			return
		end

		if mode == 1 then
			local laser = getLaserPart(player) or createLaserPart(player, color, weapon)
			if not laser then
				return
			end

			laser.Position = position
			laser.Color = color
			laser.Transparency = if nvgEnabled then 0 elseif infrared then 1 else 0
			setLaserBeamEnabled(laser, nvgEnabled)
		elseif mode == 2 then
			local laser = getLaserPart(player)
			if laser then
				laser:Destroy()
			end
		end
	end)
end

local function bindFlashlight(context: Context)
	local event = Runtime.getRemoteEvent(context.events, "SVFlash")
	if not event then
		return
	end

	event.OnClientEvent:Connect(function(player: Player, weapon: Instance?, enabled: boolean)
		if player == Players.LocalPlayer or not player.Character or not weapon then
			return
		end

		local weaponModel = Runtime.findRemoteWeapon(player, weapon)
		if weaponModel then
			updateFlashPoints(weaponModel, enabled)
		end
	end)
end

local function bindWhizz(context: Context)
	local event = Runtime.getRemoteEvent(context.events, "Whizz")
	if not event then
		return
	end

	event.OnClientEvent:Connect(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. WHIZZ_SOUNDS[math.random(1, #WHIZZ_SOUNDS)]
		sound.Volume = 2
		sound.PlayOnRemove = true
		sound.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		sound:Destroy()
	end)
end

local function bindMedicalEffects(context: Context)
	local medSys = context.events:FindFirstChild("MedSys")
	local medHandler = medSys and medSys:FindFirstChild("MedHandler")

	if not medHandler or not medHandler:IsA("RemoteEvent") then
		return
	end

	medHandler.OnClientEvent:Connect(function(mode: number)
		if mode == 4 then
			pulseColorCorrection(-0.25, 1.5)
		elseif mode == 5 then
			pulseColorCorrection(0.5, 1.5)
		elseif mode == 6 then
			pulseColorCorrection(-0.25, 60)
		elseif mode == 7 then
			pulseColorCorrection(0.5, 30)
		end
	end)
end

local function bindSuppression(context: Context)
	local event = Runtime.getRemoteEvent(context.events, "Suppression")
	if not event then
		return
	end

	event.OnClientEvent:Connect(function(mode: number, _intensity: number, duration: number)
		local player = Players.LocalPlayer
		if not Runtime.getAliveHumanoid(player.Character) then
			return
		end

		local statusUi = player:WaitForChild("PlayerGui"):FindFirstChild("StatusUI")
		local effects = statusUi and statusUi:FindFirstChild("Efeitos")
		if not effects then
			return
		end

		if mode == 1 then
			local suppress = effects:FindFirstChild("Suppress")
			if suppress and suppress:IsA("ImageLabel") then
				pulseImage(suppress, 1)
			end
		elseif mode == 2 then
			playEarRing(context, duration)

			local dirty = effects:FindFirstChild("Dirty")
			if dirty and dirty:IsA("ImageLabel") then
				pulseImage(dirty, duration)
			end
		else
			playEarRing(context, duration)
		end
	end)
end

local function bindGunStance(context: Context)
	local event = Runtime.getRemoteEvent(context.events, "GunStance")
	if not event then
		return
	end

	local stanceGoals = {
		[0] = { "SV_RightArmPos", "SV_LeftArmPos" },
		[2] = { "RightAim", "LeftAim" },
		[1] = { "RightHighReady", "LeftHighReady" },
		[-1] = { "RightLowReady", "LeftLowReady" },
		[-2] = { "RightPatrol", "LeftPatrol" },
	}

	event.OnClientEvent:Connect(function(player: Player, stance: number, data: { [string]: CFrame })
		if not Runtime.getAliveHumanoid(player.Character) then
			return
		end

		local character = player.Character :: Model
		local animBase = character:FindFirstChild("AnimBase")
		local rightWeld = animBase and animBase:FindFirstChild("RAW")
		local leftWeld = animBase and animBase:FindFirstChild("LAW")
		local goals = stanceGoals[stance]

		if not goals or not rightWeld or not leftWeld then
			return
		end

		Runtime.tween(rightWeld, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
			C0 = data[goals[1]],
		})

		Runtime.tween(leftWeld, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
			C0 = data[goals[2]],
		})
	end)
end

local function bindHeadRotation(context: Context)
	local event = Runtime.getRemoteEvent(context.events, "HeadRot")
	if not event then
		return
	end

	event.OnClientEvent:Connect(function(player: Player, cframe: CFrame, aimPitch: number?, aiming: boolean?)
		if player == Players.LocalPlayer or not player.Character then
			return
		end

		local torso = player.Character:FindFirstChild("Torso")
		local neck = torso and torso:FindFirstChild("Neck")
		if neck and neck:IsA("Motor6D") then
			Runtime.tween(neck, TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				C1 = cframe,
			})
		end

		local animBase = player.Character:FindFirstChild("AnimBase")
		local animWeld = animBase and animBase:FindFirstChild("AnimBaseW")
		if animWeld and animWeld:IsA("Motor6D") then
			local pitch = if aiming and typeof(aimPitch) == "number" then math.clamp(aimPitch, -1.1, 1.1) else 0
			Runtime.tween(animWeld, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
				C0 = CFrame.Angles(pitch * 0.72, 0, 0),
			})
		end
	end)
end

function CharacterEffects.start(context: Context)
	bindNvg(context)
	bindHitEffect(context)
	bindRemoteFire(context)
	bindLaser(context)
	bindFlashlight(context)
	bindWhizz(context)
	bindMedicalEffects(context)
	bindSuppression(context)
	bindGunStance(context)
	bindHeadRotation(context)
end

return CharacterEffects

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponDefinitionResolver = require(ReplicatedStorage.Weapons.Resolver)
local Runtime = require(script.Parent:WaitForChild("Runtime"))
local PacketBootstrap = require(ReplicatedStorage.Network.PacketBootstrap)
local Packets = PacketBootstrap.Get()

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
	Packets.packets.HitEffectPresentation.listen(function(data)
		local player = Players:GetPlayerByUserId(data.shooterUserId)
		local material = if typeof(data.material) == "string" then Enum.Material[data.material] else nil
		local weapon = data.weapon
		if not player or player == Players.LocalPlayer or not material or not data.hitPart or not data.hitPart:IsA("BasePart")
			or not weapon or not weapon:IsA("Tool") then
			return
		end

		local settingsModule = WeaponDefinitionResolver.getSettings(weapon)
		if not settingsModule or not settingsModule:IsA("ModuleScript") then
			return
		end
		local settingsOk, settings = pcall(require, settingsModule)
		if not settingsOk or type(settings) ~= "table" then
			return
		end

		context.hitmarker.HitEffect(
			Runtime.getRaycastIgnoreList(),
			data.position,
			data.hitPart,
			data.normal,
			material,
			settings
		)
	end)
end

local function bindRemoteFire(_context: Context)
	Packets.packets.WeaponFirePresentation.listen(function(data)
		local player = Players:GetPlayerByUserId(data.shooterUserId)
		if not player or player == Players.LocalPlayer or not player.Character or not data.weapon then
			return
		end

		local muzzle = Runtime.findMuzzle(player, data.weapon)
		if muzzle then
			Runtime.playChildSound(muzzle, if data.suppressor then "Supressor" else "Fire")

			if not data.flashHider then
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
local function bindLaser(_context: Context)
	Packets.packets.LaserPresentation.listen(function(data)
		local player = Players:GetPlayerByUserId(data.shooterUserId)
		if not player or player == Players.LocalPlayer or not player.Character or not data.weapon then
			return
		end

		if data.mode == 1 then
			local laser = getLaserPart(player) or createLaserPart(player, data.color, data.weapon)
			if not laser or not data.position or not data.color then
				return
			end

			laser.Position = data.position
			laser.Color = data.color
			laser.Transparency = if nvgEnabled then 0 elseif data.infrared then 1 else 0
			setLaserBeamEnabled(laser, nvgEnabled)
		elseif data.mode == 2 then
			local laser = getLaserPart(player)
			if laser then
				laser:Destroy()
			end
		end
	end)
end

local function bindFlashlight(_context: Context)
	Packets.packets.FlashPresentation.listen(function(data)
		local player = Players:GetPlayerByUserId(data.shooterUserId)
		if not player or player == Players.LocalPlayer or not player.Character or not data.weapon then
			return
		end

		local weaponModel = Runtime.findRemoteWeapon(player, data.weapon)
		if weaponModel then
			updateFlashPoints(weaponModel, data.enabled)
		end
	end)
end

local function bindWhizz(_context: Context)
	Packets.packets.WhizzPresentation.listen(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://" .. WHIZZ_SOUNDS[math.random(1, #WHIZZ_SOUNDS)]
		sound.Volume = 2
		sound.PlayOnRemove = true
		sound.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
		sound:Destroy()
	end)
end


local function bindSuppression(context: Context)
	Packets.packets.SuppressionPresentation.listen(function(data)
		local player = Players.LocalPlayer
		if not Runtime.getAliveHumanoid(player.Character) then
			return
		end

		local statusUi = player:WaitForChild("PlayerGui"):FindFirstChild("StatusUI")
		local effects = statusUi and statusUi:FindFirstChild("Efeitos")
		if not effects then
			return
		end

		if data.mode == 1 then
			local suppress = effects:FindFirstChild("Suppress")
			if suppress and suppress:IsA("ImageLabel") then
				pulseImage(suppress, 1)
			end
		elseif data.mode == 2 then
			playEarRing(context, data.duration)

			local dirty = effects:FindFirstChild("Dirty")
			if dirty and dirty:IsA("ImageLabel") then
				pulseImage(dirty, data.duration)
			end
		else
			playEarRing(context, data.duration)
		end
	end)
end

local function bindGunStance(_context: Context)
	Packets.packets.GunStancePresentation.listen(function(data)
		local player = Players:GetPlayerByUserId(data.shooterUserId)
		if not player or not Runtime.getAliveHumanoid(player.Character) then
			return
		end

		local character = player.Character :: Model
		local animBase = character:FindFirstChild("AnimBase")
		local rightWeld = animBase and animBase:FindFirstChild("RAW")
		local leftWeld = animBase and animBase:FindFirstChild("LAW")
		local stanceGoals = {
			[0] = { "SV_RightArmPos", "SV_LeftArmPos" },
			[2] = { "RightAim", "LeftAim" },
			[1] = { "RightHighReady", "LeftHighReady" },
			[-1] = { "RightLowReady", "LeftLowReady" },
			[-2] = { "RightPatrol", "LeftPatrol" },
		}
		local goals = stanceGoals[data.stance]
		if not goals or not rightWeld or not leftWeld then
			return
		end

		local animationsModule: ModuleScript? = nil
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				local candidate = child:FindFirstChild("ACS_Animations")
				if candidate and candidate:IsA("ModuleScript") then
					animationsModule = candidate
					break
				end
			end
		end
		if not animationsModule then
			return
		end

		local loaded, animations = pcall(require, animationsModule)
		if not loaded or type(animations) ~= "table" then
			return
		end

		local rightGoal = animations[goals[1]]
		local leftGoal = animations[goals[2]]
		if typeof(rightGoal) ~= "CFrame" or typeof(leftGoal) ~= "CFrame" then
			return
		end

		Runtime.tween(rightWeld, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
			C0 = rightGoal,
		})
		Runtime.tween(leftWeld, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {
			C0 = leftGoal,
		})
	end)
end


function CharacterEffects.start(context: Context)
	bindNvg(context)
	bindHitEffect(context)
	bindRemoteFire(context)
	bindLaser(context)
	bindFlashlight(context)
	bindWhizz(context)
	bindSuppression(context)
	bindGunStance(context)
end

return CharacterEffects

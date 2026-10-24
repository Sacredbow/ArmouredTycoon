--!strict

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Runtime = {}

local EFFECTS_FOLDER_NAME = "GunRegistryClientEffects"
local MUZZLE_ATTACHMENT_NAMES = { "Muzzle", "BarrelPos", "FlashPoint", "FirePoint" }
local MUZZLE_PART_NAMES = { "FlashPoint", "BarrelPos", "Muzzle" }

function Runtime.getCurrentCamera(): Camera
	local currentCamera = workspace.CurrentCamera

	if not currentCamera then
		error("[Registry Runtime] workspace.CurrentCamera is not ready")
	end

	return currentCamera
end

function Runtime.getEffectsFolder(): Folder
	local currentCamera = Runtime.getCurrentCamera()
	local existingFolder = currentCamera:FindFirstChild(EFFECTS_FOLDER_NAME)

	if existingFolder and existingFolder:IsA("Folder") then
		return existingFolder
	end

	local effectsFolder = Instance.new("Folder")
	effectsFolder.Name = EFFECTS_FOLDER_NAME
	effectsFolder.Parent = currentCamera

	return effectsFolder
end

function Runtime.getRaycastIgnoreList(): { Instance }
	local localPlayer = Players.LocalPlayer
	local ignoreList: { Instance } = {
		Runtime.getCurrentCamera(),
		Runtime.getEffectsFolder(),
	}

	if localPlayer.Character then
		table.insert(ignoreList, localPlayer.Character)
	end

	return ignoreList
end

function Runtime.findRemoteWeapon(player: Player, weapon: Instance?): Model?
	if not weapon or not player.Character then
		return nil
	end

	local weaponModel = player.Character:FindFirstChild("S" .. weapon.Name)
	if weaponModel and weaponModel:IsA("Model") then
		return weaponModel
	end

	return nil
end

function Runtime.findMuzzle(player: Player, weapon: Instance?): Attachment?
	local weaponModel = Runtime.findRemoteWeapon(player, weapon)
	if not weaponModel then
		return nil
	end

	for _, name in MUZZLE_ATTACHMENT_NAMES do
		local attachment = weaponModel:FindFirstChild(name, true)
		if attachment and attachment:IsA("Attachment") then
			return attachment
		end
	end

	for _, name in MUZZLE_PART_NAMES do
		local part = weaponModel:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			local attachment = part:FindFirstChild("GeneratedMuzzleAttachment")
			if attachment and attachment:IsA("Attachment") then
				return attachment
			end

			local created = Instance.new("Attachment")
			created.Name = "GeneratedMuzzleAttachment"
			created.Parent = part
			return created
		end
	end

	return nil
end

function Runtime.getAliveHumanoid(character: Model?): Humanoid?
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid
end

function Runtime.getBindableEvent(parent: Instance, name: string): BindableEvent?
	local event = parent:FindFirstChild(name)
	if event and event:IsA("BindableEvent") then
		return event
	end

	return nil
end

function Runtime.getNumber(value: number?, fallback: number): number
	if typeof(value) == "number" then
		return value
	end

	return fallback
end

function Runtime.tween(instance: Instance, tweenInfo: TweenInfo, goals: { [string]: any })
	TweenService:Create(instance, tweenInfo, goals):Play()
end

function Runtime.playChildSound(parent: Instance, soundName: string)
	local sound = parent:FindFirstChild(soundName)

	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

function Runtime.emitChild(parent: Instance, emitterName: string, count: number)
	local emitter = parent:FindFirstChild(emitterName)

	if emitter and emitter:IsA("ParticleEmitter") then
		emitter:Emit(count)
	end
end

return Runtime

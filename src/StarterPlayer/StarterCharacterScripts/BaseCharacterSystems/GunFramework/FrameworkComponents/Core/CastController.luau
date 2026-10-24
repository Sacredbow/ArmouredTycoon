--!strict
--[[
	@class CastController

	@desc
	Owns bullet creation, ray casting, hit detection, melee casting,
	and tracer calculation. All server-facing damage remotes are fired
	from here, but damage calculation is server-authoritative.
]]

--// Services

const RunService = game:GetService("RunService")
const Players = game:GetService("Players")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const Runtime = require(script.Parent.Runtime)
const HitResolver = require(script.Parent.Parent.Combat.HitResolver)
const HitMod = require(ReplicatedStorage["ACS_Engine"].Modules:WaitForChild("Hitmarker"))
const PacketBootstrap = require(ReplicatedStorage.Shared.Platform.Network.PacketBootstrap)
const Packets = PacketBootstrap.Get()

--// Constants

const MaxDistance = 7000
const WHIZZ_DISTANCE = 25
const IGNORE_NAMES = {
	Ignorable = true, Glass = true, Ignore = true,
	Top = true, Helmet = true, Up = true, Down = true,
	Face = true, Olho = true, Headset = true, Numero = true,
	Vest = true, Chest = true, Waist = true, Back = true,
	Belt = true, Leg1 = true, Leg2 = true, Arm1 = true, Arm2 = true,
	Armor = true, EShield = true,
}

local function addIgnored(instances: { Instance }, instance: Instance)
	for _, existing in instances do
		if existing == instance then
			return
		end
	end
	table.insert(instances, instance)
end
local CastController = {}
CastController.__index = CastController

export type CastController = typeof(setmetatable({} :: {
	_player: Player,
	_camera: Camera,
	_character: Model,
	_effectsFolder: Folder,
	_ignoreModel: { Instance },
	_destroyLater: (Instance, number) -> (),
	_tracers: number,
	_weaponTool: Tool?,
	_weaponData: any,
	_modTable: any,
	_weaponInHand: Model?,
	_gameRules: any,
	_thirdPersonCallback: (() -> boolean)?,
	_castConnections: { [RBXScriptConnection]: boolean },
	_bullets: { [Instance]: boolean },
	_destroyed: boolean,
}, CastController))

function CastController.new(
	player: Player,
	camera: Camera,
	character: Model,
	effectsFolder: Folder,
	ignoreModel: { Instance },
	gameRules: any,
	destroyLaterFn: (Instance, number) -> ()
): CastController
	return setmetatable({
		_player = player,
		_camera = camera,
		_character = character,
		_effectsFolder = effectsFolder,
		_ignoreModel = ignoreModel,
		_gameRules = gameRules,
		_destroyLater = destroyLaterFn,
		_tracers = 0,
		_weaponTool = nil,
		_weaponData = nil,
		_modTable = nil,
		_weaponInHand = nil,
		_thirdPersonCallback = nil,
	_castConnections = {},
	_bullets = {},
	_destroyed = false,
	}, CastController)
end

function CastController:setCamera(camera: Camera)
	self._camera = camera
	self._ignoreModel[1] = camera
end

function CastController:setWeaponState(weaponTool: Tool?, weaponData: any, modTable: any, weaponInHand: Model?)
	self._weaponTool = weaponTool
	self._weaponData = weaponData
	self._modTable = modTable
	self._weaponInHand = weaponInHand
end

function CastController:setThirdPersonCallback(callback: (() -> boolean)?)
	self._thirdPersonCallback = callback
end

function CastController:checkForShield(hitPart: Instance): Model?
	-- Fast path: shield parts are direct children of the Shield model.
	local parent = hitPart.Parent
	if parent and parent:IsA("Model") and parent.Name == "Shield" then
		return parent
	end

	-- Fallback: tolerate parts nested deeper inside a Shield model
	-- (matches the Hitmarker module's own FindFirstAncestor check).
	local ancestor = hitPart:FindFirstAncestor("Shield")
	if ancestor and ancestor:IsA("Model") then
		return ancestor
	end
	return nil
end

function CastController:checkForHumanoid(hitPart: Instance): (boolean, Humanoid?)
	local result = HitResolver.findHumanoid(hitPart)
	return result.found, result.humanoid
end

function CastController:submitDamage(targetHumanoid: Humanoid, limb: number, hitPart: Instance)
	if self._destroyed then
		return
	end

	local weaponTool = self._weaponTool
	if not self._character.Parent or not weaponTool or weaponTool.Parent ~= self._character or not targetHumanoid.Parent or targetHumanoid.Health <= 0 then
		return
	end

	Packets.packets.DamageIntent.send({ weapon = weaponTool, targetHumanoid = targetHumanoid, hitPart = hitPart, hitType = limb })
end
function CastController:tracerCalc(): boolean
	if not self._weaponData.Tracer and not self._weaponData.BulletFlare then
		return false
	end

	if self._weaponData.RandomTracer and self._weaponData.RandomTracer.Enabled then
		return math.random(1, 100) <= self._weaponData.RandomTracer.Chance
	end

	if self._tracers >= self._weaponData.TracerEveryXShots then
		self._tracers = 0
		return true
	end

	self._tracers += 1
	return false
end

function CastController:createBullet(
	bSpread: number,
	charspeed: number,
	aiming: boolean,
	firstPerson: boolean
)
	if self._destroyed then
		return
	end
	if not self._weaponInHand then
		return
	end

	local bullet = Instance.new("Part")
	bullet.Name = self._player.Name .. "_Bullet"
	bullet.CanCollide = false
	bullet.Shape = Enum.PartType.Ball
	bullet.Transparency = 1
	bullet.Size = Vector3.new(1, 1, 1)
	bullet.Parent = self._effectsFolder
	self._bullets[bullet] = true

	local origin = self._weaponInHand.Handle.Muzzle.WorldPosition
	local direction = self._weaponInHand.Handle.Muzzle.WorldCFrame.LookVector
		+ (self._weaponInHand.Handle.Muzzle.WorldCFrame.UpVector
			* (((self._weaponData.BulletDrop * self._weaponData.CurrentZero / 4) / self._weaponData.MuzzleVelocity) / 2))

	if self._thirdPersonCallback and self._thirdPersonCallback() then
		local viewport = self._camera.ViewportSize
		local ray = self._camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)
		local target = ray.Origin + ray.Direction * 10000
		direction = (target - origin).Unit
	end

	local bulletCF = CFrame.lookAt(origin, origin + direction)
	local walkMul = self._weaponData.WalkMult * (self._modTable and self._modTable.WalkMult or 1)
	local spreadAngle

	if aiming and self._weaponData.Bullets <= 1 then
		spreadAngle = CFrame.Angles(
			math.rad(Runtime.randomRange(-bSpread - (charspeed / 1) * walkMul, bSpread + (charspeed / 1) * walkMul) / (10 * self._weaponData.AimSpreadReduction)),
			math.rad(Runtime.randomRange(-bSpread - (charspeed / 1) * walkMul, bSpread + (charspeed / 1) * walkMul) / (10 * self._weaponData.AimSpreadReduction)),
			math.rad(Runtime.randomRange(-bSpread - (charspeed / 1) * walkMul, bSpread + (charspeed / 1) * walkMul) / (10 * self._weaponData.AimSpreadReduction))
		)
	else
		spreadAngle = CFrame.Angles(
			math.rad(Runtime.randomRange(-bSpread - (charspeed / 1) * walkMul, bSpread + (charspeed / 1) * walkMul) / 10),
			math.rad(Runtime.randomRange(-bSpread - (charspeed / 1) * walkMul, bSpread + (charspeed / 1) * walkMul) / 10),
			math.rad(Runtime.randomRange(-bSpread - (charspeed / 1) * walkMul, bSpread + (charspeed / 1) * walkMul) / 10)
		)
	end

	direction = spreadAngle * direction

	local tracerVisible = self:tracerCalc()
	if tracerVisible then
		if self._gameRules.ReplicatedBullets then
			Packets.packets.ProjectileIntent.send({
				origin = origin,
				direction = direction,
				muzzleVelocity = self._modTable and self._modTable.MuzzleVelocity or 1,
			})
		end

		local ProjectileVisuals = require(game:GetService("ReplicatedStorage").Shared.Game.Combat.ProjectileRenderer)
		ProjectileVisuals.spawnTracer(origin, direction, {
			parent = self._effectsFolder,
			weaponData = self._weaponData,
			velocityScale = self._modTable and self._modTable.MuzzleVelocity,
		})
	end

	local bulletMass = bullet:GetMass()
	local force = Vector3.new(0, bulletMass * 196.2 - self._weaponData.BulletDrop * 196.2, 0)
	local bf = Instance.new("BodyForce")
	bf.Parent = bullet

	bullet.CFrame = bulletCF
	bullet:ApplyImpulse(direction * self._weaponData.MuzzleVelocity * (self._modTable and self._modTable.MuzzleVelocity or 1))
	bf.Force = force

	self._destroyLater(bullet, 5)
	self:castRay(bullet, origin)
end

function CastController:castRay(bullet: Instance, origin: Vector3)
	local bpos = bullet.Position
	local bpos2 = self._camera.CFrame.Position

	local totalDistTraveled = 0
	local debounce = false

	local raycastParams = RaycastParams.new()
	local ignoreModel = table.clone(self._ignoreModel)
	raycastParams.FilterDescendantsInstances = ignoreModel
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local connection: RBXScriptConnection?
	local function cleanup()
		if connection then
			self._castConnections[connection] = nil
			connection:Disconnect()
			connection = nil
		end
		self._bullets[bullet] = nil
	end

	connection = RunService.Heartbeat:Connect(function()
		if self._destroyed then
			cleanup()
			return
		end
		if not bullet or not bullet.Parent then
			cleanup()
			return
		end

		bpos = bullet.Position
		totalDistTraveled = (bullet.Position - origin).Magnitude

		if totalDistTraveled > MaxDistance then
			bullet:Destroy()
			debounce = true
			cleanup()
			return
		end

		-- Whizz / suppression check
		if not debounce then
			for _, plyr in Players:GetPlayers() do
				if plyr == self._player or not plyr.Character or not plyr.Character:FindFirstChild("Head") then
					continue
				end
				if (plyr.Character.Head.Position - bpos).Magnitude > WHIZZ_DISTANCE then
					continue
				end
				Packets.packets.WhizzIntent.send({ victim = plyr })
				Packets.packets.SuppressionIntent.send({ victim = plyr, mode = 1 })
				debounce = true
				break
			end
		end

		local raycastResult = workspace:Raycast(bpos2, (bpos - bpos2) * 1, raycastParams)
		if not raycastResult then
			bpos2 = bpos
			return
		end

		local hitInstance = raycastResult.Instance
		local hitParent = hitInstance.Parent
-- If the bullet hit a shield, damage the shield instead of the player.
		-- Checked before the IGNORE_NAMES filter because shield parts are named
		-- "Armor" and would otherwise be skipped by the raycast.
		local shieldModel = self:checkForShield(hitInstance)
		if shieldModel and self._weaponData then
			bullet:Destroy()
			debounce = true
			cleanup()
			Packets.packets.ShieldHitIntent.send({ shield = shieldModel })
			return
		end

		-- Skip accessories/hats
		if hitParent and (hitParent:IsA("Accessory") or hitParent:IsA("Hat")) then
			for _, plyr in Players:GetPlayers() do
				if not plyr.Character then
					continue
				end
				for _, accessory in plyr.Character:GetChildren() do
					if accessory:IsA("Accessory") then
						addIgnored(ignoreModel, accessory)
					end
				end
			end
			raycastParams.FilterDescendantsInstances = ignoreModel
			return
		end

		-- Skip armour shell / cosmetic parts
		if hitInstance and IGNORE_NAMES[hitInstance.Name] then
			addIgnored(ignoreModel, hitInstance)
			raycastParams.FilterDescendantsInstances = ignoreModel
			return
		end
		if hitParent and IGNORE_NAMES[hitParent.Name] then
			addIgnored(ignoreModel, hitParent)
			raycastParams.FilterDescendantsInstances = ignoreModel
			return
		end

		-- Skip invisible / non-collidable parts (except body parts)
		if hitInstance
			and (hitInstance.Transparency >= 1 or hitInstance.CanCollide == false)
			and not IGNORE_NAMES[hitInstance.Name]
			and hitInstance.Name ~= "Head"
			and hitInstance.Name ~= "Right Arm" and hitInstance.Name ~= "Left Arm"
			and hitInstance.Name ~= "Right Leg" and hitInstance.Name ~= "Left Leg"
			and hitInstance.Name ~= "UpperTorso" and hitInstance.Name ~= "LowerTorso"
			and hitInstance.Name ~= "RightUpperArm" and hitInstance.Name ~= "RightLowerArm" and hitInstance.Name ~= "RightHand"
			and hitInstance.Name ~= "LeftUpperArm" and hitInstance.Name ~= "LeftLowerArm" and hitInstance.Name ~= "LeftHand"
			and hitInstance.Name ~= "RightUpperLeg" and hitInstance.Name ~= "RightLowerLeg" and hitInstance.Name ~= "RightFoot"
			and hitInstance.Name ~= "LeftUpperLeg" and hitInstance.Name ~= "LeftLowerLeg" and hitInstance.Name ~= "LeftFoot"
		then
			addIgnored(ignoreModel, hitInstance)
			raycastParams.FilterDescendantsInstances = ignoreModel
			return
		end

		-- Hit!
		bullet:Destroy()
		debounce = true
		cleanup()

		-- Hit resolution (damage / shield) must never be blocked by an error
		-- inside the visual-effect module, so run it defensively.
		local success, errorMessage = xpcall(function()
			HitMod.HitEffect(ignoreModel, raycastResult.Position, raycastResult.Instance, raycastResult.Normal, raycastResult.Material, self._weaponData)
		end, debug.traceback)
		if not success then
			warn("[ACS] Ranged hit effect failed: " .. tostring(errorMessage))
		end
		Packets.packets.HitEffectIntent.send({ position = raycastResult.Position, hitPart = raycastResult.Instance, normal = raycastResult.Normal, material = raycastResult.Material.Name })

		local hitPart = raycastResult.Instance

		local foundHuman, targetHumanoid = self:checkForHumanoid(raycastResult.Instance)

		if foundHuman and targetHumanoid and targetHumanoid.Health > 0 and self._weaponData then
			local limbType = HitResolver.getLimbType(hitPart)
			if limbType then
				self:submitDamage(targetHumanoid, limbType, hitPart)
			end
		end
	end)
	if connection then
		self._castConnections[connection] = true
	end
end

function CastController:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	for connection in self._castConnections do
		connection:Disconnect()
	end
	table.clear(self._castConnections)
	for bullet in self._bullets do
		if bullet.Parent then
			bullet:Destroy()
		end
	end
	table.clear(self._bullets)
end

function CastController:meleeCast()
	if not self._weaponData then
		return
	end

	local rayOrigin = self._camera.CFrame.Position
	local rayDirection = self._camera.CFrame.LookVector * self._weaponData.BladeRange

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = self._ignoreModel
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local ignoreModel = table.clone(self._ignoreModel)
	raycastParams.FilterDescendantsInstances = ignoreModel

	local function trace(): RaycastResult?
		for _ = 1, 32 do
			local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
			if not result then
				return nil
			end

			local hit = result.Instance
			local parent = hit.Parent

			-- Skip accessories and continue from the same ray with a bounded
			-- number of ignored candidates.
			if parent and (parent:IsA("Accessory") or parent:IsA("Hat")) then
				for _, plyr in Players:GetPlayers() do
					local character = plyr.Character
					if character then
						for _, accessory in character:GetChildren() do
							if accessory:IsA("Accessory") then
								addIgnored(ignoreModel, accessory)
							end
						end
					end
				end
				raycastParams.FilterDescendantsInstances = ignoreModel
				continue
			end

			-- Skip armour shell / cosmetic parts.
			if IGNORE_NAMES[hit.Name] or (parent and IGNORE_NAMES[parent.Name]) then
				addIgnored(ignoreModel, if IGNORE_NAMES[hit.Name] then hit else parent)
				raycastParams.FilterDescendantsInstances = ignoreModel
				continue
			end

			-- Skip invisible / non-collidable parts except body parts.
			if (hit.Transparency >= 1 or hit.CanCollide == false)
				and not IGNORE_NAMES[hit.Name]
				and hit.Name ~= "Head"
				and hit.Name ~= "Right Arm" and hit.Name ~= "Left Arm"
				and hit.Name ~= "Right Leg" and hit.Name ~= "Left Leg"
				and hit.Name ~= "UpperTorso" and hit.Name ~= "LowerTorso"
				and hit.Name ~= "RightUpperArm" and hit.Name ~= "RightLowerArm" and hit.Name ~= "RightHand"
				and hit.Name ~= "LeftUpperArm" and hit.Name ~= "LeftLowerArm" and hit.Name ~= "LeftHand"
				and hit.Name ~= "RightUpperLeg" and hit.Name ~= "RightLowerLeg" and hit.Name ~= "RightFoot"
				and hit.Name ~= "LeftUpperLeg" and hit.Name ~= "LeftLowerLeg" and hit.Name ~= "LeftFoot"
			then
				addIgnored(ignoreModel, hit)
				raycastParams.FilterDescendantsInstances = ignoreModel
				continue
			end

			return result
		end

		return nil
	end
	local raycastResult = trace()
	if not raycastResult then
		return
	end

	-- Same as the ranged path: a visual-effect error must never block
	-- melee damage or shield hit resolution.
	local success, errorMessage = xpcall(function()
		HitMod.HitEffect(ignoreModel, raycastResult.Position, raycastResult.Instance, raycastResult.Normal, raycastResult.Material, self._weaponData)
	end, debug.traceback)
	if not success then
		warn("[ACS] Melee hit effect failed: " .. tostring(errorMessage))
	end
	Packets.packets.HitEffectIntent.send({ position = raycastResult.Position, hitPart = raycastResult.Instance, normal = raycastResult.Normal, material = raycastResult.Material.Name })

	local hitPart = raycastResult.Instance

	-- If the melee hit a shield, damage the shield instead of the player.
	local shieldModel = self:checkForShield(hitPart)
	if shieldModel and self._weaponData then
		Packets.packets.ShieldHitIntent.send({ shield = shieldModel })
		return
	end

	local foundHuman, targetHumanoid = self:checkForHumanoid(raycastResult.Instance)
	if not foundHuman or targetHumanoid.Health <= 0 then
		return
	end


	local limbType = HitResolver.getLimbType(hitPart) or 3
	self:submitDamage(targetHumanoid, limbType, hitPart)
end

return CastController

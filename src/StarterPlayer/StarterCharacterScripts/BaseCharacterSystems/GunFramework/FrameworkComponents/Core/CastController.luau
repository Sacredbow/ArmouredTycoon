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
const CollectionService = game:GetService("CollectionService")
const ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Modules

const Runtime = require(script.Parent.Runtime)
const HitMod = require(ReplicatedStorage["ACS_Engine"].Modules:WaitForChild("Hitmarker"))

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

local CastController = {}
CastController.__index = CastController

export type CastController = typeof(setmetatable({} :: {
	_player: Player,
	_camera: Camera,
	_character: Model,
	_effectsFolder: Folder,
	_ignoreModel: { Instance },
	_events: any,
	_userIdToken: string,
	_destroyLater: (Instance, number) -> (),
	_tracers: number,
	_weaponTool: Tool?,
	_weaponData: any,
	_modTable: any,
	_weaponInHand: Model?,
	_gameRules: any,
	_thirdPersonCallback: (() -> boolean)?,
}, CastController))

function CastController.new(
	player: Player,
	camera: Camera,
	character: Model,
	effectsFolder: Folder,
	events: any,
	userIdToken: string,
	gameRules: any,
	destroyLaterFn: (Instance, number) -> ()
): CastController
	return setmetatable({
		_player = player,
		_camera = camera,
		_character = character,
		_effectsFolder = effectsFolder,
		_ignoreModel = { camera, character, effectsFolder },
		_events = events,
		_userIdToken = userIdToken,
		_gameRules = gameRules,
		_destroyLater = destroyLaterFn,
		_tracers = 0,
		_weaponTool = nil,
		_weaponData = nil,
		_modTable = nil,
		_weaponInHand = nil,
		_thirdPersonCallback = nil,
	}, CastController)
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
	print(`[CLIENT-Shield] checkForShield called — hitPart name: '{hitPart.Name}', className: {hitPart.ClassName}, parent name: '{hitPart.Parent and hitPart.Parent.Name or "nil"}'`)
	-- Fast path: shield parts are direct children of the Shield model.
	local parent = hitPart.Parent
	if parent and parent:IsA("Model") and parent.Name == "Shield" then
		print(`[CLIENT-Shield] Was it a shield? true — found via direct parent (parent name: '{parent.Name}')`)
		return parent
	end

	-- Fallback: tolerate parts nested deeper inside a Shield model
	-- (matches the Hitmarker module's own FindFirstAncestor check).
	local ancestor = hitPart:FindFirstAncestor("Shield")
	if ancestor and ancestor:IsA("Model") then
		print(`[CLIENT-Shield] Was it a shield? true — found via ancestor search (ancestor name: '{ancestor.Name}')`)
		return ancestor
	end

	print(`[CLIENT-Shield] Was it a shield? false — no Shield model found in hierarchy`)
	return nil
end

function CastController:checkForHumanoid(hitPart: Instance): (boolean, Humanoid?)
	if hitPart:IsA("Humanoid") then
		return true, hitPart
	end

	local parent = hitPart.Parent
	if parent and parent:IsA("Model") then
		local humanoid = parent:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return true, humanoid
		end
	end

	return false, nil
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
	aimming: boolean,
	firstPerson: boolean
)
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

	if aimming and self._weaponData.Bullets <= 1 then
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
			self._events.ServerBullet:FireServer(origin, direction, self._weaponData, self._modTable)
		end

		local ProjectileVisuals = require(game:GetService("ReplicatedStorage").Modules.ProjectileVisuals)
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
	raycastParams.FilterDescendantsInstances = self._ignoreModel
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.IgnoreWater = true

	local connection: RBXScriptConnection?
	local function cleanup()
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end

	connection = RunService.Heartbeat:Connect(function()
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
			for _, plyr in pairs(game.Players:GetPlayers()) do
				if plyr == self._player or not plyr.Character or not plyr.Character:FindFirstChild("Head") then
					continue
				end
				if (plyr.Character.Head.Position - bpos).Magnitude > WHIZZ_DISTANCE then
					continue
				end
				self._events.Whizz:FireServer(plyr)
				self._events.Suppression:FireServer(plyr, 1, nil, nil)
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
		local hitParent = hitInstance and hitInstance.Parent

		print(`[CLIENT-Shield] RAYCAST HIT — instance: '{hitInstance.Name}' (class: {hitInstance.ClassName}), parent: '{hitParent and hitParent.Name or "nil"}' (class: {hitParent and hitParent.ClassName or "nil"})`)

		-- If the bullet hit a shield, damage the shield instead of the player.
		-- Checked before the IGNORE_NAMES filter because shield parts are named
		-- "Armor" and would otherwise be skipped by the raycast.
		local shieldModel = self:checkForShield(hitInstance)
		if shieldModel and self._weaponData then
			print(`[CLIENT-Shield] RANGED shield hit detected! Shield model: '{shieldModel.Name}', firing ShieldHit to server with damage: {self._weaponData.Damage or 0}`)
			bullet:Destroy()
			debounce = true
			cleanup()
			self._events.ShieldHit:FireServer(self._weaponData, shieldModel)
			return
		end

		-- Skip accessories/hats
		if hitParent and (hitParent:IsA("Accessory") or hitParent:IsA("Hat")) then
			for _, plyr in pairs(game.Players:GetPlayers()) do
				if not plyr.Character then
					continue
				end
				for _, accessory in plyr.Character:GetChildren() do
					if accessory:IsA("Accessory") then
						table.insert(self._ignoreModel, accessory)
					end
				end
			end
			raycastParams.FilterDescendantsInstances = self._ignoreModel
			return
		end

		-- Skip armour shell / cosmetic parts
		if hitInstance and IGNORE_NAMES[hitInstance.Name] then
			table.insert(self._ignoreModel, hitInstance)
			raycastParams.FilterDescendantsInstances = self._ignoreModel
			return
		end
		if hitParent and IGNORE_NAMES[hitParent.Name] then
			table.insert(self._ignoreModel, hitParent)
			raycastParams.FilterDescendantsInstances = self._ignoreModel
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
			table.insert(self._ignoreModel, hitInstance)
			raycastParams.FilterDescendantsInstances = self._ignoreModel
			return
		end

		-- Hit!
		print(`[CLIENT-Shield] NOT a shield — bullet hit a normal target. Instance: '{raycastResult.Instance.Name}' (class: {raycastResult.Instance.ClassName}), proceeding to humanoid damage check`)
		bullet:Destroy()
		debounce = true
		cleanup()

		-- Hit resolution (damage / shield) must never be blocked by an error
		-- inside the visual-effect module, so run it defensively.
		pcall(function()
			HitMod.HitEffect(self._ignoreModel, raycastResult.Position, raycastResult.Instance, raycastResult.Normal, raycastResult.Material, self._weaponData)
		end)
		self._events.HitEffect:FireServer(raycastResult.Position, raycastResult.Instance, raycastResult.Normal, raycastResult.Material, self._weaponData)

		local hitPart = raycastResult.Instance
		local hitDist = (raycastResult.Position - origin).Magnitude

		local foundHuman, targetHumanoid = self:checkForHumanoid(raycastResult.Instance)

		if foundHuman and targetHumanoid and targetHumanoid.Health > 0 and self._weaponData then
			print(`[CLIENT-Shield] NOT a shield — humanoid hit! target part: '{hitPart.Name}', humanoid health: {targetHumanoid.Health}, sending normal damage to server`)
			local authToken = self._userIdToken .. "-" .. self._player.UserId

			if hitPart.Name == "Head" or hitPart.Parent.Name == "Top" or hitPart.Parent.Name == "Headset"
				or hitPart.Parent.Name == "Olho" or hitPart.Parent.Name == "Face" or hitPart.Parent.Name == "Numero" then
				self._events.Damage:InvokeServer(self._weaponTool, targetHumanoid, hitDist, 1, self._weaponData, self._modTable, nil, nil, authToken)
			elseif hitPart.Name == "Torso" or hitPart.Name == "UpperTorso" or hitPart.Name == "LowerTorso"
				or hitPart.Parent.Name == "Chest" or hitPart.Parent.Name == "Waist"
				or hitPart.Name == "Right Arm" or hitPart.Name == "Left Arm"
				or hitPart.Name == "RightUpperArm" or hitPart.Name == "RightLowerArm" or hitPart.Name == "RightHand"
				or hitPart.Name == "LeftUpperArm" or hitPart.Name == "LeftLowerArm" or hitPart.Name == "LeftHand" then
				self._events.Damage:InvokeServer(self._weaponTool, targetHumanoid, hitDist, 2, self._weaponData, self._modTable, nil, nil, authToken)
			elseif hitPart.Name == "Right Leg" or hitPart.Name == "Left Leg"
				or hitPart.Name == "RightUpperLeg" or hitPart.Name == "RightLowerLeg" or hitPart.Name == "RightFoot"
				or hitPart.Name == "LeftUpperLeg" or hitPart.Name == "LeftLowerLeg" or hitPart.Name == "LeftFoot" then
				self._events.Damage:InvokeServer(self._weaponTool, targetHumanoid, hitDist, 3, self._weaponData, self._modTable, nil, nil, authToken)
			end
		end
	end)
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

	local function trace()
		local result = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
		if not result then
			return nil
		end

		local hit = result.Instance
		local parent = hit and hit.Parent

		-- Skip accessories
		if parent and (parent:IsA("Accessory") or parent:IsA("Hat")) then
			for _, plyr in pairs(game.Players:GetPlayers()) do
				if not plyr.Character then
					continue
				end
				for _, acc in plyr.Character:GetChildren() do
					if acc:IsA("Accessory") then
						table.insert(self._ignoreModel, acc)
					end
				end
			end
			raycastParams.FilterDescendantsInstances = self._ignoreModel
			return trace()
		end

		-- Skip armour shell
		if hit and (IGNORE_NAMES[hit.Name] or (parent and IGNORE_NAMES[parent.Name])) then
			if IGNORE_NAMES[hit.Name] then
				table.insert(self._ignoreModel, hit)
			else
				table.insert(self._ignoreModel, parent)
			end
			raycastParams.FilterDescendantsInstances = self._ignoreModel
			return trace()
		end

		-- Skip invisible / non-collidable
		if hit and (hit.Transparency >= 1 or hit.CanCollide == false) and not IGNORE_NAMES[hit.Name]
			and hit.Name ~= "Head" and hit.Name ~= "Right Arm" and hit.Name ~= "Left Arm"
			and hit.Name ~= "Right Leg" and hit.Name ~= "Left Leg"
			and hit.Name ~= "UpperTorso" and hit.Name ~= "LowerTorso"
			and hit.Name ~= "RightUpperArm" and hit.Name ~= "RightLowerArm" and hit.Name ~= "RightHand"
			and hit.Name ~= "LeftUpperArm" and hit.Name ~= "LeftLowerArm" and hit.Name ~= "LeftHand"
			and hit.Name ~= "RightUpperLeg" and hit.Name ~= "RightLowerLeg" and hit.Name ~= "RightFoot"
			and hit.Name ~= "LeftUpperLeg" and hit.Name ~= "LeftLowerLeg" and hit.Name ~= "LeftFoot"
		then
			table.insert(self._ignoreModel, hit)
			raycastParams.FilterDescendantsInstances = self._ignoreModel
			return trace()
		end

		return result
	end

	local raycastResult = trace()
	if not raycastResult then
		return
	end

	-- Same as the ranged path: a visual-effect error must never block
	-- melee damage or shield hit resolution.
	pcall(function()
		HitMod.HitEffect(self._ignoreModel, raycastResult.Position, raycastResult.Instance, raycastResult.Normal, raycastResult.Material, self._weaponData)
	end)
	self._events.HitEffect:FireServer(raycastResult.Position, raycastResult.Instance, raycastResult.Normal, raycastResult.Material, self._weaponData)

	local hitPart = raycastResult.Instance

	-- If the melee hit a shield, damage the shield instead of the player.
	print(`[CLIENT-Shield] MELEE HIT — hitPart: '{hitPart.Name}' (class: {hitPart.ClassName}), parent: '{hitPart.Parent and hitPart.Parent.Name or "nil"}'`)
	local shieldModel = self:checkForShield(hitPart)
	if shieldModel and self._weaponData then
		print(`[CLIENT-Shield] MELEE shield hit detected! Shield model: '{shieldModel.Name}', firing ShieldHit to server with damage: {self._weaponData.Damage or 0}`)
		local authToken = self._userIdToken .. "-" .. self._player.UserId
		self._events.ShieldHit:FireServer(self._weaponData, shieldModel)
		return
	end
	print(`[CLIENT-Shield] Was it a shield? false — proceeding to normal melee damage`)

	local foundHuman, targetHumanoid = self:checkForHumanoid(raycastResult.Instance)
	if not foundHuman or targetHumanoid.Health <= 0 then
		print(`[CLIENT-Shield] MELEE — no valid humanoid found (foundHuman: {foundHuman}), melee damage cancelled`)
		return
	end
	print(`[CLIENT-Shield] MELEE — humanoid hit! target part: '{hitPart.Name}', humanoid health: {targetHumanoid.Health}, sending normal melee damage to server`)

	local authToken = self._userIdToken .. "-" .. self._player.UserId

	if hitPart.Name == "Head" or hitPart.Parent.Name == "Top" or hitPart.Parent.Name == "Headset"
		or hitPart.Parent.Name == "Olho" or hitPart.Parent.Name == "Face" or hitPart.Parent.Name == "Numero" then
		task.spawn(function()
			self._events.Damage:InvokeServer(self._weaponTool, targetHumanoid, 0, 1, self._weaponData, self._modTable, nil, nil, authToken)
		end)
	elseif hitPart.Name == "Torso" or hitPart.Name == "UpperTorso" or hitPart.Name == "LowerTorso"
		or hitPart.Parent.Name == "Chest" or hitPart.Parent.Name == "Waist"
		or hitPart.Name == "RightUpperArm" or hitPart.Name == "RightLowerArm" or hitPart.Name == "RightHand"
		or hitPart.Name == "LeftUpperArm" or hitPart.Name == "LeftLowerArm" or hitPart.Name == "LeftHand" then
		task.spawn(function()
			self._events.Damage:InvokeServer(self._weaponTool, targetHumanoid, 0, 2, self._weaponData, self._modTable, nil, nil, authToken)
		end)
	else
		task.spawn(function()
			self._events.Damage:InvokeServer(self._weaponTool, targetHumanoid, 0, 3, self._weaponData, self._modTable, nil, nil, authToken)
		end)
	end
end

return CastController

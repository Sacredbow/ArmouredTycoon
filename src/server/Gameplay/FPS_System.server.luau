

local HttpService = game:GetService("HttpService")
local TS = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RS = game:GetService("ReplicatedStorage")
local plr = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

type WeaponSettings = any
type ModifierSettings = any
type DynamicInstance = any
type ProfileManagerType = any



local ACS_Workspace = workspace:WaitForChild("ACS_WorkSpace") :: DynamicInstance
local Engine = RS:WaitForChild("ACS_Engine") :: DynamicInstance
local Evt = Engine:WaitForChild("Events") :: DynamicInstance
local Mods = Engine:WaitForChild("Modules") :: DynamicInstance
local GunModels = Engine:WaitForChild("GunModels") :: DynamicInstance
local SVGunModels = Engine:WaitForChild("GrenadeModels") :: DynamicInstance
local AttModels = Engine:WaitForChild("AttModels") :: DynamicInstance
local Rules = Engine:WaitForChild("GameRules") :: DynamicInstance

local gameRules = require(Rules:WaitForChild("Config")) :: any
local Ultil = require(Mods:WaitForChild("Utilities")) :: any
local ProfileManager = require(ServerScriptService.DataManager.ProfileManager) :: ProfileManagerType

local ACS_0 = HttpService:GenerateGUID(true)
local tempBannedPlayers: {number} = ((_G.TempBannedPlayers :: any) or {}) :: {number}
_G.TempBannedPlayers = tempBannedPlayers


-----------------------------------------------------------------

game.StarterPlayer.CharacterWalkSpeed = gameRules.NormalWalkSpeed

local function AccessID(SKP_0: Player, SKP_1: number): string
	if SKP_0.UserId ~= SKP_1 then
		SKP_0:Kick("Exploit Protocol")
		warn(SKP_0.Name .. " - Potential Exploiter! Case 0-A: Client Tried To Access Server Code")
		table.insert(tempBannedPlayers, SKP_0.UserId)
	end
	return ACS_0
end;

Evt.AcessId.OnServerInvoke = AccessID


local function compareTables(arr1: WeaponSettings, arr2: WeaponSettings): boolean
	if	arr1.gunName==arr2.gunName 				and 
		arr1.Type==arr2.Type 					and
		arr1.ShootRate==arr2.ShootRate 			and
		arr1.Bullets==arr2.Bullets				and
		arr1.LimbDamage[1]==arr2.LimbDamage[1]	and
		arr1.LimbDamage[2]==arr2.LimbDamage[2]	and
		arr1.TorsoDamage[1]==arr2.TorsoDamage[1]and
		arr1.TorsoDamage[2]==arr2.TorsoDamage[2]and
		arr1.HeadDamage[1]==arr2.HeadDamage[1]	and
		arr1.HeadDamage[2]==arr2.HeadDamage[2]
	then return true; end;
	return false;
end;

local function secureSettings(Player: Player, Gun: Tool?, Module: WeaponSettings): boolean
	if not Gun then
		Player:Kick("Exploit Protocol")
		warn(Player.Name .. " - Potential Exploiter! Case 2: Missing Gun And Module")
		return false
	end

	local PreNewModule = Gun:FindFirstChild("ACS_Settings");
	if not PreNewModule or not PreNewModule:IsA("ModuleScript") then
		Player:Kick("Exploit Protocol");
		warn(Player.Name.." - Potential Exploiter! Case 2: Missing Gun And Module")	;
		return false;
	end;

	local NewModule = require(PreNewModule) :: WeaponSettings;
	if (compareTables(Module, NewModule) == false) then
		Player:Kick("Exploit Protocol");
		warn(Player.Name.." - Potential Exploiter! Case 4: Exploiting Gun Stats")	;
		table.insert(tempBannedPlayers, Player.UserId);
		return false;
	end;
	return true;
end;


local connections: {[Player]: RBXScriptConnection} = {}

local function setupHumanoid(humanoid: Humanoid)
	humanoid.Died:Connect(function()
		local userId = humanoid:GetAttribute("LastDamager")
		if not userId then return end
		local killer = plr:GetPlayerByUserId(userId :: number)
		if not killer then
			return
		end
		ProfileManager.AddCash(killer, 50)
		ProfileManager.AddKills(killer, 1)
	end)
end

local function onCharacterAdded(character: Model)
	local humanoid = character:WaitForChild("Humanoid")
	if not humanoid:IsA("Humanoid") then
		return
	end
	setupHumanoid(humanoid)
end

local function onPlayerAdded(player: Player)
	connections[player] = player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	if connections[player] then
		connections[player]:Disconnect()
		connections[player] = nil
	end
end

function CalculateDMG(attacker: Player, targetHumanoid: Humanoid, distance: number, hitType: number, weaponSettings: WeaponSettings, modifiers: ModifierSettings)
	local parentModel = targetHumanoid.Parent
	if not parentModel or not parentModel:IsA("Model") then
		return
	end

	local targetPlayer = plr:GetPlayerFromCharacter(parentModel)
	local damage = 0
	local minDamage = weaponSettings.MinDamage * modifiers.minDamageMod

	if hitType == 1 then
		local baseDamage = math.random(weaponSettings.HeadDamage[1], weaponSettings.HeadDamage[2])
		damage = math.max(minDamage, (baseDamage * modifiers.DamageMod) - (distance / 25) * weaponSettings.DamageFallOf)
	elseif hitType == 2 then
		local baseDamage = math.random(weaponSettings.TorsoDamage[1], weaponSettings.TorsoDamage[2])
		damage = math.max(minDamage, (baseDamage * modifiers.DamageMod) - (distance / 25) * weaponSettings.DamageFallOf)
	else
		local baseDamage = math.random(weaponSettings.LimbDamage[1], weaponSettings.LimbDamage[2])
		damage = math.max(minDamage, (baseDamage * modifiers.DamageMod) - (distance / 25) * weaponSettings.DamageFallOf)
	end

	local targetCharacter: DynamicInstance = parentModel
	if targetCharacter:FindFirstChild("ACS_Client") and not weaponSettings.IgnoreProtection then

		local protection = targetCharacter.ACS_Client.Protecao
		local vestProtection = protection.VestProtect
		local helmetProtection = protection.HelmetProtect

		if hitType == 1 then
			if weaponSettings.BulletPenetration < helmetProtection.Value then
				damage = math.max(0.5, damage * (weaponSettings.BulletPenetration / helmetProtection.Value))
			end
		else
			if weaponSettings.BulletPenetration < vestProtection.Value then
				damage = math.max(0.5, damage * (weaponSettings.BulletPenetration / vestProtection.Value))
			end
		end
	end

	if targetPlayer then
		if targetPlayer.Team ~= attacker.Team or targetPlayer.Neutral then
			local creatorTag = Instance.new("ObjectValue")
			creatorTag.Name = "creator"
			creatorTag.Value = attacker
			creatorTag.Parent = targetHumanoid
			Debris:AddItem(creatorTag, 1)

			targetHumanoid:SetAttribute("LastDamager", attacker.UserId)
			targetHumanoid:TakeDamage(damage)
			return
		end

		if not gameRules.TeamKill then
			return
		end
		local creatorTag = Instance.new("ObjectValue")
		creatorTag.Name = "creator"
		creatorTag.Value = attacker
		creatorTag.Parent = targetHumanoid
		Debris:AddItem(creatorTag, 1)

		targetHumanoid:TakeDamage(damage * gameRules.TeamDmgMult)
		targetHumanoid:SetAttribute("LastDamager", attacker.UserId)
		return
	end

	local creatorTag = Instance.new("ObjectValue")
	creatorTag.Name = "creator"
	creatorTag.Value = attacker
	creatorTag.Parent = targetHumanoid
	Debris:AddItem(creatorTag, 1)

	targetHumanoid:SetAttribute("LastDamager", attacker.UserId)
	targetHumanoid:TakeDamage(damage)
	return
end

local function Damage(player: Player, weapon: Tool?, targetHumanoid: Humanoid?, distance: number, hitType: number, weaponSettings: WeaponSettings, modifiers: ModifierSettings, isSelfDamage: boolean, selfDamageAmount: number, authToken: string)
	local character = player.Character :: any
	if not player or not character then return end
	if not character:FindFirstChild("Humanoid") or character.Humanoid.Health <= 0 then return end
	if authToken == (ACS_0 .. "-" .. player.UserId) then
		if isSelfDamage then
			character.Humanoid:TakeDamage(math.max(selfDamageAmount, 0))
			return
		end

		if weapon then
			local isValidWeapon = secureSettings(player, weapon, weaponSettings)
			if not isValidWeapon or not targetHumanoid then
				return
			end
			CalculateDMG(player, targetHumanoid, distance, hitType, weaponSettings, modifiers)
			return
		end

		player:Kick("Exploit Protocol")
		warn(player.Name .. " - Potential Exploiter! Case 1: Tried To Access Damage Event")
		table.insert(tempBannedPlayers, player.UserId)
		return
	end

	player:Kick("Exploit Protocol")
	warn(player.Name .. " - Potential Exploiter! Case 0-B: Wrong Permission Code")
	table.insert(tempBannedPlayers, player.UserId)
	return
end

Evt.Damage.OnServerInvoke = Damage

Evt.HitEffect.OnServerEvent:Connect(function(Player: Player, Position: Vector3, HitPart: Instance, Normal: Vector3, Material: Enum.Material, Settings: any)
	Evt.HitEffect:FireAllClients(Player, Position, HitPart, Normal, Material, Settings)
end)

Evt.GunStance.OnServerEvent:Connect(function(Player: Player, stance: number, Data: any)
	Evt.GunStance:FireAllClients(Player,stance,Data)
end)

Evt.ServerBullet.OnServerEvent:Connect(function(Player: Player, Origin: Vector3, Direction: Vector3, WeaponData: any, ModTable: any)
	Evt.ServerBullet:FireAllClients(Player,Origin,Direction,WeaponData,ModTable)
end)


Evt.Stance.OnServerEvent:Connect(function(Player: Player, Stance: number, Virar: number)
	local Character = Player.Character :: any
	if not Player or not Character then return; end; --// Player or Character doesn't exist
	if not Character:FindFirstChild("Humanoid") or Character.Humanoid.Health <= 0 then return; end; --// Player is dead

	local ACS_Client= Character:FindFirstChild("ACS_Client")
	if not ACS_Client then return; end;

	local Torso 	= Character:FindFirstChild("Torso")
	local RootPart 	= Character:FindFirstChild("HumanoidRootPart")

	if not Torso or not RootPart then return; end; --// Essential bodyparts doesn't exist in this character

	local RootJoint = RootPart:FindFirstChild("RootJoint")
	local RS 		= Torso:FindFirstChild("Right Shoulder")
	local LS 		= Torso:FindFirstChild("Left Shoulder")
	local RH 		= Torso:FindFirstChild("Right Hip")
	local LH 		= Torso:FindFirstChild("Left Hip")

	if not RootJoint or not RS or not LS or not RH or not LH then return; end; --// Joints doesn't exist

	if Stance == 2 then
		TS:Create(RootJoint, TweenInfo.new(.3), {C1 = CFrame.new(0,1.5,2.45) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(180))} ):Play()
		TS:Create(RH, TweenInfo.new(.3), {C1 = CFrame.new(.5,1,0)* CFrame.Angles(math.rad(-5),math.rad(90),math.rad(0))} ):Play()
		TS:Create(LH, TweenInfo.new(.3), {C1 = CFrame.new(-.5,1,0)* CFrame.Angles(math.rad(-5),math.rad(-90),math.rad(0))} ):Play()
	end
	if Virar == 1 then
		if Stance == 0 then
			TS:Create(RootJoint, TweenInfo.new(.3), {C1 = CFrame.new(-1,-0,0) * CFrame.Angles(math.rad(-90),math.rad(-15),math.rad(-180))} ):Play()
			TS:Create(RH, TweenInfo.new(.3), {C1 = CFrame.new(.5,1,0)* CFrame.Angles(math.rad(0),math.rad(90),math.rad(0))} ):Play()
			TS:Create(LH, TweenInfo.new(.3), {C1 = CFrame.new(-.5,1,0)* CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0))} ):Play()

		elseif Stance == 1 then
			TS:Create(RootJoint, TweenInfo.new(.3), {C1 = CFrame.new(-1,.75,0.25)* CFrame.Angles(math.rad(-80),math.rad(-15),math.rad(-180))} ):Play()
			TS:Create(RH, TweenInfo.new(.3), {C1 = CFrame.new(.5,0,0.4)* CFrame.Angles(math.rad(20),math.rad(90),math.rad(0))} ):Play()
			TS:Create(LH, TweenInfo.new(.3), {C1 = CFrame.new(-.5,0,0.4)* CFrame.Angles(math.rad(20),math.rad(-90),math.rad(0))} ):Play()

		end
	elseif Virar == -1 then
		if Stance == 0 then
			TS:Create(RootJoint, TweenInfo.new(.3), {C1 = CFrame.new(1,0,0) * CFrame.Angles(math.rad(-90),math.rad(15),math.rad(180))} ):Play()
			TS:Create(RH, TweenInfo.new(.3), {C1 = CFrame.new(.5,1,0)* CFrame.Angles(math.rad(0),math.rad(90),math.rad(0))} ):Play()
			TS:Create(LH, TweenInfo.new(.3), {C1 = CFrame.new(-.5,1,0)* CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0))} ):Play()

		elseif Stance == 1 then
			TS:Create(RootJoint, TweenInfo.new(.3), {C1 = CFrame.new(1,.75,0.25)* CFrame.Angles(math.rad(-80),math.rad(15),math.rad(180))} ):Play()
			TS:Create(RH, TweenInfo.new(.3), {C1 = CFrame.new(.5,0,0.4)* CFrame.Angles(math.rad(20),math.rad(90),math.rad(0))} ):Play()
			TS:Create(LH, TweenInfo.new(.3), {C1 = CFrame.new(-.5,0,0.4)* CFrame.Angles(math.rad(20),math.rad(-90),math.rad(0))} ):Play()
		end
	elseif Virar == 0 then
		if Stance == 0 then
			TS:Create(RootJoint, TweenInfo.new(.3), {C1 = CFrame.new(0,0,0)* CFrame.Angles(math.rad(-90),math.rad(0),math.rad(180))} ):Play()
			TS:Create(RH, TweenInfo.new(.3), {C1 = CFrame.new(.5,1,0)* CFrame.Angles(math.rad(0),math.rad(90),math.rad(0))} ):Play()
			TS:Create(LH, TweenInfo.new(.3), {C1 = CFrame.new(-.5,1,0)* CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0))} ):Play()

		elseif Stance == 1 then
			TS:Create(RootJoint, TweenInfo.new(.3), {C1 = CFrame.new(0,1,0.25)* CFrame.Angles(math.rad(-80),math.rad(0),math.rad(180))} ):Play()
			TS:Create(RH, TweenInfo.new(.3), {C1 = CFrame.new(.5,0,0.4)* CFrame.Angles(math.rad(20),math.rad(90),math.rad(0))} ):Play()
			TS:Create(LH, TweenInfo.new(.3), {C1 = CFrame.new(-.5,0,0.4)* CFrame.Angles(math.rad(20),math.rad(-90),math.rad(0))} ):Play()
		end
	end

	-- if ACS_Client:GetAttribute("Surrender") then
	-- 	TS:Create(RS, TweenInfo.new(.3), {C1 = CFrame.new(-.5,0.95,0)* CFrame.Angles(math.rad(-175),math.rad(90),math.rad(0))} ):Play()
	-- 	TS:Create(LS, TweenInfo.new(.3), {C1 = CFrame.new(.5,0.95,0)* CFrame.Angles(math.rad(-175),math.rad(-90),math.rad(0))} ):Play()
	-- elseif Stance == 2 then
	-- 	TS:Create(RS, TweenInfo.new(.3), {C1 = CFrame.new(-.5,0.95,0)* CFrame.Angles(math.rad(-175),math.rad(90),math.rad(0))} ):Play()
	-- 	TS:Create(LS, TweenInfo.new(.3), {C1 = CFrame.new(.5,0.95,0)* CFrame.Angles(math.rad(-175),math.rad(-90),math.rad(0))} ):Play()
	-- else
	-- 	--p1.CFrame:inverse() * p2.CFrame
	-- 	TS:Create(RS, TweenInfo.new(.3), {C1 = CFrame.new(-.5,0.5,0)* CFrame.Angles(math.rad(0),math.rad(90),math.rad(0))} ):Play()
	-- 	TS:Create(LS, TweenInfo.new(.3), {C1 = CFrame.new(.5,0.5,0)* CFrame.Angles(math.rad(0),math.rad(-90),math.rad(0))} ):Play()
	-- end

end)

Evt.Surrender.OnServerEvent:Connect(function(Player: Player, Victim: Player?)
	local Character = Player.Character :: any
	if not Player or not Character then return; end;

	local PClient 	= nil
	if Victim then
		if Victim == Player or not Victim.Character then return; end;

		PClient = Victim.Character:FindFirstChild("ACS_Client")
		if not PClient then return; end;

		if PClient:GetAttribute("Surrender") then
			PClient:SetAttribute("Surrender",false)
		end
	end

	PClient = Character:FindFirstChild("ACS_Client")
	if not PClient then return; end;

	if not PClient:GetAttribute("Surrender") then
		PClient:SetAttribute("Surrender",true)
	end
end)

Evt.Grenade.OnServerEvent:Connect(function(player: Player, grenadeTool: Tool?, weaponSettings: WeaponSettings, spawnCFrame: CFrame, impulseDirection: Vector3, impulsePower: number, authToken: string)
	local character = player.Character :: any
	if not player or not character then return end
	if not character:FindFirstChild("Humanoid") or character.Humanoid.Health <= 0 then return end

	if authToken ~= (ACS_0 .. "-" .. player.UserId) then
		player:Kick("Exploit Protocol")
		warn(player.Name .. " - Potential Exploiter! Case 0-B: Wrong Permission Code")
		table.insert(tempBannedPlayers, player.UserId)
		return
	end

	if not grenadeTool or not weaponSettings then
		player:Kick("Exploit Protocol")
		warn(player.Name .. " - Potential Exploiter! Case 3: Tried To Access Grenade Event")
		return
	end

	local isValidWeapon = secureSettings(player, grenadeTool, weaponSettings)
	if not isValidWeapon or weaponSettings.Type ~= "Grenade" then return end

	if not SVGunModels:FindFirstChild(weaponSettings.gunName) then
		warn("ACS_Server Couldn't Find " .. weaponSettings.gunName .. " In Grenade Model Folder")
		return
	end

	local grenadeModel = (SVGunModels[weaponSettings.gunName] :: DynamicInstance):Clone() :: DynamicInstance
	if not grenadeModel.PrimaryPart then
		return

	end

	for _, characterPart in pairs(character:GetChildren()) do
		if not characterPart:IsA("BasePart") then continue end
		local noCollisionConstraint = Instance.new("NoCollisionConstraint")
		noCollisionConstraint.Parent = grenadeModel
		noCollisionConstraint.Part0 = grenadeModel.PrimaryPart
		noCollisionConstraint.Part1 = characterPart
	end

	local creatorTag = Instance.new("ObjectValue")
	creatorTag.Name = "creator"
	creatorTag.Value = player
	creatorTag.Parent = grenadeModel.PrimaryPart

	grenadeModel.Parent = ACS_Workspace.Server
	grenadeModel.PrimaryPart.CFrame = spawnCFrame
	grenadeModel.PrimaryPart:ApplyImpulse(impulseDirection * impulsePower * grenadeModel.PrimaryPart:GetMass())
	grenadeModel.PrimaryPart:SetNetworkOwner(nil)
	grenadeModel.PrimaryPart.Damage.Disabled = false

	grenadeTool:Destroy()
end)

local function loadAttachment(weapon: DynamicInstance, WeaponData: WeaponSettings)
	if not weapon or not WeaponData or not weapon:FindFirstChild("Nodes") then return; end;
	--load sight Att
	if weapon.Nodes:FindFirstChild("Sight") and WeaponData.SightAtt ~= "" then

		local SightAtt = AttModels[WeaponData.SightAtt]:Clone()
		SightAtt.Parent = weapon
		SightAtt:PivotTo(weapon.Nodes.Sight.CFrame)

		for index, key in pairs(weapon:GetChildren()) do
			if not key:IsA('BasePart') or key.Name ~= "IS" then continue; end;
			key.Transparency = 1
		end

		for index, key in pairs(SightAtt:GetChildren()) do
			if key.Name == "SightMark" or key.Name == "Main" then key:Destroy(); continue; end;
			if not key:IsA('BasePart') then continue; end;
			Ultil.Weld(weapon:WaitForChild("Handle"), key )
			key.Anchored = false
			key.CanCollide = false
		end

	end

	--load Barrel Att
	if weapon.Nodes:FindFirstChild("Barrel") and WeaponData.BarrelAtt ~= "" then

		local BarrelAtt = AttModels[WeaponData.BarrelAtt]:Clone()
		BarrelAtt.Parent = weapon
		BarrelAtt:PivotTo(weapon.Nodes.Barrel.CFrame)

		if BarrelAtt:FindFirstChild("BarrelPos") then
			weapon.Handle.Muzzle.WorldCFrame = BarrelAtt.BarrelPos.CFrame
		end

		for index, key in pairs(BarrelAtt:GetChildren()) do
			if not key:IsA('BasePart') then continue; end;
			Ultil.Weld(weapon:WaitForChild("Handle"), key )
			key.Anchored = false
			key.CanCollide = false
		end
	end

	--load Under Barrel Att
	if weapon.Nodes:FindFirstChild("UnderBarrel") and WeaponData.UnderBarrelAtt ~= "" then

		local UnderBarrelAtt = AttModels[WeaponData.UnderBarrelAtt]:Clone()
		UnderBarrelAtt.Parent = weapon
		UnderBarrelAtt:PivotTo(weapon.Nodes.UnderBarrel.CFrame)


		for index, key in pairs(UnderBarrelAtt:GetChildren()) do
			if not key:IsA('BasePart') then continue; end;
			Ultil.Weld(weapon:WaitForChild("Handle"), key )
			key.Anchored = false
			key.CanCollide = false
		end
	end

	if weapon.Nodes:FindFirstChild("Other") and WeaponData.OtherAtt ~= "" then

		local OtherAtt = AttModels[WeaponData.OtherAtt]:Clone()
		OtherAtt.Parent = weapon
		OtherAtt:PivotTo(weapon.Nodes.Other.CFrame)

		for index, key in pairs(OtherAtt:GetChildren()) do
			if not key:IsA('BasePart') then continue; end;
			Ultil.Weld(weapon:WaitForChild("Handle"), key )
			key.Anchored = false
			key.CanCollide = false

		end
	end
end

Evt.Equip.OnServerEvent:Connect(function(Player: Player, Arma: Tool, Mode: number, Settings: WeaponSettings, Anim: {[string]: CFrame})
	local Character = Player.Character :: any
	if not Player or not Character then return; end;

	local Head 		= Character:FindFirstChild('Head')
	local Torso 	= Character:FindFirstChild('Torso')
	local LeftArm 	= Character:FindFirstChild('Left Arm')
	local RightArm 	= Character:FindFirstChild('Right Arm')

	if not Head or not Torso or not LeftArm or not RightArm then return; end;
	local RS 		= Torso:FindFirstChild("Right Shoulder")
	local LS 		= Torso:FindFirstChild("Left Shoulder")
	if not RS or not LS then return; end;

	--// EQUIP
	if Mode == 1 then
		local GunModel = GunModels:FindFirstChild(Arma.Name)
		if not GunModel then
			warn(Player.Name..": Couldn't load Server-side weapon model")
			return;
		end;

		local ServerGun = GunModel:Clone() :: DynamicInstance
		ServerGun.Name = 'S' .. Arma.Name

		local AnimBase = Instance.new("Part", Character)
		AnimBase.CanCollide = false
		AnimBase.Transparency = 1
		AnimBase.Anchored = false
		AnimBase.Name = "AnimBase"
		AnimBase.Size = Vector3.new(0.1, 0.1, 0.1)

		local AnimBaseW = Instance.new("Motor6D")
		AnimBaseW.Part0 = Head
		AnimBaseW.Part1 = AnimBase
		AnimBaseW.Parent = AnimBase
		AnimBaseW.Name = "AnimBaseW"
		--AnimBaseW.C0 = CFrame.new(0,-1.25,0)

		local ruaw = Instance.new("Motor6D")
		ruaw.Name = "RAW"
		ruaw.Part0 = RightArm
		ruaw.Part1 = AnimBase
		ruaw.Parent = AnimBase
		ruaw.C0 = Anim.SV_RightArmPos
		RS.Enabled = false

		local luaw = Instance.new("Motor6D")
		luaw.Name = "LAW"
		luaw.Part0 = LeftArm
		luaw.Part1 = AnimBase
		luaw.Parent = AnimBase
		luaw.C0 = Anim.SV_LeftArmPos
		LS.Enabled = false

		ServerGun.Parent = Character

		loadAttachment(ServerGun,Settings)

		if ServerGun:FindFirstChild("Nodes") ~= nil then
			ServerGun.Nodes:Destroy()
		end

		for SKP_001, SKP_002 in pairs(ServerGun:GetDescendants()) do
			if SKP_002.Name ~= "SightMark" then continue; end;
			SKP_002:Destroy()
		end

		for SKP_001, SKP_002 in pairs(ServerGun:GetDescendants()) do
			if not SKP_002:IsA('BasePart') or SKP_002.Name == 'Handle' then continue; end;
			Ultil.WeldComplex(ServerGun:WaitForChild("Handle"), SKP_002, SKP_002.Name)
		end

		local SKP_004 = Instance.new('Motor6D')
		SKP_004.Name = 'Handle'
		SKP_004.Parent = ServerGun.Handle
		SKP_004.Part0 = RightArm
		SKP_004.Part1 = ServerGun.Handle
		SKP_004.C1 = Anim.SV_GunPos:Inverse()

		for L_74_forvar1, L_75_forvar2 in pairs(ServerGun:GetDescendants()) do
			if not L_75_forvar2:IsA('BasePart') then continue; end;
			L_75_forvar2.Anchored = false
			L_75_forvar2.CanCollide = false
		end
		return;
	end;

	if Mode == 2 then
		if Arma and Character:FindFirstChild('S' .. Arma.Name) then
			Character['S' .. Arma.Name]:Destroy()
			Character.AnimBase:Destroy()
		end

		RS.Enabled = true
		LS.Enabled = true
	end
	return;
end)



Evt.HeadRot.OnServerEvent:Connect(function(Player: Player, CF: CFrame)
	Evt.HeadRot:FireAllClients(Player, CF)
end)

Evt.Atirar.OnServerEvent:Connect(function(Player: Player, Arma: Tool, Suppressor: boolean, FlashHider: boolean)
	Evt.Atirar:FireAllClients(Player, Arma, Suppressor, FlashHider)
end)

Evt.Whizz.OnServerEvent:Connect(function(Player: Player, Victim: Player)
	Evt.Whizz:FireClient(Victim)
end)

Evt.Suppression.OnServerEvent:Connect(function(Player: Player, Victim: Player, Mode: number, Intensity: number, Time: number)
	Evt.Suppression:FireClient(Victim,Mode,Intensity,Time)
end)

Evt.Refil.OnServerEvent:Connect(function(Player: Player, Stored: NumberValue, NewStored: number)
	Stored.Value = Stored.Value - NewStored
end)

Evt.SVLaser.OnServerEvent:Connect(function(Player: Player, Position: Vector3, Modo: any, Cor: Color3, IRmode: any, Arma: Tool)
	Evt.SVLaser:FireAllClients(Player,Position,Modo,Cor,IRmode,Arma)
end)

Evt.SVFlash.OnServerEvent:Connect(function(Player: Player, Arma: Tool, Mode: any)
	Evt.SVFlash:FireAllClients(Player,Arma,Mode)
end)


local function RefillAllMags(Player: Player, Weapon: Tool?)
	if not Player or not (Player.Character :: any) then return end
	if not Weapon or not Weapon:FindFirstChild("ACS_Client") then return end

	local ACS_Client = Weapon:FindFirstChild("ACS_Client")
	if not ACS_Client then return end

	-- Refills all magazines
	if ACS_Client:FindFirstChild("Stored") and ACS_Client:FindFirstChild("TotalMags") then
		local totalMags = ACS_Client.TotalMags.Value
		ACS_Client.Stored.Value = totalMags
	end
end

-- Server event for refilling weapon mags
Evt.RefillMag.OnServerEvent:Connect(function(Player: Player, Weapon: Tool?)
	RefillAllMags(Player, Weapon)
end)










plr.PlayerAdded:Connect(function(player: Player)
	onPlayerAdded(player)

	for i, v in ipairs(tempBannedPlayers) do
		if v == player.UserId then
			player:Kick('Blacklisted')
			warn(player.Name.." (Temporary Banned) tried to join to server")
			break
		end
	end

	for i,v in ipairs(gameRules.Blacklist) do
		if v == player.UserId then
			player:Kick('Blacklisted')
			warn(player.Name.." (Blacklisted) tried to join to server")
			break
		end
	end





end)


for _, player in ipairs(plr:GetPlayers()) do
	onPlayerAdded(player)
end

plr.PlayerRemoving:Connect(onPlayerRemoving)

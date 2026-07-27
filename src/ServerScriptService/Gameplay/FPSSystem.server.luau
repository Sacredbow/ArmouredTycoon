

local HttpService = game:GetService("HttpService")
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
local ECS = require(RS.ECS)
local Packets = require(RS.Network.Packets)
local Diagnostics = require(ServerScriptService.Utilities.ServerDiagnostics)
local PlayerRuntimeState = require(ServerScriptService.Services.Players.PlayerRuntimeState)
local DamageRuntimeState = require(ServerScriptService.Services.Combat.DamageRuntimeState)

local ACS_0 = HttpService:GenerateGUID(true)
local tempBannedPlayers: {number} = ((_G.TempBannedPlayers :: any) or {}) :: {number}
_G.TempBannedPlayers = tempBannedPlayers


-----------------------------------------------------------------

game.StarterPlayer.CharacterWalkSpeed = gameRules.NormalWalkSpeed

local function AccessID(SKP_0: Player, SKP_1: number): string
	if SKP_0.UserId ~= SKP_1 then
		Diagnostics.reject(SKP_0, "ACS.AccessID", `Requested token for user id {tostring(SKP_1)}`)
		SKP_0:Kick("Exploit Protocol")
		table.insert(tempBannedPlayers, SKP_0.UserId)
		return ""
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
		Diagnostics.reject(Player, "ACS.Damage", "Missing weapon")
		Player:Kick("Exploit Protocol")
		return false
	end

	local character = Player.Character
	local backpack = Player:FindFirstChildOfClass("Backpack")
	local ownsWeapon = (character ~= nil and Gun:IsDescendantOf(character))
		or (backpack ~= nil and Gun:IsDescendantOf(backpack))
	if not ownsWeapon then
		Diagnostics.reject(Player, "ACS.Damage", `Weapon is not owned by the player: {Gun:GetFullName()}`)
		Player:Kick("Exploit Protocol")
		return false
	end

	local PreNewModule = Gun:FindFirstChild("ACS_Settings");
	if not PreNewModule or not PreNewModule:IsA("ModuleScript") then
		Diagnostics.reject(Player, "ACS.Damage", `Weapon {Gun.Name} is missing ACS_Settings`)
		Player:Kick("Exploit Protocol");
		return false;
	end;

	local NewModule = require(PreNewModule) :: WeaponSettings;
	if (compareTables(Module, NewModule) == false) then
		Diagnostics.reject(Player, "ACS.Damage", `Weapon settings do not match server settings for {Gun.Name}`)
		Player:Kick("Exploit Protocol");
		table.insert(tempBannedPlayers, Player.UserId);
		return false;
	end;
	return true;
end;


local connections: {[Player]: RBXScriptConnection} = {}
local weaponRigEntities: {[Player]: number} = {}

local function setupHumanoid(humanoid: Humanoid)
	humanoid.Died:Connect(function()
		local userId = DamageRuntimeState.GetLastDamager(humanoid)
		if not userId then return end
		local killer = plr:GetPlayerByUserId(userId :: number)
		if not killer then
			return
		end
		ProfileManager.AddCash(killer, 50)
		ProfileManager.AddKills(killer, 1)
		ProfileManager.AddExperience(killer, 45)
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

        local weaponRigEntity = weaponRigEntities[player]
        if weaponRigEntity then
                ECS.deleteEntity(weaponRigEntity)
                weaponRigEntities[player] = nil
        end
end

local function setWeaponRigEntity(player: Player, character: Model, weapon: Tool, serverGun: Model, animBase: BasePart)
        local oldEntity = weaponRigEntities[player]
        if oldEntity then
                ECS.deleteEntity(oldEntity)
        end

        weaponRigEntities[player] = ECS.createEntity({
                Name = `{player.Name}:{weapon.Name}:WeaponRig`,
                Model = serverGun,
                Character = character,
                WeaponRig = {
                        player = player,
                        character = character,
                        tool = weapon,
                        model = serverGun,
                        animBase = animBase,
                        equippedAt = os.clock(),
                },
        })

        Packets.packets.WeaponState.sendToAll({
                kind = "Equip",
                weaponName = weapon.Name,
                stance = nil,
                lean = nil,
        })
end

local function clearWeaponRigEntity(player: Player)
        local entity = weaponRigEntities[player]
        if entity then
                ECS.deleteEntity(entity)
                weaponRigEntities[player] = nil
        end

        Packets.packets.WeaponState.sendToAll({
                kind = "Unequip",
                weaponName = nil,
                stance = nil,
                lean = nil,
        })
end

local function setStanceState(player: Player, character: Model, stance: number, lean: number)
        local entity = weaponRigEntities[player]
        if not entity then
                entity = ECS.createEntity({
                        Name = `{player.Name}:StanceState`,
                        Character = character,
                })
                weaponRigEntities[player] = entity
        end

        ECS.set(entity, "StanceState", {
                player = player,
                character = character,
                stance = stance,
                lean = lean,
                updatedAt = os.clock(),
        })

        Packets.packets.WeaponState.sendToAll({
                kind = "Stance",
                weaponName = nil,
                stance = stance,
                lean = lean,
        })
end

local function queueDamage(attacker: Player?, targetHumanoid: Humanoid, amount: number)
        ECS.createEntity({
                Name = "DamageRequest",
                DamageRequest = {
                        attacker = attacker,
                        humanoid = targetHumanoid,
                        amount = amount,
                },
        })
end

local function rollDamageRange(range: {number}?): number
        if type(range) ~= "table" then
                return 0
        end

        local first = tonumber(range[1]) or 0
        local second = tonumber(range[2]) or first
        local low = math.floor(math.min(first, second))
        local high = math.floor(math.max(first, second))

        if high <= low then
                return low
        end

        return math.random(low, high)
end

function CalculateDMG(attacker: Player, targetHumanoid: Humanoid, distance: number, hitType: number, weaponSettings: WeaponSettings, modifiers: ModifierSettings)
	local parentModel = targetHumanoid.Parent
	if not parentModel or not parentModel:IsA("Model") then
		return
	end

	local targetPlayer = plr:GetPlayerFromCharacter(parentModel)
	local damage = 0
	local minDamage = (tonumber(weaponSettings.MinDamage) or 0) * (tonumber(modifiers.minDamageMod) or 1)
	local damageModifier = tonumber(modifiers.DamageMod) or 1
	local damageFalloff = tonumber(weaponSettings.DamageFallOf) or 0
	local damageDistance = math.max(tonumber(distance) or 0, 0)

	if hitType == 1 then
		local baseDamage = rollDamageRange(weaponSettings.HeadDamage)
		damage = math.max(minDamage, (baseDamage * damageModifier) - (damageDistance / 25) * damageFalloff)
	elseif hitType == 2 then
		local baseDamage = rollDamageRange(weaponSettings.TorsoDamage)
		damage = math.max(minDamage, (baseDamage * damageModifier) - (damageDistance / 25) * damageFalloff)
	else
		local baseDamage = rollDamageRange(weaponSettings.LimbDamage)
		damage = math.max(minDamage, (baseDamage * damageModifier) - (damageDistance / 25) * damageFalloff)
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
                        queueDamage(attacker, targetHumanoid, damage)
                        return
                end

                if not gameRules.TeamKill then
                        return
                end
                queueDamage(attacker, targetHumanoid, damage * gameRules.TeamDmgMult)
                return
        end

        queueDamage(attacker, targetHumanoid, damage)
        return
end

local function Damage(player: Player, weapon: Tool?, targetHumanoid: Humanoid?, distance: number, hitType: number, weaponSettings: WeaponSettings, modifiers: ModifierSettings, isSelfDamage: boolean, selfDamageAmount: number, authToken: string)
	local character = player.Character :: any
	if not character then return end
	if not character:FindFirstChild("Humanoid") or character.Humanoid.Health <= 0 then return end
	if typeof(distance) ~= "number" or distance ~= distance or math.abs(distance) == math.huge then
		Diagnostics.reject(player, "ACS.Damage", "Distance was not a finite number")
		return
	end
	if typeof(hitType) ~= "number" or type(weaponSettings) ~= "table" or type(modifiers) ~= "table" then
		Diagnostics.reject(player, "ACS.Damage", "Damage payload had invalid types")
		return
	end
	if authToken == (ACS_0 .. "-" .. player.UserId) then
                if isSelfDamage then
						if typeof(selfDamageAmount) ~= "number" or selfDamageAmount ~= selfDamageAmount then
							Diagnostics.reject(player, "ACS.Damage", "Self damage was not a valid number")
							return
						end
						queueDamage(player, character.Humanoid, math.clamp(selfDamageAmount, 0, 500))
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
		Diagnostics.reject(player, "ACS.Damage", "Damage request did not contain a weapon")
		table.insert(tempBannedPlayers, player.UserId)
		return
	end

	player:Kick("Exploit Protocol")
	Diagnostics.reject(player, "ACS.Damage", "Incorrect authorization token")
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
        setStanceState(Player, Character, Stance, Virar)

end)

Evt.Surrender.OnServerEvent:Connect(function(Player: Player, Victim: Player?)
	local Character = Player.Character :: any
	if not Player or not Character then return; end;

	local PClient 	= nil
	if Victim then
		if Victim == Player or not Victim.Character then return; end;

		PClient = Victim.Character:FindFirstChild("ACS_Client")
		if not PClient then return; end;

		if PlayerRuntimeState.IsSurrendering(Victim) then
			PlayerRuntimeState.SetSurrendering(Victim, false)
		end
	end

	PClient = Character:FindFirstChild("ACS_Client")
	if not PClient then return; end;

	if not PlayerRuntimeState.IsSurrendering(Player) then
		PlayerRuntimeState.SetSurrendering(Player, true)
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
                setWeaponRigEntity(Player, Character, Arma, ServerGun, AnimBase)
                return;
        end;

        if Mode == 2 then
                clearWeaponRigEntity(Player)
                if Arma and Character:FindFirstChild('S' .. Arma.Name) then
                        Character['S' .. Arma.Name]:Destroy()
                        Character.AnimBase:Destroy()
		end

		RS.Enabled = true
		LS.Enabled = true
	end
	return;
end)



Evt.HeadRot.OnServerEvent:Connect(function(Player: Player, CF: CFrame, aimPitch: number?, aiming: boolean?)
	Evt.HeadRot:FireAllClients(Player, CF, aimPitch, aiming)
end)

Evt.Atirar.OnServerEvent:Connect(function(Player: Player, Arma: Tool, Suppressor: boolean, FlashHider: boolean)
	local character = Player.Character
	if not Arma or not Arma:IsA("Tool") or not character or not Arma:IsDescendantOf(character) then
		Diagnostics.reject(Player, "ACS.FireVFX", "Attempted to replicate an unowned weapon")
		return
	end
	Evt.Atirar:FireAllClients(Player, Arma, Suppressor, FlashHider)
end)

Evt.Whizz.OnServerEvent:Connect(function(Player: Player, Victim: Player)
	if not Victim or not Victim:IsA("Player") then
		Diagnostics.reject(Player, "ACS.Whizz", "Victim was not a player")
		return
	end
	Evt.Whizz:FireClient(Victim)
end)

Evt.Suppression.OnServerEvent:Connect(function(Player: Player, Victim: Player, Mode: number, Intensity: number, Time: number)
	if not Victim or not Victim:IsA("Player") then
		Diagnostics.reject(Player, "ACS.Suppression", "Victim was not a player")
		return
	end
	Evt.Suppression:FireClient(Victim,Mode,Intensity,Time)
end)

Evt.Refil.OnServerEvent:Connect(function(Player: Player, Stored: NumberValue, NewStored: number)
	Diagnostics.reject(Player, "ACS.Refill", "Client attempted to mutate server ammunition storage")
end)

Evt.SVLaser.OnServerEvent:Connect(function(Player: Player, Position: Vector3, Modo: any, Cor: Color3, IRmode: any, Arma: Tool)
	Evt.SVLaser:FireAllClients(Player,Position,Modo,Cor,IRmode,Arma)
end)

Evt.SVFlash.OnServerEvent:Connect(function(Player: Player, Arma: Tool, Mode: any)
	Evt.SVFlash:FireAllClients(Player,Arma,Mode)
end)


local function RefillAllMags(Player: Player, Weapon: Tool?)
	local character = Player.Character
	if not character then return end
	if not Weapon or not Weapon:IsA("Tool") or not Weapon:IsDescendantOf(character) then
		Diagnostics.reject(Player, "ACS.RefillMag", "Weapon was missing or not equipped")
		return
	end
	if not Weapon:FindFirstChild("ACS_Client") then
		Diagnostics.reject(Player, "ACS.RefillMag", `Weapon {Weapon.Name} is missing ACS_Client`)
		return
	end

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

--!strict

--[[
	WeaponHudAdapter

	Thin adapter around the SE_GUI.GunHUD frame. The full React weapon HUD is
	paused for now, so this module keeps SE_GUI labels/icons working while Main
	and the weapon logic continue to get modularized.
]]

local TweenService = game:GetService("TweenService")

local WeaponHudAdapter = {}

export type WeaponData = {
	gunName: string?,
	BulletType: string?,
	Jammed: boolean?,
	ShootType: number?,
	EnableZeroing: boolean?,
	CurrentZero: number?,
	MagCount: boolean?,
	Ammo: number?,
	Type: string?,
}

local FIREMODE_NAMES = {
	[1] = "Semi",
	[2] = "Burst",
	[3] = "Auto",
	[4] = "Pump-Action",
	[5] = "Bolt-Action",
}

local OriginalSizes: { [GuiObject]: UDim2 } = setmetatable({}, { __mode = "k" }) :: any

local function getGunHud(statusGui: Instance): Instance?
	-- GunHUD may be missing in UI Labs/story contexts, so all callers go through
	-- a defensive lookup instead of indexing the frame directly.
	local gunHud = statusGui:FindFirstChild("GunHUD")
	if gunHud and gunHud:IsA("GuiObject") then
		return gunHud
	end

	return nil
end

local function findGui(root: Instance, names: { string }): GuiObject?
	for _, name in ipairs(names) do
		local descendant = root:FindFirstChild(name, true)
		if descendant and descendant:IsA("GuiObject") then
			return descendant
		end
	end

	return nil
end

local function countMagazines(storedAmmo: number, ammoPerMagazine: number): number
	if ammoPerMagazine <= 0 or storedAmmo <= 0 then
		return 0
	end

	return math.ceil(storedAmmo / ammoPerMagazine)
end
local function setText(root: Instance, names: { string }, text: string)
	for _, name in ipairs(names) do
		local descendant = root:FindFirstChild(name, true)
		if descendant and (descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox")) then
			descendant.Text = text
		end
	end
end

local function tweenAmmoBar(root: Instance, ammo: number, maxAmmo: number, jammed: boolean?)
	local bar = findGui(root, { "AmmoFill", "AmmoLine", "AmmoTube", "B", "AmmoBar" })
	if not bar then
		return
	end

	local ratio = if maxAmmo > 0 then math.clamp(ammo / maxAmmo, 0, 1) else 0
	local originalSize = OriginalSizes[bar]
	if not originalSize then
		originalSize = bar.Size
		if originalSize.X.Scale <= 0 and originalSize.X.Offset <= 0 then
			local parent = bar.Parent
			if parent and parent:IsA("GuiObject") then
				originalSize = UDim2.new(1, 0, originalSize.Y.Scale, originalSize.Y.Offset)
			end
		end
		OriginalSizes[bar] = originalSize
	end

	local targetSize = UDim2.new(
		originalSize.X.Scale * ratio,
		math.floor(originalSize.X.Offset * ratio + 0.5),
		originalSize.Y.Scale,
		originalSize.Y.Offset
	)
	local targetColor = if jammed then Color3.fromRGB(255, 0, 0) elseif ratio > 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(0, 0, 0)
	local target: { [string]: any } = {
		Size = targetSize,
		BackgroundColor3 = targetColor,
	}

	if bar:IsA("ImageLabel") or bar:IsA("ImageButton") then
		target.ImageColor3 = targetColor
	end

	TweenService:Create(bar, TweenInfo.new(0.14, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), target):Play()
end

function WeaponHudAdapter.setVisible(statusGui: Instance?, visible: boolean)
	-- Main calls this on equip/unequip. Keeping visibility here avoids spreading
	-- SE_GUI frame names through weapon code.
	if not statusGui then
		return
	end

	local gunHud = getGunHud(statusGui)
	if gunHud and gunHud:IsA("GuiObject") then
		gunHud.Visible = visible
	end
end

function WeaponHudAdapter.hideGrenadeForce(statusGui: Instance?)
	if not statusGui then
		return
	end

	local grenadeForce = statusGui:FindFirstChild("GrenadeForce")
	if grenadeForce and grenadeForce:IsA("GuiObject") then
		grenadeForce.Visible = false
	end
end

function WeaponHudAdapter.setGrenadeForceText(statusGui: Instance?, text: string)
	if not statusGui then
		return
	end

	local grenadeForce = statusGui:FindFirstChild("GrenadeForce")
	if grenadeForce and grenadeForce:IsA("TextLabel") then
		grenadeForce.Visible = true
		grenadeForce.Text = text
	end
end

function WeaponHudAdapter.update(
	statusGui: Instance?,
	weaponData: WeaponData?,
	ammo: number?,
	storedAmmo: number?,
	safeMode: boolean,
	suppressor: boolean,
	bipodAttached: boolean,
	sensitivity: number
)
	-- Keep visual update logic in one place. Main only publishes state and calls
	-- this adapter after ammo/safety/attachment changes.
	if not statusGui or not weaponData then
		return
	end

	local hud = getGunHud(statusGui) :: any
	if not hud then
		return
	end

	hud.NText.Text = weaponData.gunName or "Weapon"
	hud.BText.Text = weaponData.BulletType or ""
	hud.A.Visible = safeMode
	hud.Att.Silencer.Visible = suppressor
	hud.Att.Bipod.Visible = bipodAttached
	hud.Sens.Text = tostring(sensitivity / 100)

	local currentAmmo = math.max(ammo or 0, 0)
	local maxAmmo = math.max(weaponData.Ammo or 0, 0)
	hud.B.Visible = true
	hud.FText.Text = FIREMODE_NAMES[weaponData.ShootType or 1] or "Semi"
	setText(hud, { "AText", "AmmoText", "CurrentAmmo", "AmmoCount" }, tostring(currentAmmo))
	tweenAmmoBar(hud, currentAmmo, maxAmmo, weaponData.Jammed)

	if weaponData.EnableZeroing then
		hud.ZeText.Visible = true
		hud.ZeText.Text = `{weaponData.CurrentZero or 0} m`
	else
		hud.ZeText.Visible = false
	end

	if weaponData.MagCount and (weaponData.Ammo or 0) > 0 then
		local magazineCount = countMagazines(storedAmmo or 0, weaponData.Ammo or 0)
		hud.SAText.Text = tostring(magazineCount)
		setText(hud, { "SAText", "ReserveText", "StoredAmmo", "MagCount" }, tostring(magazineCount))
		hud.Magazines.Visible = true
		hud.Bullets.Visible = false
	else
		hud.SAText.Text = tostring(storedAmmo or 0)
		setText(hud, { "SAText", "ReserveText", "StoredAmmo", "MagCount" }, tostring(storedAmmo or 0))
		hud.Magazines.Visible = false
		hud.Bullets.Visible = true
	end

	WeaponHudAdapter.hideGrenadeForce(statusGui)
end

function WeaponHudAdapter.setBipodStatus(statusGui: Instance?, color: Color3, transparency: number)
	if not statusGui then
		return
	end

	local hud = getGunHud(statusGui) :: any
	if not hud then
		return
	end

	TweenService:Create(hud.Att.Bipod, TweenInfo.new(0.1, Enum.EasingStyle.Linear), {
		ImageColor3 = color,
		ImageTransparency = transparency,
	}):Play()
end

return WeaponHudAdapter

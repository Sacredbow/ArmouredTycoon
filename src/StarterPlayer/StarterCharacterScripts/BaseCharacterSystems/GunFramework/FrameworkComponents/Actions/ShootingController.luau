--!strict

--[[
	ShootingController

	Owns weapon trigger sequencing only. It intentionally does not create bullets,
	play animations directly, or mutate Main.luau state by itself. Instead, Main
	passes a small mutable state table plus callbacks. That keeps the old ACS
	behavior intact while making the firing rules easier to test and replace.

	ShootType meanings currently follow ACS conventions:
		1 = semi
		2 = burst
		3 = automatic
		4 = pump/bolt style
		5 = melee

	If we add new weapon categories later, prefer adding a new branch here and
	keeping the actual effects in callbacks/controllers.
]]

local ShootingController = {}

export type WeaponData = {
	Type: string?,
	Jammed: boolean?,
	ShootRate: number,
	ShootType: number,
	BurstShot: number?,
	Bullets: number?,
}

export type State = {
	ammo: number,
	shooting: boolean,
	reloading: boolean,
	runKeyDown: boolean,
	safeMode: boolean,
	checkingMag: boolean,
	mouseDown: boolean,
}

export type Callbacks = {
	setShooting: (boolean) -> (),
	setMouseDown: (boolean) -> (),
	isMouseDown: () -> boolean,
	fireRound: () -> (),
	firePumpRound: () -> (),
	playEmptyClick: () -> (),
	pump: () -> (),
	runCheck: () -> (),
	melee: () -> (),
	schedule: (number, () -> (), string?) -> (),
}

local function positive<T>(value: T?, fallback: number): number
	-- Weapon configs are authored by hand, so clamp bad or missing rates before
	-- they create divide-by-zero timing bugs in burst/auto loops.
	if typeof(value) == "number" and (value :: any) > 0 then
		return value :: any
	end

	return fallback
end

function ShootingController.canFire(weaponData: WeaponData?, state: State): boolean
	-- Shared by burst/auto loops so reload, sprint, safety, jam, and empty ammo
	-- all stop firing consistently even if they change mid-stream.
	return weaponData ~= nil
		and state.ammo > 0
		and weaponData.Jammed ~= true
		and not state.reloading
		and not state.runKeyDown
		and not state.safeMode
		and not state.checkingMag
end

function ShootingController.shoot(weaponData: WeaponData?, state: State, callbacks: Callbacks)
	-- Keep this controller focused on ordering. Every visible/gameplay side effect
	-- still happens through callbacks owned by Main or smaller effect modules.
	if weaponData and weaponData.Type == "Gun" and not state.shooting and not state.reloading then
		if state.reloading or state.runKeyDown or state.safeMode or state.checkingMag then
			callbacks.setMouseDown(false)
			return
		end

		if state.ammo <= 0 or weaponData.Jammed then
			callbacks.playEmptyClick()
			callbacks.setMouseDown(false)
			return
		end

		callbacks.setMouseDown(true)
		local fireInterval = 60 / positive(weaponData.ShootRate, 600)

		local function canFireNext(): boolean
			-- The state table is intentionally shared/mutable. Main updates ammo and
			-- flags inside callbacks, and these loops read the latest values.
			return ShootingController.canFire(weaponData, state)
		end

		local function finishShot()
			callbacks.setShooting(false)
		end

		if weaponData.ShootType == 1 then
			callbacks.setShooting(true)
			callbacks.fireRound()
			callbacks.schedule(fireInterval, finishShot, "ACS:SemiCooldown")
			return
		end

		if weaponData.ShootType == 2 then
			local burstIndex = 0
			local burstShot = positive(weaponData.BurstShot, 1)

			local function fireBurst()
				if burstIndex >= burstShot or not callbacks.isMouseDown() or not canFireNext() then
					callbacks.setShooting(false)
					return
				end

				burstIndex += 1
				callbacks.setShooting(true)
				callbacks.fireRound()

				callbacks.schedule(fireInterval, function()
					callbacks.setShooting(false)
					fireBurst()
				end, "ACS:BurstCooldown")
			end

			fireBurst()
			return
		end

		if weaponData.ShootType == 3 then
			local function fireAutomatic()
				if not callbacks.isMouseDown() or not canFireNext() then
					callbacks.setShooting(false)
					return
				end

				callbacks.setShooting(true)
				callbacks.fireRound()

				callbacks.schedule(fireInterval, function()
					callbacks.setShooting(false)
					fireAutomatic()
				end, "ACS:AutoCooldown")
			end

			fireAutomatic()
			return
		end

		if weaponData.ShootType == 4 or weaponData.ShootType == 5 then
			callbacks.setShooting(true)
			callbacks.firePumpRound()
			callbacks.pump()
			callbacks.runCheck()
			callbacks.setShooting(false)
			return
		end
	end

	if weaponData and weaponData.Type == "Melee" and not state.runKeyDown and not state.shooting then
		callbacks.setShooting(true)
		callbacks.melee()
		callbacks.runCheck()
		callbacks.setShooting(false)
	end
end

return ShootingController

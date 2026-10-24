const Settings = {}

Settings.SlideEx 		= CFrame.new(0,0,0)
Settings.SlideLock 		= false

Settings.canAim 		= false
Settings.Zoom 			= 70
Settings.Zoom2 			= 70

Settings.gunName 		= script.Parent.Name
Settings.Type 			= "Grenade"
Settings.EnableHUD		= false
Settings.IncludeChamberedBullet = false
Settings.Ammo 			= 0
Settings.StoredAmmo 	= 0
Settings.AmmoInGun 		= 0
Settings.MaxStoredAmmo	= 0
Settings.CanCheckMag 	= false
Settings.MagCount		= false
Settings.ShellInsert	= false
Settings.ShootRate 		= 0
Settings.Bullets 		= 0
Settings.BurstShot 		= 0
Settings.ShootType 		= 0				--[1 = SEMI; 2 = BURST; 3 = AUTO; 4 = PUMP ACTION; 5 = BOLT ACTION]
Settings.FireModes = {
	ChangeFiremode = false;		
	Semi = false;
	Burst = false;
	Auto = false;}

Settings.LimbDamage 	= {0,0}
Settings.TorsoDamage 	= {0,0} 
Settings.HeadDamage 	= {0,0} 
Settings.DamageFallOf 	= 0
Settings.MinDamage 		= 0
Settings.IgnoreProtection  = false
Settings.BulletPenetration = 0

Settings.adsTime 		= 1

Settings.CrossHair 		= false
Settings.CenterDot 		= true
Settings.CrosshairOffset= 0
Settings.CanBreachDoor 	= false

Settings.SightAtt 		= ""
Settings.BarrelAtt		= ""
Settings.UnderBarrelAtt = ""
Settings.OtherAtt 		= ""

Settings.camRecoil = {
	camRecoilUp 	= {0,0}
	,camRecoilTilt 	= {0,0}
	,camRecoilLeft 	= {0,0}
	,camRecoilRight = {0,0}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {0,0}
	,gunRecoilTilt 	= {0,0}
	,gunRecoilLeft 	= {0,0}
	,gunRecoilRight = {0,0}
}

Settings.AimRecoilReduction 		= 1
Settings.AimSpreadReduction 		= 1

Settings.MinRecoilPower 			= 1
Settings.MaxRecoilPower 			= 1
Settings.RecoilPowerStepAmount 		= 1

Settings.MinSpread 					= 0
Settings.MaxSpread 					= 0					
Settings.AimInaccuracyStepAmount 	= 0
Settings.AimInaccuracyDecrease 		= 0
Settings.WalkMult 					= 0

Settings.EnableZeroing 				= false
Settings.MaxZero 					= 0
Settings.ZeroIncrement 				= 0
Settings.CurrentZero 				= 0

Settings.BulletType 				= ""
Settings.MuzzleVelocity 			= 0 --m/s
Settings.BulletDrop 				= 0 --Between 0 - 1
Settings.Tracer						= false
Settings.BulletFlare 				= false
Settings.TracerColor				= Color3.fromRGB(255,255,255)
Settings.RandomTracer				= {
	Enabled = false
	,Chance = 25 -- 0-100%
}
Settings.TracerEveryXShots			= 0
Settings.RainbowMode 				= false
Settings.InfraRed 					= false

Settings.CanBreak	= false
Settings.Jammed		= false

return Settings
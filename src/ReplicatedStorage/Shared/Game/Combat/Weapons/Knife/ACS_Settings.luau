const Settings = {}

Settings.SlideEx 		= CFrame.new(0,0,0)
Settings.SlideLock 		= false

Settings.canAim 		= false
Settings.Zoom 			= 70
Settings.Zoom2 			= 70

Settings.gunName 		= script.Parent.Name
Settings.Type 			= "Melee"
Settings.EnableHUD		= false
Settings.BladeRange 	= 7
Settings.IncludeChamberedBullet = false
Settings.Ammo 			= 0
Settings.StoredAmmo 	= 0
Settings.AmmoInGun 		= Settings.Ammo
Settings.MaxStoredAmmo	= 0
Settings.CanCheckMag 	= false
Settings.MagCount		= false
Settings.ShellInsert	= false
Settings.ShootRate 		= 0
Settings.Bullets 		= 0
Settings.ShootType 		= 1				--[1 = SEMI; 2 = BURST; 3 = AUTO; 4 = PUMP ACTION; 5 = BOLT ACTION]
Settings.FireModes = {
	ChangeFiremode = false;		
	Semi = false;
	Burst = false;
	Auto = false;}

Settings.LimbDamage 	= {55,45}
Settings.TorsoDamage 	= {55,56} 
Settings.HeadDamage 	= {95,95} 
Settings.DamageFallOf 	= 0
Settings.MinDamage 		= 0
Settings.IgnoreProtection = true
Settings.BulletPenetration = 0

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

Settings.MinRecoilPower 			= 0
Settings.MaxRecoilPower 			= 0
Settings.RecoilPowerStepAmount 		= 0

Settings.MinSpread 					= 0
Settings.MaxSpread 					= 0					
Settings.AimInaccuracyStepAmount 	= 0
Settings.AimInaccuracyDecrease 		= 0
Settings.WalkMult 					= 0

Settings.EnableZeroing 				= false
Settings.MaxZero 					= 500
Settings.ZeroIncrement 				= 50
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
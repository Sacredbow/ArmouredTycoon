const Settings = {}

Settings.SlideEx 		= CFrame.new(0,0,-0.3)
Settings.SlideLock 		= true

Settings.canAim 		= true
Settings.Zoom 			= 70
Settings.Zoom2 			= 70

Settings.gunName 		= script.Parent.Name
Settings.Type 			= "Gun"
Settings.EnableHUD		= true
Settings.IncludeChamberedBullet = true
Settings.Ammo 			= 20
Settings.StoredAmmo 	= 120
Settings.AmmoInGun 		= Settings.Ammo
Settings.MaxStoredAmmo	= 120
Settings.CanCheckMag 	= true
Settings.MagCount		= true
Settings.ShellInsert	= false
Settings.ShootRate 		= 400
Settings.Bullets 		= 1
Settings.BurstShot 		= 3
Settings.ShootType 		= 1				--[1 = SEMI; 2 = BURST; 3 = AUTO; 4 = PUMP ACTION; 5 = BOLT ACTION]
Settings.FireModes = {
	ChangeFiremode = false;		
	Semi = false;
	Burst = false;
	Auto = false;}

Settings.LimbDamage 	= {39,40}
Settings.TorsoDamage 	= {39,41} 
Settings.HeadDamage 	= {43,48} 
Settings.DamageFallOf 	= 2
Settings.MinDamage 		= 15
Settings.IgnoreProtection = false
Settings.BulletPenetration = 40

Settings.CrossHair 		= true
Settings.CenterDot 		= false
Settings.CrosshairOffset= 0
Settings.CanBreachDoor 	= false

Settings.SightAtt 		= ""
Settings.BarrelAtt		= ""
Settings.UnderBarrelAtt = ""
Settings.OtherAtt 		= ""

Settings.camRecoil = {
	camRecoilUp 	= {0,0}
	,camRecoilTilt 	= {0,0}
	,camRecoilLeft 	= {5,8}
	,camRecoilRight = {5,8}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {100,105}
	,gunRecoilTilt 	= {25,40}
	,gunRecoilLeft 	= {10,15}
	,gunRecoilRight = {10,15}
}

Settings.AimRecoilReduction 		= 1
Settings.AimSpreadReduction 		= 1

Settings.MinRecoilPower 			= 1
Settings.MaxRecoilPower 			= 1.5
Settings.RecoilPowerStepAmount 		= .1

Settings.MinSpread 					= 10
Settings.MaxSpread 					= 50					
Settings.AimInaccuracyStepAmount 	= 5.75
Settings.AimInaccuracyDecrease 		= 1
Settings.WalkMult 					= 0

Settings.EnableZeroing 				= false
Settings.MaxZero 					= 500
Settings.ZeroIncrement 				= 50
Settings.CurrentZero 				= 0

Settings.BulletType 				= "9x19mm"
Settings.MuzzleVelocity 			= 1000 --m/s
Settings.BulletDrop 				= .05 --Between 0 - 1
Settings.Tracer						= true
Settings.BulletFlare 				= true
Settings.TracerColor				= Color3.fromRGB(0,128,0)
Settings.RandomTracer				= {
	Enabled = false
	,Chance = 25 -- 0-100%
}
Settings.TracerEveryXShots			= 3
Settings.RainbowMode 				= false
Settings.InfraRed 					= false

Settings.CanBreak	= false
Settings.Jammed		= false

return Settings
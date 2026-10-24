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
Settings.Ammo 			= 12
Settings.StoredAmmo 	= 60
Settings.AmmoInGun 		= Settings.Ammo
Settings.MaxStoredAmmo	= 84
Settings.CanCheckMag 	= true
Settings.MagCount		= true
Settings.ShellInsert	= false
Settings.ShootRate 		= 700
Settings.Bullets 		= 1
Settings.BurstShot 		= 3
Settings.ShootType 		= 1				--[1 = SEMI; 2 = BURST; 3 = AUTO; 4 = PUMP ACTION; 5 = BOLT ACTION]
Settings.FireModes = {
	ChangeFiremode = false;		
	Semi = false;
	Burst = false;
	Auto = false;}

Settings.LimbDamage 	= {22,26}
Settings.TorsoDamage 	= {34,38} 
Settings.HeadDamage 	= {120,120} 
Settings.DamageFallOf 	= 2
Settings.MinDamage 		= 5
Settings.IgnoreProtection = false
Settings.BulletPenetration = 50.5

Settings.CrossHair 		= false
Settings.CenterDot 		= false
Settings.CrosshairOffset= 0
Settings.CanBreachDoor 	= false

Settings.SightAtt 		= ""
Settings.BarrelAtt		= ""
Settings.UnderBarrelAtt = ""
Settings.OtherAtt 		= ""

Settings.camRecoil = {
	camRecoilUp 	= {5,8}
	,camRecoilTilt 	= {10,15}
	,camRecoilLeft 	= {5,8}
	,camRecoilRight = {5,8}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {150,150}
	,gunRecoilTilt 	= {25,50}
	,gunRecoilLeft 	= {10,20}
	,gunRecoilRight = {10,20}
}

Settings.AimRecoilReduction 		= 1
Settings.AimSpreadReduction 		= 1

Settings.MinRecoilPower 			= 1
Settings.MaxRecoilPower 			= 1.5
Settings.RecoilPowerStepAmount 		= .1

Settings.MinSpread 					= 5
Settings.MaxSpread 					= 50					
Settings.AimInaccuracyStepAmount 	= 5.75
Settings.AimInaccuracyDecrease 		= 1
Settings.WalkMult 					= 0

Settings.EnableZeroing 				= false
Settings.MaxZero 					= 500
Settings.ZeroIncrement 				= 50
Settings.CurrentZero 				= 0

Settings.BulletType 				= ".45 ACP"
Settings.MuzzleVelocity 			= 1000 --m/s
Settings.BulletDrop 				= .25 --Between 0 - 1
Settings.Tracer						= false
Settings.BulletFlare 				= false
Settings.TracerColor				= Color3.fromRGB(255,255,255)
Settings.RandomTracer				= {
	Enabled = false
	,Chance = 25 -- 0-100%
}
Settings.TracerEveryXShots			= 3
Settings.RainbowMode 				= false
Settings.InfraRed 					= false

Settings.CanBreak	= true
Settings.Jammed		= false

return Settings
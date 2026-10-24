const Settings = {}

Settings.SlideEx 		= CFrame.new(0,0,-0.2)
Settings.SlideLock 		= false

Settings.canAim 		= true
Settings.Zoom 			= 60
Settings.Zoom2 			= 60

Settings.gunName 		= script.Parent.Name
Settings.Type 			= "Gun"
Settings.EnableHUD		= true
Settings.IncludeChamberedBullet = true
Settings.Ammo 			= 10
Settings.StoredAmmo 	= 30
Settings.AmmoInGun 		= Settings.Ammo
Settings.MaxStoredAmmo	= 70
Settings.CanCheckMag 	= true
Settings.MagCount		= true
Settings.ShellInsert	= false
Settings.ShootRate 		= 800
Settings.Bullets 		= 1
Settings.BurstShot 		= 3
Settings.ShootType 		= 5				--[1 = SEMI; 2 = BURST; 3 = AUTO; 4 = PUMP ACTION; 5 = BOLT ACTION]
Settings.FireModes = {
	ChangeFiremode = false;		
	Semi = false;
	Burst = false;
	Auto = false;}

Settings.LimbDamage 	= {50,50}
Settings.TorsoDamage 	= {90,90} 
Settings.HeadDamage 	= {125,125} 
Settings.DamageFallOf 	= .5
Settings.MinDamage 		= 5
Settings.IgnoreProtection = false
Settings.BulletPenetration = 75

Settings.adsTime 		= 1

Settings.CrossHair 		= false
Settings.CenterDot 		= false
Settings.CrosshairOffset= 0
Settings.CanBreachDoor 	= true

Settings.SightAtt 		= ""
Settings.BarrelAtt		= ""
Settings.UnderBarrelAtt = ""
Settings.OtherAtt 		= ""

Settings.camRecoil = {
	camRecoilUp 	= {35,45}
	,camRecoilTilt 	= {100,100}
	,camRecoilLeft 	= {40,50}
	,camRecoilRight = {40,50}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {150,175}
	,gunRecoilTilt 	= {25,50}
	,gunRecoilLeft 	= {75,150}
	,gunRecoilRight = {75,150}
}

Settings.AimRecoilReduction 		= 1
Settings.AimSpreadReduction 		= 1

Settings.MinRecoilPower 			= 1
Settings.MaxRecoilPower 			= 1
Settings.RecoilPowerStepAmount 		= 1

Settings.MinSpread 					= 0.25
Settings.MaxSpread 					= 100					
Settings.AimInaccuracyStepAmount 	= 5
Settings.AimInaccuracyDecrease 		= 1.5
Settings.WalkMult 					= 0

Settings.EnableZeroing 				= true
Settings.MaxZero 					= 1000
Settings.ZeroIncrement 				= 50
Settings.CurrentZero 				= 0

Settings.BulletType 				= ".338 Lapua Magnum"
Settings.MuzzleVelocity 			= 2000 --m/s
Settings.BulletDrop 				= .5 --Between 0 - 1
Settings.Tracer						= true
Settings.BulletFlare 				= true
Settings.TracerColor				= Color3.fromRGB(255,255,255)
Settings.RandomTracer				= {
	Enabled = false
	,Chance = 25 -- 0-100%
}
Settings.TracerEveryXShots			= 0
Settings.RainbowMode 				= false
Settings.InfraRed 					= false

Settings.CanBreak	= true
Settings.Jammed		= false

return Settings
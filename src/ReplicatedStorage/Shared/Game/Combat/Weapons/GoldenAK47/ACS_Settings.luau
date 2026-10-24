const Settings = {}

Settings.SlideEx 		= CFrame.new(0,0,-0.4)
Settings.SlideLock 		= true

Settings.canAim 		= true
Settings.Zoom 			= 60
Settings.Zoom2 			= 60

Settings.gunName 		= script.Parent.Name
Settings.Type 			= "Gun"
Settings.EnableHUD		= true
Settings.IncludeChamberedBullet = true
Settings.Ammo 			= 69
Settings.StoredAmmo 	= 690
Settings.AmmoInGun 		= Settings.Ammo
Settings.MaxStoredAmmo	= 210
Settings.CanCheckMag 	= true
Settings.MagCount		= true
Settings.ShellInsert	= false
Settings.ShootRate 		= 800
Settings.Bullets 		= 1
Settings.BurstShot 		= 3
Settings.ShootType 		= 3				--[1 = SEMI; 2 = BURST; 3 = AUTO; 4 = PUMP ACTION; 5 = BOLT ACTION]
Settings.FireModes = {
	ChangeFiremode = false;		
	Semi = false;
	Burst = false;
	Auto = true;}

Settings.LimbDamage 	= {35,35}
Settings.TorsoDamage 	= {35,35} 
Settings.HeadDamage 	= {35,35} 
Settings.DamageFallOf 	= 1
Settings.MinDamage 		= 5
Settings.IgnoreProtection = false
Settings.BulletPenetration = 72

Settings.adsTime 		= 1

Settings.CrossHair 		= true
Settings.CenterDot 		= false
Settings.CrosshairOffset= 10
Settings.CanBreachDoor 	= false

Settings.SightAtt 		= ""
Settings.BarrelAtt		= ""
Settings.UnderBarrelAtt = ""
Settings.OtherAtt 		= ""

Settings.camRecoil = {
	camRecoilUp 	= {3,3}
	,camRecoilTilt 	= {5,5}
	,camRecoilLeft 	= {5,5}
	,camRecoilRight = {5,5}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {5,5}
	,gunRecoilTilt 	= {5,5}
	,gunRecoilLeft 	= {5,5}
	,gunRecoilRight = {5,5}
}

Settings.AimRecoilReduction 		= 4
Settings.AimSpreadReduction 		= 1

Settings.MinRecoilPower 			= .5
Settings.MaxRecoilPower 			= 1.5
Settings.RecoilPowerStepAmount 		= .1

Settings.MinSpread 					= 0.75
Settings.MaxSpread 					= 100					
Settings.AimInaccuracyStepAmount 	= 0.75
Settings.AimInaccuracyDecrease 		= .25
Settings.WalkMult 					= 0

Settings.EnableZeroing 				= true
Settings.MaxZero 					= 500
Settings.ZeroIncrement 				= 50
Settings.CurrentZero 				= 0

Settings.BulletType 				= "le gold bullet"
Settings.MuzzleVelocity 			= 1500 --m/s
Settings.BulletDrop 				= .05 --Between 0 - 1
Settings.Tracer						= true
Settings.BulletFlare 				= true
Settings.TracerColor				= Color3.fromRGB(255, 255, 0)
Settings.RandomTracer				= {
	Enabled = true
	,Chance = 100 -- 0-100%
}
Settings.TracerEveryXShots			= 3
Settings.RainbowMode 				= false
Settings.InfraRed 					= false

Settings.CanBreak	= false
Settings.Jammed		= false

return Settings
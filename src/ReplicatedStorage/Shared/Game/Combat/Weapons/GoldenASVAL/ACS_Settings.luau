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
Settings.Ammo 			= 55
Settings.StoredAmmo 	= 550
Settings.AmmoInGun 		= Settings.Ammo
Settings.MaxStoredAmmo	= 1100
Settings.CanCheckMag 	= true
Settings.MagCount		= true
Settings.ShellInsert	= false
Settings.ShootRate 		= 850
Settings.Bullets 		= 1
Settings.BurstShot 		= 3
Settings.ShootType 		= 3				--[1 = SEMI; 2 = BURST; 3 = AUTO; 4 = PUMP ACTION; 5 = BOLT ACTION]
Settings.FireModes = {
	ChangeFiremode = false;		
	Semi = false;
	Burst = false;
	Auto = true;}

Settings.LimbDamage 	= {32,32}
Settings.TorsoDamage 	= {32,32} 
Settings.HeadDamage 	= {32,32} 
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
	camRecoilUp 	= {12,15}
	,camRecoilTilt 	= {10,15}
	,camRecoilLeft 	= {7,10}
	,camRecoilRight = {6,9}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {20,25}
	,gunRecoilTilt 	= {10,20}
	,gunRecoilLeft 	= {15,20}
	,gunRecoilRight = {15,20}
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

Settings.BulletType 				= "9x19mm"
Settings.MuzzleVelocity 			= 1500 --m/s
Settings.BulletDrop 				= .05 --Between 0 - 1
Settings.Tracer						= true
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
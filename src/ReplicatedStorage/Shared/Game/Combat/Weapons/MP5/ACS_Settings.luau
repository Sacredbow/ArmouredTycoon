const Settings = {}

Settings.SlideEx 		= CFrame.new(0,0,-0.3)
Settings.SlideLock 		= false

Settings.canAim 		= true
Settings.Zoom 			= 60
Settings.Zoom2 			= 60

Settings.gunName 		= script.Parent.Name
Settings.Type 			= "Gun"
Settings.EnableHUD		= true
Settings.IncludeChamberedBullet = true
Settings.Ammo 			= 30
Settings.StoredAmmo 	= 90
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
	ChangeFiremode = true;		
	Semi = true;
	Burst = false;
	Auto = true;}

Settings.LimbDamage 	= {15,12}
Settings.TorsoDamage 	= {18,21} 
Settings.HeadDamage 	= {25,22} 
Settings.DamageFallOf 	= 2
Settings.MinDamage 		= 5
Settings.IgnoreProtection = false
Settings.BulletPenetration = 62.5

Settings.CrossHair 		= false
Settings.CenterDot 		= false
Settings.CrosshairOffset= 0
Settings.CanBreachDoor 	= false

Settings.SightAtt 		= ""
Settings.BarrelAtt		= ""
Settings.UnderBarrelAtt = ""
Settings.OtherAtt 		= ""

Settings.camRecoil = {
	camRecoilUp 	= {8,12}
	,camRecoilTilt 	= {10,15}
	,camRecoilLeft 	= {4,6}
	,camRecoilRight = {4,6}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {15,20}
	,gunRecoilTilt 	= {10,15}
	,gunRecoilLeft 	= {10,15}
	,gunRecoilRight = {10,15}
}

Settings.AimRecoilReduction 		= 4
Settings.AimSpreadReduction 		= 1

Settings.MinRecoilPower 			= .25
Settings.MaxRecoilPower 			= 1.5
Settings.RecoilPowerStepAmount 		= .05

Settings.MinSpread 					= 2.5
Settings.MaxSpread 					= 100					
Settings.AimInaccuracyStepAmount 	= 1
Settings.AimInaccuracyDecrease 		= .25
Settings.WalkMult 					= 0

Settings.EnableZeroing 				= true
Settings.MaxZero 					= 200
Settings.ZeroIncrement 				= 50
Settings.CurrentZero 				= 0

Settings.BulletType 				= "9x19mm"
Settings.MuzzleVelocity 			= 1250 --m/s
Settings.BulletDrop 				= .25 --Between 0 - 1
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
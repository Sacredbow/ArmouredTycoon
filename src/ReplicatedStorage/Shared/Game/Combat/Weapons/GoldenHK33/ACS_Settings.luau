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
Settings.Ammo 			= 50
Settings.StoredAmmo 	= 250
Settings.AmmoInGun 		= Settings.Ammo
Settings.MaxStoredAmmo	= 175
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

Settings.LimbDamage 	= {18,18}
Settings.TorsoDamage 	= {23,23} 
Settings.HeadDamage 	= {23,23} 
Settings.DamageFallOf 	= 1
Settings.MinDamage 		= 5
Settings.IgnoreProtection = false
Settings.BulletPenetration = 80

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
	camRecoilUp 	= {5,5}
	,camRecoilTilt 	= {5,5}
	,camRecoilLeft 	= {5,5}
	,camRecoilRight = {5,5}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {20,25}
	,gunRecoilTilt 	= {10,20}
	,gunRecoilLeft 	= {18,25}
	,gunRecoilRight = {18,25}
}

Settings.AimRecoilReduction 		= 4
Settings.AimSpreadReduction 		= 1

Settings.MinRecoilPower 			= .5
Settings.MaxRecoilPower 			= 1.5
Settings.RecoilPowerStepAmount 		= .05

Settings.MinSpread 					= 0.85
Settings.MaxSpread 					= 100					
Settings.AimInaccuracyStepAmount 	= .95
Settings.AimInaccuracyDecrease 		= .25
Settings.WalkMult 					= 0

Settings.EnableZeroing 				= true
Settings.MaxZero 					= 500
Settings.ZeroIncrement 				= 50
Settings.CurrentZero 				= 0

Settings.BulletType 				= "5.56x45mm"
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

Settings.CanBreak	= false
Settings.Jammed		= false

return Settings
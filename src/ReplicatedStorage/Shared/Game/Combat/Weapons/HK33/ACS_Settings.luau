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
Settings.Ammo 			= 25
Settings.StoredAmmo 	= 75
Settings.AmmoInGun 		= Settings.Ammo
Settings.MaxStoredAmmo	= 175
Settings.CanCheckMag 	= true
Settings.MagCount		= true
Settings.ShellInsert	= false
Settings.ShootRate 		= 750
Settings.Bullets 		= 1
Settings.BurstShot 		= 3
Settings.ShootType 		= 3				--[1 = SEMI; 2 = BURST; 3 = AUTO; 4 = PUMP ACTION; 5 = BOLT ACTION]
Settings.FireModes = {
	ChangeFiremode = true;		
	Semi = true;
	Burst = false;
	Auto = true;}

Settings.LimbDamage 	= {10,10}
Settings.TorsoDamage 	= {10,12} 
Settings.HeadDamage 	= {20,15} 
Settings.DamageFallOf 	= 1
Settings.MinDamage 		= 5
Settings.IgnoreProtection = false
Settings.BulletPenetration = 70

Settings.adsTime 		= 1

Settings.CrossHair 		= false
Settings.CenterDot 		= false
Settings.CrosshairOffset= 0
Settings.CanBreachDoor 	= false

Settings.SightAtt 		= ""
Settings.BarrelAtt		= ""
Settings.UnderBarrelAtt = ""
Settings.OtherAtt 		= ""

Settings.camRecoil = {
	camRecoilUp 	= {13,16}
	,camRecoilTilt 	= {10,15}
	,camRecoilLeft 	= {8,12}
	,camRecoilRight = {7,11}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {30,35}
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
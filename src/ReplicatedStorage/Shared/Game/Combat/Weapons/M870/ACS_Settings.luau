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
Settings.Ammo 			= 7
Settings.StoredAmmo 	= 21
Settings.AmmoInGun 		= Settings.Ammo
Settings.MaxStoredAmmo	= 49
Settings.CanCheckMag 	= false
Settings.MagCount		= false
Settings.ShellInsert	= true
Settings.ShootRate 		= 800
Settings.Bullets 		= 8
Settings.BurstShot 		= 3
Settings.ShootType 		= 4				--[1 = SEMI; 2 = BURST; 3 = AUTO; 4 = PUMP ACTION; 5 = BOLT ACTION]
Settings.FireModes = {
	ChangeFiremode = false;		
	Semi = false;
	Burst = false;
	Auto = false;}

Settings.LimbDamage 	= {30,20}
Settings.TorsoDamage 	= {20,25} 
Settings.HeadDamage 	= {45,45} 
Settings.DamageFallOf 	= 2
Settings.MinDamage 		= 5
Settings.IgnoreProtection = false
Settings.BulletPenetration = 50

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
	camRecoilUp 	= {70,75}
	,camRecoilTilt 	= {90,100}
	,camRecoilLeft 	= {40,45}
	,camRecoilRight = {40,45}
}

Settings.gunRecoil = {
	gunRecoilUp 	= {150,200}
	,gunRecoilTilt 	= {50,75}
	,gunRecoilLeft 	= {100,175}
	,gunRecoilRight = {100,175}
}

Settings.AimRecoilReduction 		= 1
Settings.AimSpreadReduction 		= 1

Settings.MinRecoilPower 			= 1
Settings.MaxRecoilPower 			= 1
Settings.RecoilPowerStepAmount 		= 1

Settings.MinSpread 					= 20
Settings.MaxSpread 					= 75					
Settings.AimInaccuracyStepAmount 	= 2
Settings.AimInaccuracyDecrease 		= 1.5
Settings.WalkMult 					= 0

Settings.EnableZeroing 				= false
Settings.MaxZero 					= 500
Settings.ZeroIncrement 				= 50
Settings.CurrentZero 				= 0

Settings.BulletType 				= ".12 Gauge"
Settings.MuzzleVelocity 			= 1500 --m/s
Settings.BulletDrop 				= .25 --Between 0 - 1
Settings.Tracer						= true
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
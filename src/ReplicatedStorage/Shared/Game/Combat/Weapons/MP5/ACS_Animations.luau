const TweenService = game:GetService('TweenService')
const AnimationData = {}

AnimationData.MainCFrame 	= CFrame.new(0.5,-.85,-0.75)

AnimationData.GunModelFixed 	= true
AnimationData.GunCFrame 		= CFrame.new(0.15, -.2, .85) * CFrame.Angles(math.rad(90),math.rad(0),math.rad(0))
AnimationData.LArmCFrame 	= CFrame.new(-.6,-0.1,-.2) * CFrame.Angles(math.rad(110),math.rad(15),math.rad(15))
AnimationData.RArmCFrame 	= CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(90),math.rad(0),math.rad(0))

AnimationData.EquipAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Linear), {C1 = (CFrame.new(1,-1,1) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Linear), {C1 = (CFrame.new(-1,-1,1) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))):inverse() }):Play()
	task.wait(.25)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.35,Enum.EasingStyle.Sine), {C1 = AnimationData.RArmCFrame:Inverse()}):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.35,Enum.EasingStyle.Sine), {C1 = AnimationData.LArmCFrame:Inverse()}):Play()
	task.wait(.35)
end;

AnimationData.IdleAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = AnimationData.RArmCFrame:Inverse()}):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = AnimationData.LArmCFrame:Inverse()}):Play()
end;

AnimationData.SprintAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(.75,-0.15,0) * CFrame.Angles(math.rad(90),math.rad(20),math.rad(-75))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-1.15,-0.75,0.4) * CFrame.Angles(math.rad(90),math.rad(20),math.rad(25))):inverse() }):Play()	
	task.wait(.25)
end;

AnimationData.LowReady = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1],TweenInfo.new(.25,Enum.EasingStyle.Sine),{C1 = (CFrame.new(0.05,-0.15,1) * CFrame.Angles(math.rad(65), math.rad(0), math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2],TweenInfo.new(.25,Enum.EasingStyle.Sine),{C1 = (CFrame.new(-.6,-0.5,0) * CFrame.Angles(math.rad(85),math.rad(15),math.rad(15))):inverse() }):Play()
	task.wait(0.25)	
end;

AnimationData.HighReady = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1],TweenInfo.new(.25,Enum.EasingStyle.Sine),{C1 = (CFrame.new(0.35,-0.75,1) * CFrame.Angles(math.rad(135), math.rad(0), math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2],TweenInfo.new(.25,Enum.EasingStyle.Sine),{C1 = (CFrame.new(-.2,-0.15,0.25) * CFrame.Angles(math.rad(155),math.rad(35),math.rad(15))):inverse() }):Play()
	task.wait(0.25)	
end;

AnimationData.Patrol = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(.75,-0.15,0) * CFrame.Angles(math.rad(90),math.rad(20),math.rad(-75))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-1.15,-0.75,0.4) * CFrame.Angles(math.rad(90),math.rad(20),math.rad(25))):inverse() }):Play()	
	task.wait(.25)	
end;

AnimationData.ReloadAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(110),math.rad(-15),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.65,0,.2) * CFrame.Angles(math.rad(110),math.rad(-15),math.rad(30))):inverse() }):Play()
	task.wait(.3)

	TweenService:Create(AnimationObjects[1], TweenInfo.new(.5,Enum.EasingStyle.Back), {C1 = (CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(100),math.rad(-5),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Back), {C1 = (CFrame.new(-.75,-0.15,1) * CFrame.Angles(math.rad(60),math.rad(-5),math.rad(15))):inverse() }):Play()
	task.wait(.05)
	AnimationObjects[4].Handle.MagOut:Play()
	AnimationObjects[4].Mag.Transparency = 1
	task.wait(.5)
	AnimationObjects[4].Handle.AimUp:Play()
	task.wait(.75)
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.65,0,.2) * CFrame.Angles(math.rad(110),math.rad(-15),math.rad(30))):inverse() }):Play()
	task.wait(.25)
	AnimationObjects[4].Handle.MagIn:Play()
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.15,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(101),math.rad(-6),math.rad(0))):inverse() }):Play()
	AnimationObjects[4].Mag.Transparency = 0
	task.wait(.2)
end;

AnimationData.TacticalReloadAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(90),math.rad(0),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.65,0.1,-0.15) * CFrame.Angles(math.rad(90),math.rad(60),math.rad(30))):inverse() }):Play()
	task.wait(.25)
	AnimationObjects[4].Bolt.SlidePull:Play()
	TweenService:Create(AnimationObjects[4].Handle.Slide, TweenInfo.new(.15,Enum.EasingStyle.Sine), {C0 =  CFrame.new(0,0,-0.3):inverse() }):Play()
	TweenService:Create(AnimationObjects[4].Handle.Bolt, TweenInfo.new(.15,Enum.EasingStyle.Sine), {C0 =  CFrame.new(0,0,-0.3):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.15,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.65,0.1,0.15) * CFrame.Angles(math.rad(90),math.rad(60),math.rad(30))):inverse() }):Play()
	task.wait(.2)

	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(110),math.rad(-15),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.65,0,.2) * CFrame.Angles(math.rad(110),math.rad(-15),math.rad(30))):inverse() }):Play()
	task.wait(.3)

	TweenService:Create(AnimationObjects[1], TweenInfo.new(.5,Enum.EasingStyle.Back), {C1 = (CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(100),math.rad(-5),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Back), {C1 = (CFrame.new(-.75,-0.15,1) * CFrame.Angles(math.rad(60),math.rad(-5),math.rad(15))):inverse() }):Play()
	task.wait(.05)
	AnimationObjects[4].Handle.MagOut:Play()
	AnimationObjects[4].Mag.Transparency = 1
	task.wait(.5)
	AnimationObjects[4].Handle.AimUp:Play()
	task.wait(.75)
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.65,0,.2) * CFrame.Angles(math.rad(110),math.rad(-15),math.rad(30))):inverse() }):Play()
	task.wait(.25)
	AnimationObjects[4].Handle.MagIn:Play()
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.15,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(101),math.rad(-6),math.rad(0))):inverse() }):Play()
	AnimationObjects[4].Mag.Transparency = 0
	task.wait(.25)

	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.55,0.15,.2) * CFrame.Angles(math.rad(160),math.rad(0),math.rad(15))):inverse() }):Play()
	task.wait(.25)
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Back), {C1 = (CFrame.new(-.6,-0.15,.2) * CFrame.Angles(math.rad(70),math.rad(-15),math.rad(15))):inverse() }):Play()
	task.wait(.05)
	TweenService:Create(AnimationObjects[4].Handle.Slide, TweenInfo.new(.15,Enum.EasingStyle.Linear), {C0 =  CFrame.new():inverse() }):Play()
	TweenService:Create(AnimationObjects[4].Handle.Bolt, TweenInfo.new(.15,Enum.EasingStyle.Linear), {C0 =  CFrame.new():inverse() }):Play()
	AnimationObjects[4].Bolt.SlideRelease:Play()
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.15,Enum.EasingStyle.Back), {C1 = (CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(85),math.rad(0),math.rad(0))):inverse() }):Play()
	task.wait(.25)
end;

AnimationData.JammedAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0.05,-0.15,.85) * CFrame.Angles(math.rad(90),math.rad(0),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.65,0.1,-0.15) * CFrame.Angles(math.rad(90),math.rad(60),math.rad(30))):inverse() }):Play()
	task.wait(.25)
	AnimationObjects[4].Bolt.SlidePull:Play()
	TweenService:Create(AnimationObjects[4].Handle.Slide, TweenInfo.new(.2,Enum.EasingStyle.Sine), {C0 =  CFrame.new(0,0,-0.3):inverse() }):Play()
	TweenService:Create(AnimationObjects[4].Handle.Bolt, TweenInfo.new(.2,Enum.EasingStyle.Sine), {C0 =  CFrame.new(0,0,-0.3):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.2,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.65,0.1,0.15) * CFrame.Angles(math.rad(90),math.rad(60),math.rad(30))):inverse() }):Play()
	task.wait(.3)
	TweenService:Create(AnimationObjects[4].Handle.Slide, TweenInfo.new(.15,Enum.EasingStyle.Linear), {C0 =  CFrame.new():inverse() }):Play()
	TweenService:Create(AnimationObjects[4].Handle.Bolt, TweenInfo.new(.15,Enum.EasingStyle.Linear), {C0 =  CFrame.new():inverse() }):Play()
	AnimationObjects[4].Bolt.SlideRelease:Play()
end;

AnimationData.PumpAnim = function(AnimationObjects)

end;

AnimationData.MagCheck = function(AnimationObjects)
	AnimationObjects[4].Handle.AimUp:Play()
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0.5,-0.15,0) * CFrame.Angles(math.rad(100),math.rad(0),math.rad(-45))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Linear), {C1 = (CFrame.new(-1,-1,1) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))):inverse() }):Play()
	task.wait(2.5)
	AnimationObjects[4].Handle.AimDown:Play()
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0.5,-0.15,0) * CFrame.Angles(math.rad(160),math.rad(60),math.rad(-45))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Linear), {C1 = (CFrame.new(-1,-1,1) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))):inverse() }):Play()
	task.wait(2.5)
	AnimationObjects[4].Handle.AimUp:Play()
end;

AnimationData.meleeAttack = function(AnimationObjects)

end;

AnimationData.GrenadeReady = function(AnimationObjects)

end;

AnimationData.GrenadeThrow = function(AnimationObjects)

end;

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--//Server Animations
------//Idle Position
AnimationData.SV_GunPos 		= CFrame.new(-.3, -1, -0.4) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0));

AnimationData.SV_RightArmPos = CFrame.new(-0.85, 0.2, -1.2) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0));
AnimationData.SV_LeftArmPos 	= CFrame.new(1.05,0.9,-1.4) * CFrame.Angles(math.rad(-100),math.rad(25),math.rad(-20));

------//High Ready Animations
AnimationData.RightHighReady = CFrame.new(-1, -1, -1.5) * CFrame.Angles(math.rad(-160), math.rad(0), math.rad(0));
AnimationData.LeftHighReady 	= CFrame.new(.85,-0.35,-1.15) * CFrame.Angles(math.rad(-170),math.rad(60),math.rad(15));

------//Low Ready Animations
AnimationData.RightLowReady 	= CFrame.new(-1, 0.5, -1.25) * CFrame.Angles(math.rad(-60), math.rad(0), math.rad(0));
AnimationData.LeftLowReady 	= CFrame.new(1.25,1.15,-1.35) * CFrame.Angles(math.rad(-60),math.rad(35),math.rad(-25));

------//Patrol Animations
AnimationData.RightPatrol 	= CFrame.new(-1, -.35, -1.5) * CFrame.Angles(math.rad(-80), math.rad(-80), math.rad(0));
AnimationData.LeftPatrol 	= CFrame.new(1,1.25,-.75) * CFrame.Angles(math.rad(-90),math.rad(-45),math.rad(-25));

------//Aim Animations
AnimationData.RightAim 		= CFrame.new(-.575, 0.2, -1) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0));
AnimationData.LeftAim 		= CFrame.new(1.4,0.25,-1.45) * CFrame.Angles(math.rad(-120),math.rad(35),math.rad(-25));

------//Sprinting Animations
AnimationData.RightSprint 	= CFrame.new(-1, 0.5, -1.25) * CFrame.Angles(math.rad(-60), math.rad(0), math.rad(0));
AnimationData.LeftSprint 	= CFrame.new(1.25,1.15,-1.35) * CFrame.Angles(math.rad(-60),math.rad(35),math.rad(-25));

return AnimationData
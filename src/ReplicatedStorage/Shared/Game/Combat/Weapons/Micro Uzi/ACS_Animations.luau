const TweenService = game:GetService('TweenService')
const AnimationData = {}

AnimationData.MainCFrame 	= CFrame.new(0.5,-.70,-1.2)

AnimationData.GunModelFixed 	= true
AnimationData.GunCFrame 		= CFrame.new(0.15, -.2, .85) * CFrame.Angles(math.rad(90),math.rad(0),math.rad(0))
AnimationData.LArmCFrame 	= CFrame.new(-.4,-0.6,0.3) * CFrame.Angles(math.rad(110),math.rad(15),math.rad(15))
AnimationData.RArmCFrame 	= CFrame.new(0.05,-0.15,1) * CFrame.Angles(math.rad(90),math.rad(0),math.rad(0))

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

AnimationData.LowReady = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1],TweenInfo.new(.25,Enum.EasingStyle.Sine),{C1 = (CFrame.new(0.05,-0.15,1) * CFrame.Angles(math.rad(65), math.rad(0), math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2],TweenInfo.new(.25,Enum.EasingStyle.Sine),{C1 = (CFrame.new(-.6,-0.75,-.25) * CFrame.Angles(math.rad(85),math.rad(15),math.rad(15))):inverse() }):Play()
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

AnimationData.SprintAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(.5,-0.15,0) * CFrame.Angles(math.rad(175),math.rad(0),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-1,-1,1) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))):inverse() }):Play()	
	task.wait(.25)
end;

AnimationData.ReloadAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0,-0.2,1) * CFrame.Angles(math.rad(90),math.rad(-25),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.6,-0.5,0.8) * CFrame.Angles(math.rad(60),math.rad(50),math.rad(30))):inverse() }):Play()
	task.wait(.3)

	TweenService:Create(AnimationObjects[1], TweenInfo.new(.5,Enum.EasingStyle.Back), {C1 = (CFrame.new(0,-0.2,1) * CFrame.Angles(math.rad(85),math.rad(-15),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.5,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-1.5,-.5,.75) * CFrame.Angles(math.rad(0),math.rad(50),math.rad(15))):inverse() }):Play()
	task.wait(.05)
	AnimationObjects[4].Handle.MagOut:Play()
	AnimationObjects[4].Mag.Transparency = 1
	task.wait(.5)
	AnimationObjects[4].Handle.AimUp:Play()
	task.wait(.75)
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.6,-0.3,0.8) * CFrame.Angles(math.rad(60),math.rad(50),math.rad(30))):inverse() }):Play()
	task.wait(.25)
	AnimationObjects[4].Handle.MagIn:Play()
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.15,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0,-0.15,1) * CFrame.Angles(math.rad(90),math.rad(-25),math.rad(0))):inverse() }):Play()
	AnimationObjects[4].Mag.Transparency = 0
	task.wait(.15)
end;

AnimationData.TacticalReloadAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Back), {C1 = (CFrame.new(0,-0.2,1) * CFrame.Angles(math.rad(95),math.rad(45),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.5,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-1.5,-1,1) * CFrame.Angles(math.rad(0),math.rad(50),math.rad(15))):inverse() }):Play()
	task.wait(.2)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.5,Enum.EasingStyle.Back), {C1 = (CFrame.new(0,-0.2,1) * CFrame.Angles(math.rad(85),math.rad(-25),math.rad(0))):inverse() }):Play()

	AnimationObjects[4].Handle.MagOut:Play()
	AnimationObjects[4].Mag.Transparency = 1

	const FakeMag = AnimationObjects[4]:WaitForChild("Mag"):Clone()
	FakeMag:ClearAllChildren()
	FakeMag.Transparency = 0
	FakeMag.Parent = AnimationObjects[4]
	FakeMag.Anchored = false
	FakeMag.RotVelocity = Vector3.new(0,0,0)
	FakeMag:ApplyImpulse(FakeMag.CFrame.RightVector * 1) --FakeMag.CFrame.LookVector * 15

	task.wait(.5)
	AnimationObjects[4].Handle.AimUp:Play()
	task.wait(.25)
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.6,-0.3,1) * CFrame.Angles(math.rad(60),math.rad(50),math.rad(30))):inverse() }):Play()
	task.wait(.25)
	AnimationObjects[4].Handle.MagIn:Play()
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.15,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0,-0.2,1) * CFrame.Angles(math.rad(90),math.rad(-25),math.rad(0))):inverse() }):Play()
	AnimationObjects[4].Mag.Transparency = 0
	task.wait(.25)
	AnimationObjects[4].Bolt.SlideRelease:Play()
	TweenService:Create(AnimationObjects[4].Handle.Slide, TweenInfo.new(.05,Enum.EasingStyle.Linear), {C0 =  CFrame.new():inverse() }):Play()
	task.wait(.1)
end;

AnimationData.JammedAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(0.05,-0.15,.75) * CFrame.Angles(math.rad(90),math.rad(0),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.5,-0.35,0.45) * CFrame.Angles(math.rad(160),math.rad(0),math.rad(0))):inverse() }):Play()
	task.wait(.25)
	AnimationObjects[4].Bolt.SlidePull:Play()
	TweenService:Create(AnimationObjects[4].Handle.Slide, TweenInfo.new(.2,Enum.EasingStyle.Sine), {C0 =  CFrame.new(0,0,-0.4):inverse() }):Play()
	TweenService:Create(AnimationObjects[4].Handle.Bolt, TweenInfo.new(.2,Enum.EasingStyle.Sine), {C0 =  CFrame.new(0,0,-0.4):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.2,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-.5,-0.35,0.45) * CFrame.Angles(math.rad(180),math.rad(0),math.rad(0))):inverse() }):Play()
	task.wait(.3)
	TweenService:Create(AnimationObjects[4].Handle.Slide, TweenInfo.new(.1,Enum.EasingStyle.Linear), {C0 =  CFrame.new():inverse() }):Play()
	TweenService:Create(AnimationObjects[4].Handle.Bolt, TweenInfo.new(.1,Enum.EasingStyle.Linear), {C0 =  CFrame.new():inverse() }):Play()
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
AnimationData.SV_GunPos = CFrame.new(-.3, -.2, -0.4) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0))

AnimationData.SV_RightArmPos = CFrame.new(-.9, 1.25, -0.35) * CFrame.Angles(math.rad(-30), math.rad(0), math.rad(0))	--Server
AnimationData.SV_LeftArmPos = CFrame.new(1,1,-1) * CFrame.Angles(math.rad(-80),math.rad(30),math.rad(-10))	--server

AnimationData.SV_RightElbowPos = CFrame.new(0,-0.45,-.25) * CFrame.Angles(math.rad(-80), math.rad(0), math.rad(0))		--Client
AnimationData.SV_LeftElbowPos = CFrame.new(0,0, -0.1) * CFrame.Angles(math.rad(-15),math.rad(0),math.rad(0))	--Client

AnimationData.SV_RightWristPos = CFrame.new(0,0,0.15) * CFrame.Angles(math.rad(20), math.rad(0), math.rad(0))		--Client
AnimationData.SV_LeftWristPos = CFrame.new(0,0,0) * CFrame.Angles(math.rad(0),math.rad(-15),math.rad(0))	

------//High Ready Animations
AnimationData.RightHighReady = CFrame.new(-1.1, .5, -1.1) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0));
AnimationData.LeftHighReady = CFrame.new(0.65,0.4,-1.3) * CFrame.Angles(math.rad(-140),math.rad(30),math.rad(30));

AnimationData.RightElbowHighReady = CFrame.new(0,-0.25,-.35) * CFrame.Angles(math.rad(-45), math.rad(0), math.rad(0));
AnimationData.LeftElbowHighReady = CFrame.new(0,0, -0.1) * CFrame.Angles(math.rad(-15),math.rad(0),math.rad(0));

AnimationData.RightWristHighReady = CFrame.new(0,0,0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0));
AnimationData.LeftWristHighReady = CFrame.new(0,0,0) * CFrame.Angles(math.rad(0),math.rad(-15),math.rad(0));	

------//Low Ready Animations
AnimationData.RightLowReady = CFrame.new(-.9, 1.25, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0));
AnimationData.LeftLowReady = CFrame.new(1,1,-0.6) * CFrame.Angles(math.rad(-45),math.rad(15),math.rad(-25));

AnimationData.RightElbowLowReady = CFrame.new(0,-0.45,-.25) * CFrame.Angles(math.rad(-80), math.rad(0), math.rad(0));
AnimationData.LeftElbowLowReady = CFrame.new(0,0,0)  * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0));

AnimationData.RightWristLowReady = CFrame.new(0,0,0.15) * CFrame.Angles(math.rad(20), math.rad(0), math.rad(0));
AnimationData.LeftWristLowReady = CFrame.new(0,0,0)  * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0));	

------//Patrol Animations
AnimationData.RightPatrol = CFrame.new(-.85, 0.75, -1.3) * CFrame.Angles(math.rad(-30), math.rad(-90), math.rad(0));
AnimationData.LeftPatrol = CFrame.new(1.5,1.1,0) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0));

AnimationData.RightElbowPatrol = CFrame.new(0,-0.2,-.1) * CFrame.Angles(math.rad(-40), math.rad(0), math.rad(0));
AnimationData.LeftElbowPatrol = CFrame.new(0,-0.15,-0.25)  * CFrame.Angles(math.rad(-50), math.rad(0), math.rad(0));

AnimationData.RightWristPatrol = CFrame.new(0,0,0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(-15));
AnimationData.LeftWristPatrol = CFrame.new(0,0,0)  * CFrame.Angles(math.rad(0), math.rad(-90), math.rad(0));	

------//Aim Animations
AnimationData.RightAim = CFrame.new(-.6, 0.85, -0.5) * CFrame.Angles(math.rad(-50), math.rad(0), math.rad(0));
AnimationData.LeftAim = CFrame.new(1.6,0.6,-0.85) * CFrame.Angles(math.rad(-95),math.rad(35),math.rad(-25));

AnimationData.RightElbowAim = CFrame.new(0,-0.2,-.25) * CFrame.Angles(math.rad(-60), math.rad(0), math.rad(0));
AnimationData.LeftElbowAim = CFrame.new(0,0,0)  * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0));

AnimationData.RightWristAim = CFrame.new(0,0,0.15) * CFrame.Angles(math.rad(20), math.rad(0), math.rad(0));
AnimationData.LeftWristAim = CFrame.new(0,0,0)  * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0));

------//Sprinting Animations
AnimationData.RightSprint = CFrame.new(-.9, 1.25, 0) * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0));
AnimationData.LeftSprint = CFrame.new(1,1,-0.6) * CFrame.Angles(math.rad(-45),math.rad(15),math.rad(-25));

AnimationData.RightElbowSprint = CFrame.new(0,-0.45,-.25) * CFrame.Angles(math.rad(-80), math.rad(0), math.rad(0));
AnimationData.LeftElbowSprint = CFrame.new(0,0,0)  * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0));

AnimationData.RightWristSprint = CFrame.new(0,0,0.15) * CFrame.Angles(math.rad(20), math.rad(0), math.rad(0));
AnimationData.LeftWristSprint = CFrame.new(0,0,0)  * CFrame.Angles(math.rad(0), math.rad(0), math.rad(0));

return AnimationData
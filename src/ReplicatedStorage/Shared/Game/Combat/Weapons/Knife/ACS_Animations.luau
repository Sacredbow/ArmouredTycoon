const TweenService = game:GetService('TweenService')
const AnimationData = {}

AnimationData.MainCFrame 	= CFrame.new(0,0,0)

AnimationData.GunModelFixed 	= true
AnimationData.GunCFrame 		= CFrame.new(0.15, 0, .85) * CFrame.Angles(math.rad(90),math.rad(0),math.rad(0))
AnimationData.LArmCFrame	 	= CFrame.new(-1,-.85,-.25) * CFrame.Angles(math.rad(100),math.rad(-30),math.rad(15))
AnimationData.RArmCFrame 	= CFrame.new(1,-.85,-.25) * CFrame.Angles(math.rad(100),math.rad(30),math.rad(-15))

AnimationData.EquipAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(0,Enum.EasingStyle.Linear), {C1 = (CFrame.new(1,-1,1) * CFrame.Angles(math.rad(180),math.rad(35),math.rad(-120))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(0,Enum.EasingStyle.Linear), {C1 = (CFrame.new(-1,-1,1) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))):inverse() }):Play()
	task.wait(.15)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = AnimationData.RArmCFrame:Inverse()}):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = AnimationData.LArmCFrame:Inverse()}):Play()
	task.wait(.25)
end;

AnimationData.IdleAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = AnimationData.RArmCFrame:Inverse()}):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = AnimationData.LArmCFrame:Inverse()}):Play()
end;

AnimationData.LowReady = function(AnimationObjects)

end;

AnimationData.HighReady = function(AnimationObjects)

end;

AnimationData.Patrol = function(AnimationObjects)

end;

AnimationData.SprintAnim = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(1,-1,1) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-1,-1,1) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))):inverse() }):Play()	
	task.wait(.25)
end;

AnimationData.ReloadAnim = function(AnimationObjects)

end;

AnimationData.TacticalReloadAnim = function(AnimationObjects)

end;

AnimationData.JammedAnim = function(AnimationObjects)

end;

AnimationData.PumpAnim = function(AnimationObjects)

end;

AnimationData.MagCheck = function(AnimationObjects)

end;

AnimationData.meleeAttack = function(AnimationObjects)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.15,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-1,-.65,0) * CFrame.Angles(math.rad(175),math.rad(15),math.rad(-85))):inverse() }):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.25,Enum.EasingStyle.Sine), {C1 = (CFrame.new(-1,-1,1) * CFrame.Angles(math.rad(0),math.rad(0),math.rad(0))):inverse() }):Play()	
	task.wait(.2)
	AnimationObjects[4].Handle.Swing:Play()
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.25,Enum.EasingStyle.Back), {C1 = (CFrame.new(1.5,-.85,0) * CFrame.Angles(math.rad(180),math.rad(160),math.rad(-85))):inverse() }):Play()
	task.wait(.3)
	TweenService:Create(AnimationObjects[1], TweenInfo.new(.35,Enum.EasingStyle.Back), {C1 = AnimationData.RArmCFrame:Inverse()}):Play()
	TweenService:Create(AnimationObjects[2], TweenInfo.new(.35,Enum.EasingStyle.Back), {C1 = AnimationData.LArmCFrame:Inverse()}):Play()
	task.wait(.1)
end;

AnimationData.GrenadeReady = function(AnimationObjects)

end;

AnimationData.GrenadeThrow = function(AnimationObjects)

end;

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------
--//Server Animations
------//Idle Position
AnimationData.SV_GunPos 		= CFrame.new(-.3, -1, -0.4) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0))

AnimationData.SV_RightArmPos = CFrame.new(-0.575, 0.65, -1.185) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0))
AnimationData.SV_LeftArmPos 	= CFrame.new(1.15,-0.1,-1.65) * CFrame.Angles(math.rad(-120),math.rad(20),math.rad(-25))

------//High Ready Animations
AnimationData.RightHighReady = CFrame.new(-1, -.5, -1.25) * CFrame.Angles(math.rad(-160), math.rad(0), math.rad(0));
AnimationData.LeftHighReady 	= CFrame.new(.85,-0.35,-1.15) * CFrame.Angles(math.rad(-170),math.rad(60),math.rad(15));

------//Low Ready Animations
AnimationData.RightLowReady 	= CFrame.new(-1, 0.85, -1.15) * CFrame.Angles(math.rad(-60), math.rad(0), math.rad(0));
AnimationData.LeftLowReady 	= CFrame.new(.95,.75,-1.35) * CFrame.Angles(math.rad(-60),math.rad(35),math.rad(-25));

------//Patrol Animations
AnimationData.RightPatrol 	= CFrame.new(-1, 1.5, -0.45) * CFrame.Angles(math.rad(-30), math.rad(0), math.rad(0));
AnimationData.LeftPatrol 	= CFrame.new(1,1.35,-0.75) * CFrame.Angles(math.rad(-30),math.rad(35),math.rad(-25));

------//Aim Animations
AnimationData.RightAim 		= CFrame.new(-.575, 1, -.65) * CFrame.Angles(math.rad(-90), math.rad(0), math.rad(0));
AnimationData.LeftAim 		= CFrame.new(1.3,0.35,-1.45) * CFrame.Angles(math.rad(-120),math.rad(35),math.rad(-25));

------//Sprinting Animations
AnimationData.RightSprint 	= CFrame.new(-1, 1.5, -0.45) * CFrame.Angles(math.rad(-30), math.rad(0), math.rad(0));
AnimationData.LeftSprint 	= CFrame.new(1,1.35,-0.75) * CFrame.Angles(math.rad(-30),math.rad(35),math.rad(-25));

return AnimationData
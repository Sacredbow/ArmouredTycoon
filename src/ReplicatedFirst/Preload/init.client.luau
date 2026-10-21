
local player = game:GetService("Players").LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local Camera = workspace.CurrentCamera
local head = character:WaitForChild("Head")
local playerGUI = player:WaitForChild("PlayerGui")
local humanoid : Humanoid = character:WaitForChild("Humanoid")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientRuntimeState = require(ReplicatedStorage.Modules.ClientRuntimeState)
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local PlayerScripts = player:WaitForChild("PlayerScripts") :: typeof(player.PlayerScripts)
local PlayerModule = require(PlayerScripts:WaitForChild("PlayerModule")) :: ModuleScript & PlayerModule


local Controls = PlayerModule:GetControls()

type ControlsManager = {
	Disable: () -> (), 
	Enable: () -> (),

}
type PlayerModule = {
	GetControls: (self : PlayerModule) -> ControlsManager ,

}


local BackgroundBlur = Lighting.BackgroundBlur

ClientRuntimeState.SetHasLoaded(player, false)


Controls:Enable()


local RotationManger = require(script.RotationManager)
local InitManager = require(script.InitManager)
local TweenManager = require(ReplicatedStorage.Modules.TweenManager)

local SubtitlesGUI = playerGUI.SubtitlesGUI
local Subtitles = SubtitlesGUI.Subtitles
local sound = SoundService.SFX.UserInterface.Interactions.TextSound
local BaseCharSys = character:WaitForChild("BaseCharacterSystems")


local PlayerInterface = playerGUI.MainInterface.PlayerInterface






local CameraPoint1 = workspace:WaitForChild("CameraPoint1")
local CameraPoint2 = workspace:WaitForChild("CameraPoint2")
--local CameraPoint3 = workspace:WaitForChild("CameraPoint3")

local Menu = Instance.new("ScreenGui")
Menu.Parent = playerGUI
Menu.IgnoreGuiInset = true
Menu.ResetOnSpawn = false
Menu.Name = "MenuScreen"

local BlackScreen = Instance.new("Frame")
BlackScreen.Parent = Menu
BlackScreen.BackgroundColor3 = Color3.new(0, 0, 0)
BlackScreen.BorderSizePixel = 0

BlackScreen.AnchorPoint = Vector2.new(0, 0)
BlackScreen.Position = UDim2.fromScale(0, 0)
BlackScreen.Size = UDim2.fromScale(1, 1)
BlackScreen.BackgroundTransparency = 0

local PlayButton = PlayerInterface.Play
local ChangeLog : TextButton = PlayerInterface.Changelog
local Credits : TextButton = PlayerInterface.Credits

local Stroke1 = PlayButton.UIStroke
local Stroke2 = ChangeLog.UIStroke
local Stroke3 = Credits.UIStroke



local BackgroundCover : ImageLabel = Instance.new("ImageLabel")
BackgroundCover.Parent = Menu
BackgroundCover.BackgroundColor3 = Color3.new(0, 0, 0)
BackgroundCover.BorderSizePixel = 0

BackgroundCover.AnchorPoint = Vector2.new(0, 0)
BackgroundCover.Position = UDim2.fromScale(0, 0)
BackgroundCover.Size = UDim2.fromScale(1, 1)
BackgroundCover.BackgroundTransparency = 1
BackgroundCover.ImageTransparency = 1
BackgroundCover.Image = "rbxassetid://125917413750903"


local Presents1 = Instance.new("TextLabel")
Presents1.Parent = BlackScreen
Presents1.Position = UDim2.fromScale(0.5, 0.5)
Presents1.AnchorPoint = Vector2.new(0.5, 0.5)
Presents1.BackgroundTransparency = 1
Presents1.Font = Enum.Font.Highway
Presents1.Size = UDim2.fromScale(0.4, 0.4)
Presents1.Text = "Aqua Studios Presents...."
Presents1.TextColor3 = Color3.new(1, 1, 1)
Presents1.TextSize = 0
Presents1.TextTransparency = 1

local Presents2 = Instance.new("TextLabel")
Presents2.Parent = BlackScreen
Presents2.Position = UDim2.fromScale(0.5, 0.5)
Presents2.AnchorPoint = Vector2.new(0.5, 0.5)
Presents2.BackgroundTransparency = 1
Presents2.Font = Enum.Font.TitilliumWeb
Presents2.Size = UDim2.fromScale(0.4, 0.4)
Presents2.Text = "ARMOURED TYCOON"
Presents2.TextColor3 = Color3.new(1, 1, 0)
Presents2.TextSize = 65
Presents2.TextTransparency = 1

local LoadingCounter = Instance.new("TextLabel")
LoadingCounter.Parent = BackgroundCover
LoadingCounter.Position = UDim2.fromScale(0.5, 0.5)
LoadingCounter.AnchorPoint = Vector2.new(0.5, 0.5)
LoadingCounter.BackgroundTransparency = 1
LoadingCounter.Font = Enum.Font.TitilliumWeb
LoadingCounter.Size = UDim2.fromScale(0.4, 0.4)
LoadingCounter.Text = "[0/0]"
LoadingCounter.TextColor3 = Color3.new(1, 1, 0)
LoadingCounter.TextSize = 65
LoadingCounter.TextTransparency = 1

local Tips = Instance.new("TextLabel")
Tips.Parent = BackgroundCover
Tips.Position = UDim2.fromScale(0.5, 0.8)
Tips.AnchorPoint = Vector2.new(0.5, 0.5)
Tips.BackgroundTransparency = 1
Tips.Font = Enum.Font.TitilliumWeb
Tips.Size = UDim2.fromScale(0.65, 0.3)
Tips.Text = ""
Tips.TextColor3 = Color3.new(1, 1, 1)
Tips.TextScaled = true
Tips.TextTransparency = 1

local Init = Instance.new("TextLabel")
Init.Parent = BackgroundCover
Init.Position = UDim2.fromScale(0.5, 0.6)
Init.AnchorPoint = Vector2.new(0.5, 0.5)
Init.BackgroundTransparency = 1
Init.Font = Enum.Font.TitilliumWeb
Init.Size = UDim2.fromScale(0.4, 0.4)
Init.Text = ""
Init.TextColor3 = Color3.new(1, 1, 1)
Init.TextSize = 20
Init.TextTransparency = 0.25


local Rotation = RotationManger.new({
	Label = Tips
	
})

local InitText = InitManager.new({
	Label = Init
})






local LoadingComplete = false

local function Assets()
	Rotation:Start()
	InitText:Start()

	local assets = { BackgroundCover, PlayerInterface }
	local total = #assets
	local loaded = 0
	LoadingCounter.Text = "[0/" .. total .. "]"

	local success, errorMessage = pcall(function()
		ContentProvider:PreloadAsync(assets, function()
			loaded += 1
			LoadingCounter.Text = "[" .. loaded .. "/" .. total .. "]"
		end)
	end)
	if not success then
		warn("[Preload] Critical asset preload failed:", errorMessage)
	end

	LoadingCounter.Text = "[" .. math.min(loaded, total) .. "/" .. total .. "]"
end
task.spawn(function()
	while not LoadingComplete do
		task.wait(5)
		if LoadingComplete then
			break
		end
		TweenService:Create(BackgroundCover, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
			ImageColor3 = Color3.fromRGB(math.random(1, 255), math.random(1, 255), math.random(1, 255)),
		}):Play()
	end
end)
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)

task.wait(5)
TweenManager.Interface(Presents1, {TextTransparency = 0}, TweenInfo.new(1, Enum.EasingStyle.Sine))
TweenManager.Interface(Presents1, {TextSize = 65}, TweenInfo.new(1.3, Enum.EasingStyle.Sine))

task.wait(3)
TweenManager.Interface(Presents1, {TextTransparency = 1}, TweenInfo.new(2, Enum.EasingStyle.Sine))

task.wait(2)
TweenManager.Interface(Presents2, {TextTransparency = 0}, TweenInfo.new(1.5, Enum.EasingStyle.Sine))

task.wait(3)
TweenManager.Interface(Presents2, {TextTransparency = 1}, TweenInfo.new(1, Enum.EasingStyle.Sine))
task.wait(1.5)

TweenManager.Interface(BackgroundCover, {BackgroundTransparency = 0}, TweenInfo.new(1, Enum.EasingStyle.Sine))
TweenManager.Interface(BackgroundCover, {ImageTransparency = 0}, TweenInfo.new(1, Enum.EasingStyle.Sine))
task.wait(1)
TweenManager.Interface(BlackScreen, {BackgroundTransparency = 1}, TweenInfo.new(0.2, Enum.EasingStyle.Sine))

TweenManager.Interface(LoadingCounter, {TextTransparency = 0}, TweenInfo.new(1, Enum.EasingStyle.Sine))

Assets()
LoadingComplete = true
Rotation:Stop()
InitText:Finish()
task.wait(2)
Rotation:Hide()
InitText:Hide()
task.wait(2)
TweenManager.Interface(LoadingCounter, {TextTransparency = 1}, TweenInfo.new(2, Enum.EasingStyle.Sine))
TweenManager.Interface(BackgroundCover, {BackgroundTransparency = 1}, TweenInfo.new(2, Enum.EasingStyle.Sine))
TweenManager.Interface(BackgroundCover, {ImageTransparency = 1}, TweenInfo.new(2, Enum.EasingStyle.Sine))


local function setfalse()
	task.wait(0.2)
	TweenManager.Interface(PlayButton, {BackgroundTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenManager.Interface(PlayButton, {TextTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenService:Create(Stroke1, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{Transparency = 1}):Play()
	

	task.wait(0.2)
	TweenManager.Interface(ChangeLog, {BackgroundTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenManager.Interface(ChangeLog, {TextTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenService:Create(Stroke2, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{Transparency = 1}):Play()

	task.wait(0.2)
	TweenManager.Interface(Credits, {BackgroundTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenManager.Interface(Credits, {TextTransparency = 1}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenService:Create(Stroke3, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Transparency = 1}):Play()

end


local function settrue()

task.wait(0.2)
	TweenManager.Interface(PlayButton, {BackgroundTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenManager.Interface(PlayButton, {TextTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenService:Create(Stroke1, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{Transparency = 0}):Play()


	task.wait(0.2)
	TweenManager.Interface(ChangeLog, {BackgroundTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenManager.Interface(ChangeLog, {TextTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenService:Create(Stroke2, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{Transparency = 0}):Play()

	
	

	task.wait(0.2)
	TweenManager.Interface(Credits, {BackgroundTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenManager.Interface(Credits, {TextTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenService:Create(Stroke3, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Transparency = 0}):Play()
end








local function text(label, text, delaychar)
	


	label.Text = ""
	
	for i = 1, #text do
		label.Text = string.sub(text, 1, i)
		sound:Play()
		task.wait(delaychar or 0.5)
	end
end



	Camera.CameraType = Enum.CameraType.Scriptable
	local StartingCFrame = CFrame.new(head.Position + head.CFrame.LookVector * 2, head.Position)
	Camera.CFrame = StartingCFrame
for _, v in pairs(playerGUI:GetChildren()) do
	if v:IsA("ScreenGui")
		and v.Name ~= "Dex"
		and v.Name ~= "SubtitlesGUI"
		and v ~= Menu
		and v.Name ~= "GamepassFrame"
	then
		v.Enabled = false
	end




		
	end
	
task.wait(1)
text(Subtitles, "Welcome to Build An Armoured Tycoon!", 0.05)


task.wait(2)
task.spawn(function()
		text(Subtitles, "Build your own infrastructure, organise your armoury, and become the strongest tycoon!", 0.06)
end)


local TargetedCFrame1 = CFrame.new(CameraPoint1.Position + CameraPoint1.CFrame.LookVector, CameraPoint1.Position)
local TargetedCFrame2 = CFrame.new(CameraPoint2.Position + CameraPoint2.CFrame.LookVector, CameraPoint2.Position)
--local TargetedCFrame3 = CFrame.new(CameraPoint3.Position + CameraPoint3.CFrame.LookVector, CameraPoint3.Position)
local TargetedCFrame4 = CFrame.new(head.Position + head.CFrame.LookVector * 3, head.Position)
local TargetedCFrame5 = CFrame.new(head.Position + head.CFrame.LookVector * 8, head.Position)

local tween1 = TweenService:Create(Camera, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = TargetedCFrame1})
tween1:Play()
tween1.Completed:Wait()

task.wait(0.2)
	local tween2 = TweenService:Create(Camera, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = TargetedCFrame2})
	tween2:Play()
	tween2.Completed:Wait()

--task.wait(0.2)
--	local tween3 = TweenService:Create(Camera, TweenInfo.new(3.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = TargetedCFrame3})
--	tween3:Play()
--	tween3.Completed:Wait()
	
	local tween4 = TweenService:Create(Camera, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = TargetedCFrame4})
	tween4:Play()
	tween4.Completed:Wait()
TweenManager.Interface(Subtitles, {TextTransparency = 1}, TweenInfo.new(0.7, Enum.EasingStyle.Sine))
	task.wait(0.5)
local tween5 = TweenService:Create(Camera, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {CFrame = TargetedCFrame5})
tween5:Play()
tween5.Completed:Wait()

PlayButton.Parent = Menu
Credits.Parent = Menu
ChangeLog.Parent = Menu

task.wait(1)
TweenManager.Interface(PlayButton, {BackgroundTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
TweenManager.Interface(PlayButton, {TextTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
TweenService:Create(Stroke1, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{Transparency = 0}):Play()

task.wait(1)
TweenManager.Interface(ChangeLog, {BackgroundTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
TweenManager.Interface(ChangeLog, {TextTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
TweenService:Create(Stroke2, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In),{Transparency = 0}):Play()

task.wait(1)
TweenManager.Interface(Credits, {BackgroundTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
TweenManager.Interface(Credits, {TextTransparency = 0}, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
TweenService:Create(Stroke3, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Transparency = 0}):Play()


local CreditsFrame : Frame = SubtitlesGUI.CreditsFrame
local ChangeLogFrame : Frame = SubtitlesGUI.ChangelogFrame
local Liner : TextLabel = CreditsFrame.Liner
local Liner2 : TextLabel = ChangeLogFrame.Liner
local CurrentSize = Liner.Size
local CurrentPos = CreditsFrame.Position
local CloseButton : TextButton = CreditsFrame.Close
local CloseButton2 : TextButton = ChangeLogFrame.Close


Credits.MouseButton1Click:Connect(function()
	setfalse()
	TweenManager.Interface(CreditsFrame, {Position = UDim2.fromScale(0.243,0.161)}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
	TweenService:Create(BackgroundBlur, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Size = 24}):Play()
	task.wait(0.35)
	TweenManager.Interface(Liner, {Size = UDim2.fromScale(0.584, -0.002)}, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	
	

end)

ChangeLog.MouseButton1Click:Connect(function()
	setfalse()
	TweenManager.Interface(ChangeLogFrame, {Position = UDim2.fromScale(0.243,0.161)}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
	TweenService:Create(BackgroundBlur, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Size = 24}):Play()
	task.wait(0.35)
	TweenManager.Interface(Liner2, {Size = UDim2.fromScale(0.584, -0.002)}, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.In))

end)

CloseButton.MouseButton1Click:Connect(function()
	TweenManager.Interface(Liner, {Size = CurrentSize}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenManager.Interface(CreditsFrame, {Position = CurrentPos}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
	TweenService:Create(BackgroundBlur, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Size = 0}):Play()
	settrue()
end)
CloseButton2.MouseButton1Click:Connect(function()
	TweenManager.Interface(Liner2, {Size = CurrentSize}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.In))
	TweenManager.Interface(ChangeLogFrame, {Position = CurrentPos}, TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out))
	TweenService:Create(BackgroundBlur, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {Size = 0}):Play()
	settrue()
end)


PlayButton.MouseButton1Click:Connect(function()
	Controls:Enable()
	Camera.CameraType = Enum.CameraType.Custom
	ClientRuntimeState.SetHasLoaded(player, true)
	
	Subtitles.TextTransparency = 1

	for _, v in (playerGUI:GetChildren()) do
		if v:IsA("ScreenGui") then
			v.Enabled = true
			
		
		end
	end
	
	
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.Chat, true)
PlayButton:Destroy()
ChangeLog:Destroy()
Credits:Destroy()



	local TycoonsFolder = workspace:WaitForChild("Tycoons")
	local PlayerData = {}
	local BeamsActive = false

	local function CleanupPlayerData()
		for _, Object in PlayerData do
			if Object and Object.Parent then
				pcall(function()
					Object:Destroy()
				end)
			end
		end
		PlayerData = {}
		BeamsActive = false
	end

	local function GetOwnerDoor(Tycoon)
		local MainItems = Tycoon:FindFirstChild("MainItems")
		local OwnerDoor = MainItems and MainItems:FindFirstChild("OwnerDoor")
		local Door = OwnerDoor and OwnerDoor:FindFirstChild("Door")
		return if Door and Door:IsA("BasePart") then Door else nil
	end

	local function PlayerOwnsTycoon()
		local ExpectedTitle = player.Name .. "'s Tycoon"
		for _, Tycoon in TycoonsFolder:GetChildren() do
			local MainItems = Tycoon:FindFirstChild("MainItems")
			local OwnerDoor = MainItems and MainItems:FindFirstChild("OwnerDoor")
			local Title = OwnerDoor and OwnerDoor:FindFirstChild("Title")
			local SurfaceGui = Title and Title:FindFirstChildOfClass("SurfaceGui")
			local Label = SurfaceGui and SurfaceGui:FindFirstChildOfClass("TextLabel")
			if Label and Label.Text == ExpectedTitle then
				return true
			end
		end

		return false
	end

	local function EnsureBeams()
		if PlayerOwnsTycoon() then
			CleanupPlayerData()
			return
		end
		local Character = player.Character
		if not Character then return end
		local RootPart = Character:FindFirstChild("HumanoidRootPart")
		if not RootPart then return end

		if BeamsActive then return end
		BeamsActive = true

		for _, Tycoon in TycoonsFolder:GetChildren() do
			local Door = GetOwnerDoor(Tycoon)
			if Door and Door.Transparency < 0.5 then

					local StartAttachment = Instance.new("Attachment")
					StartAttachment.Parent = RootPart  

					local EndAttachment = Instance.new("Attachment")
					EndAttachment.Parent = Door  

					local Beam = Instance.new("Beam")
					Beam.Attachment0 = EndAttachment
					Beam.Attachment1 = StartAttachment
					Beam.Parent = RootPart
					Beam.Color = ColorSequence.new(Color3.fromRGB(221, 255, 247))
					Beam.Transparency = NumberSequence.new(0)
					Beam.Width0 = 1
					Beam.Width1 = 1
					Beam.FaceCamera = true
					Beam.LightInfluence = 0
					Beam.Texture = "rbxassetid://9006027964"
					Beam.TextureMode = Enum.TextureMode.Wrap
					Beam.TextureSpeed = -11
					Beam.TextureLength = 1


					table.insert(PlayerData, StartAttachment)
					table.insert(PlayerData, EndAttachment)
					table.insert(PlayerData, Beam)
			end
		end
	end

	local function MonitorTycoonOwnership()
		for _, Tycoon in TycoonsFolder:GetChildren() do
			local Door = GetOwnerDoor(Tycoon)
			if Door then
				Door:GetPropertyChangedSignal("Transparency"):Connect(function()
					task.wait(0.1)
					CleanupPlayerData()
					EnsureBeams()
				end)
			end
		end
	end

	local function UpdateTycoonGuidance()
		if not PlayerOwnsTycoon() then
			EnsureBeams()
		else
			CleanupPlayerData()
		end
	end

	UpdateTycoonGuidance()

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		CleanupPlayerData()
		EnsureBeams()
	end)


	MonitorTycoonOwnership()
end)
	
	
	

	
	



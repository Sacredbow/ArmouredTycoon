--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenManager = require(ReplicatedStorage.Modules.TweenManager)
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer :: Player

-- Resolve UI folder path: script -> Components -> Shop -> HudCurrency -> components -> UI
local UI = script.Parent.Parent.Parent.Parent.Parent
local Format = require(UI.utils.Format)
local GameStore = require(UI.store.GameStore)

local Currency = {}

-- Animation constants
local AnimationDuration = 1.5
local CashGainColor = Color3.fromRGB(86, 255, 132)
local CashLossColor = Color3.fromRGB(255, 82, 82)
local CashAccentColor = Color3.fromRGB(255, 255, 255)

-- Per-label animation state
type AnimationState = {
	currentValue: number,
	connection: RBXScriptConnection?,
	animationId: number,
	shrinkThread: thread?,
	originalSizeX: number,
	originalSizeY: number,
}

local cashState: AnimationState = {
	currentValue = 0,
	connection = nil,
	animationId = 0,
	shrinkThread = nil,
	originalSizeX = 0,
	originalSizeY = 0,
}

local sapphireState: AnimationState = {
	currentValue = 0,
	connection = nil,
	animationId = 0,
	shrinkThread = nil,
	originalSizeX = 0,
	originalSizeY = 0,
}

local function animateCurrency(
	label: TextLabel,
	targetValue: number,
	formatFn: (number) -> string,
	state: AnimationState
)
	local startValue = state.currentValue
	if startValue == targetValue then
		label.Text = formatFn(math.round(targetValue))
		return
	end

	state.animationId += 1
	local myId = state.animationId
	local startTime = os.clock()
	local changeColor = if targetValue > startValue then CashGainColor else CashLossColor

	if state.connection then
		state.connection:Disconnect()
		state.connection = nil
	end

	-- Capture the true original size from the state (set once in Init)
	local originalSizeX = state.originalSizeX
	local originalSizeY = state.originalSizeY

	-- Cancel any pending shrink tween from a previous animation
	if state.shrinkThread then
		task.cancel(state.shrinkThread)
		state.shrinkThread = nil
	end

	-- Size pulse: briefly enlarge from the true original size
	TweenManager.Interface(
		label,
		({ Size = UDim2.fromScale(originalSizeX * 1.15, originalSizeY * 1.15) }) :: any,
		TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		function() end
	)

	
	state.shrinkThread = task.spawn(function() 
		task.wait(1.5)
		state.shrinkThread = nil
		TweenManager.Interface(
			label,
			({ Size = UDim2.fromScale(originalSizeX, originalSizeY) }) :: any,
			TweenInfo.new(0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			function() end
		)
	end)

	state.connection = RunService.RenderStepped:Connect(function()
		if state.animationId ~= myId then
			return
		end

		local alpha = math.clamp((os.clock() - startTime) / AnimationDuration, 0, 1)
		local easedAlpha = alpha * alpha * (3 - 2 * alpha)
		local value = startValue + (targetValue - startValue) * easedAlpha
		local colorReturnAlpha = math.clamp((alpha - 0.82) / 0.18, 0, 1)
		local color = changeColor:Lerp(CashAccentColor, colorReturnAlpha)

		state.currentValue = value
		label.Text = formatFn(math.round(value))
		label.TextColor3 = color

		if alpha >= 1 then
			state.currentValue = targetValue
			label.Text = formatFn(math.round(targetValue))
			label.TextColor3 = CashAccentColor
			if state.connection then
				state.connection:Disconnect()
				state.connection = nil
			end
		end
	end)
end

function Currency.Init()
	
	local playerGui = player:WaitForChild("PlayerGui")  :: typeof(player.PlayerGui)

	local mainInterface = playerGui:WaitForChild("MainInterface") 
	local currencyFolder = mainInterface:WaitForChild("Currency")
	
	local cashFrame = currencyFolder:WaitForChild("CashFrame")
	local sapphireFrame = currencyFolder:WaitForChild("SapphireFrame")

	local cashLabel = cashFrame:WaitForChild("CashLabel") :: TextLabel
	local sapphireLabel = sapphireFrame:WaitForChild("SapphireLabel") :: TextLabel

	-- Capture original label sizes before any animation runs
	cashState.originalSizeX = cashLabel.Size.X.Scale
	cashState.originalSizeY = cashLabel.Size.Y.Scale
	sapphireState.originalSizeX = sapphireLabel.Size.X.Scale
	sapphireState.originalSizeY = sapphireLabel.Size.Y.Scale
	

	local store = GameStore.get() 

	local function updateUI()
		local snapshot = store:GetSnapshot()
		local cash = snapshot.stats.Cash
		local emerald = snapshot.stats.Emerald

		animateCurrency(cashLabel, cash, Format.currency, cashState)
		animateCurrency(sapphireLabel, emerald, Format.compactNumber, sapphireState)
	end

	-- Initial update
	updateUI()

	-- Subscribe to store changes
	store:Subscribe(updateUI)

	-- Wire up shop buttons via BindableEvent
	local openShopSignal = ReplicatedStorage:FindFirstChild("OpenShopSignal")
	
	if openShopSignal and openShopSignal:IsA("BindableEvent") then
		local cashShop = cashFrame:FindFirstChild("CashShop")
		local sapphireShop = sapphireFrame:FindFirstChild("SapphireShop")

		if cashShop and cashShop:IsA("ImageButton") then
			cashShop.MouseButton1Click:Connect(function()
				openShopSignal:Fire("Money")
			end)
			
		else
		end

		if sapphireShop and sapphireShop:IsA("ImageButton") then
			sapphireShop.MouseButton1Click:Connect(function()
				openShopSignal:Fire("Money")
			end)
		end
	end

	-- Wire up menu and profile buttons via BindableEvents
	local openMenuSignal = ReplicatedStorage:FindFirstChild("OpenMenuSignal")
	local openProfileSignal = ReplicatedStorage:FindFirstChild("OpenProfileSignal")
	local actions = mainInterface.Actions
	local menuButton =   actions:FindFirstChild("MenuButton")
	local profileButton =  actions:FindFirstChild("ProfileButton")
	
	if openMenuSignal and openMenuSignal:IsA("BindableEvent") then
		
		if menuButton and menuButton:IsA("ImageButton") then
			
			
			menuButton.MouseButton1Click:Connect(function()
				openMenuSignal:Fire()
			end)
			
			
		end
	end


	if openProfileSignal and openProfileSignal:IsA("BindableEvent") then
		

		if profileButton and profileButton:IsA("ImageButton") then
			
			
			profileButton.MouseButton1Click:Connect(function()
				openProfileSignal:Fire() 
			end)
			
			
		end
	end
	
	-- Positioning 
	if UserInputService.TouchEnabled then
		profileButton.Position = UDim2.fromScale(0.001, 0.26)
		menuButton.Position = UDim2.fromScale(0.001, 0.34)
	end
end




return Currency

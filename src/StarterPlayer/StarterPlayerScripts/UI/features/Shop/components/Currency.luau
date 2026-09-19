--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenManager = require(ReplicatedStorage.Modules.TweenManager)
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer :: Player

-- Resolve UI folder path: script -> components -> Shop -> features -> UI
local UI = script.Parent.Parent.Parent.Parent
local Format = require(UI.shared.Format)
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

function Currency.Mount(Callbacks: {
	OpenShop: (Tab: string) -> (),
	OpenMenu: () -> (),
	OpenProfile: () -> (),
}): () -> ()
	local PlayerGui = player:WaitForChild("PlayerGui") :: typeof(player.PlayerGui)
	local MainInterface = PlayerGui:WaitForChild("MainInterface")
	local CurrencyFolder = MainInterface:WaitForChild("Currency")
	local Actions = MainInterface:WaitForChild("Actions")

	local CashFrame = CurrencyFolder:WaitForChild("CashFrame")
	local SapphireFrame = CurrencyFolder:WaitForChild("SapphireFrame")
	local CashLabel = CashFrame:WaitForChild("CashLabel") :: TextLabel
	local SapphireLabel = SapphireFrame:WaitForChild("SapphireLabel") :: TextLabel
	local MenuButton = Actions:FindFirstChild("MenuButton")
	local ProfileButton = Actions:FindFirstChild("ProfileButton")

	cashState.originalSizeX = CashLabel.Size.X.Scale
	cashState.originalSizeY = CashLabel.Size.Y.Scale
	sapphireState.originalSizeX = SapphireLabel.Size.X.Scale
	sapphireState.originalSizeY = SapphireLabel.Size.Y.Scale

	local Store = GameStore.get()
	local Connections: { RBXScriptConnection } = {}
	local StoreCleanup = Store:Subscribe(function()
		local Snapshot = Store:GetSnapshot()
		animateCurrency(CashLabel, Snapshot.stats.Cash, Format.currency, cashState)
		animateCurrency(SapphireLabel, Snapshot.stats.Emerald, Format.compactNumber, sapphireState)
	end)

	local function Bind(Button: Instance?, Callback: () -> ())
		if Button and Button:IsA("GuiButton") then
			table.insert(Connections, Button.Activated:Connect(Callback))
		end
	end

	local CashShop = CashFrame:FindFirstChild("CashShop")
	local SapphireShop = SapphireFrame:FindFirstChild("SapphireShop")
	Bind(CashShop, function()
		Callbacks.OpenShop("Money")
	end)
	Bind(SapphireShop, function()
		Callbacks.OpenShop("Money")
	end)
	Bind(MenuButton, Callbacks.OpenMenu)
	Bind(ProfileButton, Callbacks.OpenProfile)

	if UserInputService.TouchEnabled then
		if ProfileButton and ProfileButton:IsA("GuiObject") then
			ProfileButton.Position = UDim2.fromScale(0.001, 0.26)
		end
		if MenuButton and MenuButton:IsA("GuiObject") then
			MenuButton.Position = UDim2.fromScale(0.001, 0.34)
		end
	end

	local Snapshot = Store:GetSnapshot()
	animateCurrency(CashLabel, Snapshot.stats.Cash, Format.currency, cashState)
	animateCurrency(SapphireLabel, Snapshot.stats.Emerald, Format.compactNumber, sapphireState)

	return function()
		StoreCleanup()
		for _, Connection in Connections do
			Connection:Disconnect()
		end
		if cashState.connection then
			cashState.connection:Disconnect()
			cashState.connection = nil
		end
		if sapphireState.connection then
			sapphireState.connection:Disconnect()
			sapphireState.connection = nil
		end
		if cashState.shrinkThread then
			task.cancel(cashState.shrinkThread)
			cashState.shrinkThread = nil
		end
		if sapphireState.shrinkThread then
			task.cancel(sapphireState.shrinkThread)
			sapphireState.shrinkThread = nil
		end
	end
end

return Currency

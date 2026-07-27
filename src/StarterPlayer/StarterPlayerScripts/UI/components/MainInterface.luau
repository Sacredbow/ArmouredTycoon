
local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.react)

local QuestOptions = require(ReplicatedStorage.Progression.Quests.QuestOptions)
local useGameStore = require(script.Parent.Parent.store.useGameStore)
local ClientSignals = require(ReplicatedStorage.Network.ClientSignals)

local e = React.createElement

type ShopTab = "Money" | "Passes" | "Boosts"
type Modal = "None" | "Shop" | "Codes" | "Lootbox" | "Profile" | "Quests" | "Daily" | "Rebirth" | "Settings"
type Stats = {
	Cash: number,
	Emerald: number,
	Kills: number,
	Rebirths: number,
	Level: number,
	Experience: number,
}

type QuestProgress = {
	Progress: number,
	Completed: boolean,
	Claimed: boolean,
}

type ProfileState = {
	hydrated: boolean,
	level: number,
	experience: number,
	requiredExperience: number,
	dailyReadyAt: number,
	dailySecondsRemaining: number,
	dailyQuestSecondsRemaining: number,
	weeklyQuestSecondsRemaining: number,
	quests: { [string]: QuestProgress },
}

type MainInterfaceProps = {
	stats: Stats?,
	profile: ProfileState?,
}?

local function selectStats(snapshot)
	return snapshot.stats
end

local function selectProfile(snapshot)
	return snapshot.profile
end

local DEFAULT_PROFILE: ProfileState = {
	hydrated = false,
	level = 1,
	experience = 0,
	requiredExperience = 120,
	dailyReadyAt = 0,
	dailySecondsRemaining = 86400,
	dailyQuestSecondsRemaining = 86400,
	weeklyQuestSecondsRemaining = 604800,
	quests = QuestOptions.createProgressMap(),
}

local function getViewportSize(): Vector2
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end

	return Vector2.new(1280, 720)
end

local function computeInterfaceScale(viewportSize: Vector2): number
	local widthScale = viewportSize.X / 760
	local heightScale = viewportSize.Y / 620
	return math.clamp(math.min(widthScale, heightScale), 0.42, 1)
end

local function getBlur(): BlurEffect?
	local blur = Lighting:FindFirstChild("BackgroundBlur")
	if blur and blur:IsA("BlurEffect") then
		return blur
	end

	return nil
end

local function setBlur(size: number)
	local blur = getBlur()
	if blur then
		blur.Size = size
	end
end

local InterfaceModules = script.Parent.MainInterfaceModules
local InterfaceKit = require(InterfaceModules.InterfaceKit)
local CurrencyHud = require(InterfaceModules.CurrencyHud)
local ItemMenu = require(InterfaceModules.NavigationMenu)
local ShopPanel = require(InterfaceModules.ShopPanel)
local CodesPanel = require(InterfaceModules.CodesPanel)
local LootboxPanel = require(InterfaceModules.LootboxPanel)
local ProfilePanel = require(InterfaceModules.ProfilePanel)
local QuestPanels = require(InterfaceModules.QuestPanels)
local RebirthPanels = require(InterfaceModules.RebirthPanels)
local LevelUpPresentation = require(InterfaceModules.LevelUpPresentation)
local SettingsPanel = require(InterfaceModules.SettingsPanel)

local QuestsPanel = QuestPanels.Quests
local DailyPanel = QuestPanels.Daily
local RebirthButton = RebirthPanels.Button
local RebirthConfirmPanel = RebirthPanels.Confirmation
local corner = InterfaceKit.Corner
local noticeGradient = InterfaceKit.NoticeGradient
local solidButton = InterfaceKit.SolidButton
local SwatGamepassId = 1573236427

local function MainInterface(props: MainInterfaceProps)
	local resolvedProps: { stats: Stats?, profile: ProfileState? } = props or {
		stats = nil,
		profile = nil,
	}

	local stats: Stats = resolvedProps.stats or useGameStore(selectStats :: any)
	local profile: ProfileState = resolvedProps.profile or useGameStore(selectProfile :: any) or DEFAULT_PROFILE
	local modal, setModal = React.useState("None" :: Modal)
	local menuOpen, setMenuOpen = React.useState(false)
	local shopTab, setShopTab = React.useState("Money" :: ShopTab)
	local selectedItem, setSelectedItem = React.useState(nil)
	local codeText, setCodeText = React.useState("")
	local feedbackText, setFeedbackText = React.useState(nil :: string?)
	local feedbackColor, setFeedbackColor = React.useState(Color3.fromRGB(255, 255, 255))
	local profileImage, setProfileImage = React.useState("rbxasset://textures/ui/GuiImagePlaceholder.png")
	local lastSeenLevel, setLastSeenLevel = React.useState(profile.level)
	local profileBaselineAccepted = React.useRef(false)
	local levelUpVisible, setLevelUpVisible = React.useState(false)
	local uiScale, setUiScale = React.useState(computeInterfaceScale(getViewportSize()))
	local canRebirth, setCanRebirth = React.useState(false)

	local function closeModal()
		setModal("None")
		setBlur(0)
	end

	local function openShop(defaultTab: ShopTab)
		setShopTab(defaultTab)
		setSelectedItem(nil)
		setMenuOpen(false)
		setModal("Shop")
		setBlur(0)
	end

	local function openCodes()
		setMenuOpen(false)
		setModal("Codes")
		setBlur(0)
	end

	local function openStats()
		setMenuOpen(false)
		setModal("Profile")
		setBlur(24)
	end

	local function openQuests()
		setMenuOpen(false)
		setModal("Quests")
		setBlur(24)
	end

	local function openDaily()
		setMenuOpen(false)
		setModal("Daily")
		setBlur(24)
	end

	local function openSettings()
		setMenuOpen(false)
		setModal("Settings")
		setBlur(24)
	end

	React.useEffect(function()
		local connections = {}

		local function updateScale()
			setUiScale(computeInterfaceScale(getViewportSize()))
		end

		local function connectCamera(camera)
			if camera then
				table.insert(connections, camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
			end
		end

		connectCamera(workspace.CurrentCamera)
		table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			connectCamera(workspace.CurrentCamera)
			updateScale()
		end))
		updateScale()

		return function()
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
		end
	end, {})

	React.useEffect(function()
		local connection = ClientSignals.Listen(function(kind: string, value: any?)
			if kind == "CanRebirth" then
				setCanRebirth(value == true)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		if not profile.hydrated then
			setLastSeenLevel(profile.level)
			return
		end

		if not profileBaselineAccepted.current then
			profileBaselineAccepted.current = true
			setLastSeenLevel(profile.level)
			return
		end

		if profile.level > lastSeenLevel then
			setLevelUpVisible(true)
			task.delay(3, function()
				setLevelUpVisible(false)
			end)
		end
		setLastSeenLevel(profile.level)
	end, { profile.hydrated, profile.level })

	React.useEffect(function()
		local connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end
			if input.KeyCode == Enum.KeyCode.M and modal == "None" then
				setMenuOpen(true)
				setBlur(24)
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, { modal })

	React.useEffect(function()
		task.spawn(function()
			local localPlayer = Players.LocalPlayer
			local scopedUser = (localPlayer :: any).User or localPlayer.UserId
			local ok, content = pcall(function()
				return Players:GetUserThumbnailAsync(scopedUser, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
			end)
			if ok then
				setProfileImage(content)
			end
		end)
	end, {})

	React.useEffect(function()
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local connections = {}

		table.insert(connections, ClientSignals.Listen(function(request, value)
			if request == "NotFollowing" then
				setMenuOpen(false)
				setModal("Lootbox")
			elseif request == "Prompt" then
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, SwatGamepassId)
			elseif request == "Rain" then
				local store = require(script.Parent.Parent.store.GameStore).get()
				local typedStore: any = store
				typedStore:PushNotification("info", "Rain is moving through the area.", 4)
			elseif request == "SystemMessage" and typeof(value) == "string" then
				local general = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
				if general then
					general:DisplaySystemMessage(value)
				end
			end
		end))


		return function()
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
		end
	end, {})

	React.useEffect(function()
		local openShopSignal = ReplicatedStorage:FindFirstChild("OpenShopSignal")
		if not openShopSignal or not openShopSignal:IsA("BindableEvent") then
			return
		end

		local connection = openShopSignal.Event:Connect(function(tab)
			openShop(tab)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local openMenuSignal = ReplicatedStorage:FindFirstChild("OpenMenuSignal")
		if not openMenuSignal or not openMenuSignal:IsA("BindableEvent") then
			return
		end

		local connection = openMenuSignal.Event:Connect(function()
			if modal ~= "None" then
				return
			end
			setMenuOpen(true)
			setBlur(24)
		end)

		return function()
			connection:Disconnect()
		end
	end, { modal })

	React.useEffect(function()
		local openProfileSignal = ReplicatedStorage:FindFirstChild("OpenProfileSignal")
		if not openProfileSignal or not openProfileSignal:IsA("BindableEvent") then
			return
		end

		local connection = openProfileSignal.Event:Connect(function()
			openStats()
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	local function redeemCode()
		if codeText == "" then
			return
		end

		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local redeemFunction = remotes and remotes:FindFirstChild("CodeServiceFunction")
		if not redeemFunction or not redeemFunction:IsA("RemoteFunction") then
			setFeedbackText("Codes are unavailable.")
			setFeedbackColor(Color3.fromRGB(255, 0, 0))
			return
		end

		local success = false
		local message = nil
		local ok = pcall(function()
			success, message = redeemFunction:InvokeServer(codeText)
		end)

		if ok and success then
			if codeText == "R3L3ASE" then
				setFeedbackText("Earned $5000!")
			elseif codeText == "STARTER" then
				setFeedbackText("Earned $10000!")
			elseif codeText == "FR33MULTI" then
				setFeedbackText("Given a 1.5x Multiplier!")
			else
				setFeedbackText("Code redeemed!")
			end
			setFeedbackColor(Color3.fromRGB(0, 170, 0))
			setCodeText("")
		else
			setFeedbackText(tostring(message or "Already redeemed or invalid code."))
			setFeedbackColor(Color3.fromRGB(255, 0, 0))
		end

		task.delay(2.5, function()
			setFeedbackText(nil :: any)
		end)
	end

	local function invokeProfileAction(action: string, payload: any?)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local profileAction = remotes and remotes:FindFirstChild("ProfileAction")
		if not profileAction or not profileAction:IsA("RemoteFunction") then
			local store = require(script.Parent.Parent.store.GameStore).get()
			local typedStore: any = store
			typedStore:PushNotification("error", "Profile rewards are unavailable.")
			return
		end

		local success = false
		local message = "Unable to claim reward."
		local ok = pcall(function()
			success, message = profileAction:InvokeServer(action, payload)
		end)

		local store = require(script.Parent.Parent.store.GameStore).get()
		local typedStore: any = store
		if ok and success then
			typedStore:PushNotification("success", tostring(message))
		else
			typedStore:PushNotification("error", tostring(message))
		end
	end

	local function invokeTycoonAction(action: string)
		local remotes = ReplicatedStorage:FindFirstChild("Remotes")
		local tycoonAction = remotes and remotes:FindFirstChild("TycoonAction")
		if not tycoonAction or not tycoonAction:IsA("RemoteFunction") then
			local store = require(script.Parent.Parent.store.GameStore).get()
			local typedStore: any = store
			typedStore:PushNotification("error", "Tycoon actions are unavailable.")
			return
		end

		local success = false
		local message = "Unable to perform tycoon action."
		local ok = pcall(function()
			success, message = tycoonAction:InvokeServer(action)
		end)

		local store = require(script.Parent.Parent.store.GameStore).get()
		local typedStore: any = store
		if ok and success then
			typedStore:PushNotification("success", tostring(message))
			setModal("None")
			setBlur(0)
		else
			typedStore:PushNotification("error", tostring(message))
		end
	end

	return e(React.Fragment, nil, {
		-- Currency HUD migrated to Workspace-based GUI (Hud/Shop/Components/Currency)
		-- Currency = e(CurrencyHud, {
		-- 	stats = stats,
		-- 	hidden = modal == "Profile",
		-- 	uiScale = uiScale,
		-- 	openShop = openShop,
		-- 	openMenu = function()
		-- 		if modal ~= "None" then
		-- 			return
		-- 		end
		-- 		setMenuOpen(true)
		-- 		setBlur(24)
		-- 	end,
		-- 	openStats = openStats,
		-- }),
		Menu = e(ItemMenu, {
			open = menuOpen,
			uiScale = uiScale,
			openShop = openShop,
			openCodes = openCodes,
			openQuests = openQuests,
			openDaily = openDaily,
			openSettings = openSettings,
			closeMenu = function()
				setMenuOpen(false)
				setBlur(0)
			end,
		}),
		Sprint = solidButton({
			Name = "SprintButton",
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.fromRGB(21, 31, 46),
			Font = Enum.Font.GothamBold,
			Position = UDim2.new(0, 22, 1, -24),
			Size = UDim2.fromOffset(116, 56),
			Text = "SPRINT",
			TextColor3 = Color3.fromRGB(230, 244, 255),
			TextScaled = false,
			TextSize = 16,
			Visible = UserInputService.TouchEnabled and modal == "None",
		}, {
			Scale = e("UIScale", {
				Scale = uiScale,
			}),
			Corner = corner(18),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 255, 255),
				Thickness = 1.5,
				Transparency = 0.22,
			}),
			Gradient = noticeGradient(),
		}),
		RebirthButton = e(RebirthButton, {
			visible = canRebirth and modal == "None",
			uiScale = uiScale,
			onActivated = function()
				setMenuOpen(false)
				setModal("Rebirth")
				setBlur(24)
			end,
		}),
		Shop = e(ShopPanel, {
			visible = modal == "Shop",
			tab = shopTab,
			setTab = setShopTab,
			selectedItem = selectedItem,
			setSelectedItem = setSelectedItem,
			uiScale = uiScale,
			close = closeModal,
		}),
		Codes = e(CodesPanel, {
			visible = modal == "Codes",
			codeText = if feedbackText then codeText else codeText,
			setCodeText = setCodeText,
			feedbackText = feedbackText,
			feedbackColor = feedbackColor,
			redeem = redeemCode,
			uiScale = uiScale,
			close = closeModal,
		}),
		Lootbox = e(LootboxPanel, {
			visible = modal == "Lootbox",
			profileImage = profileImage,
			uiScale = uiScale,
			close = closeModal,
		}),
		Profile = e(ProfilePanel, {
			visible = modal == "Profile",
			stats = stats,
			profile = profile,
			profileImage = profileImage,
			uiScale = uiScale,
			close = closeModal,
		}),
		Quests = e(QuestsPanel, {
			visible = modal == "Quests",
			profile = profile,
			uiScale = uiScale,
			claimQuest = function(questId: string)
				invokeProfileAction("ClaimQuest", questId)
			end,
			close = closeModal,
		}),
		Daily = e(DailyPanel, {
			visible = modal == "Daily",
			profile = profile,
			uiScale = uiScale,
			claimDaily = function()
				invokeProfileAction("ClaimDaily", nil)
			end,
			close = closeModal,
		}),
		Rebirth = e(RebirthConfirmPanel, {
			visible = modal == "Rebirth",
			uiScale = uiScale,
			close = closeModal,
			confirm = function()
				invokeTycoonAction("Rebirth")
			end,
		}),
		Settings = e(SettingsPanel, {
			visible = modal == "Settings",
			uiScale = uiScale,
			close = closeModal,
		}),
		LevelUp = e(LevelUpPresentation, {
			visible = levelUpVisible,
			level = profile.level,
			uiScale = uiScale,
		}),
	})
end

return MainInterface




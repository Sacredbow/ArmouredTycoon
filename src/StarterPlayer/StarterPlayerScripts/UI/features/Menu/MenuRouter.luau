local Lighting = game:GetService("Lighting")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local React = require(ReplicatedStorage.Packages.react)

local QuestOptions = require(ReplicatedStorage.Progression.QuestOptions)
local useGameStore = require(script.Parent.Parent.Parent.store.useGameStore)
local useViewportScale = require(script.Parent.Parent.Parent.hooks.useViewportScale)
local Currency = require(script.Parent.Parent.Shop.components.Currency)
local Packets = require(ReplicatedStorage.Network.Packets)

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

type MenuRouterProps = {
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

local InterfaceKit = require(script.Parent.Parent.Parent.shared.InterfaceKit)

local ItemMenu = require(script.Parent.components.NavigationMenu)
local ShopPanel = require(script.Parent.Parent.Shop.components.ShopPanel)
local CodesPanel = require(script.Parent.Parent.Shop.components.CodesPanel)
local LootboxPanel = require(script.Parent.Parent.Shop.components.LootboxPanel)
local ProfilePanel = require(script.Parent.Parent.Player.ProfileView)
local QuestPanels = require(script.Parent.Parent.Progression.QuestPanels)
local RebirthPanels = require(script.Parent.Parent.Player.components.RebirthPanels)
local LevelUpPresentation = require(script.Parent.Parent.Progression.LevelUpPresentation)
local SettingsPanel = require(script.Parent.components.SettingsPanel)

local QuestsPanel = QuestPanels.Quests
local DailyPanel = QuestPanels.Daily
local RebirthButton = RebirthPanels.Button
local RebirthConfirmPanel = RebirthPanels.Confirmation
local corner = InterfaceKit.Corner
local noticeGradient = InterfaceKit.NoticeGradient
local solidButton = InterfaceKit.SolidButton
local SwatGamepassId = 1573236427

local store = require(script.Parent.Parent.Parent.store.GameStore).get()

local function MenuRouter(props: MenuRouterProps)
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
	local uiScale = useViewportScale()
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
		return Currency.Mount({
			OpenShop = openShop,
			OpenMenu = function()
				if modal == "None" then
					setMenuOpen(true)
					setBlur(24)
				end
			end,
			OpenProfile = openStats,
		})
	end, {})

	-- Replaces the old ClientSignals.Listen(kind == "CanRebirth") branch.
	React.useEffect(function()
		local connection = Packets.packets.GameEvent.listen(function(data)
			if data.type == "CanRebirth" then
				setCanRebirth(true)
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
				return Players:GetUserThumbnailAsync(
					scopedUser,
					Enum.ThumbnailType.HeadShot,
					Enum.ThumbnailSize.Size420x420
				)
			end)
			if ok then
				setProfileImage(content)
			end
		end)
	end, {})

	-- Replaces the old second ClientSignals.Listen block.
	-- "Rain" removed: GameStore's Weather listener already owns that notification.
	-- "Teleporting" removed: GameStore's messageByKind now owns that notification.
	-- NotFollowing / Prompt / SystemMessage remain here since they're UI actions,
	-- not toasts, and GameStore explicitly ignores these types for that reason.
	React.useEffect(function()
		local connection = Packets.packets.GameEvent.listen(function(data)
			if data.type == "NotFollowing" then
				setMenuOpen(false)
				setModal("Lootbox")
			elseif data.type == "Prompt" then
				MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, SwatGamepassId)
			elseif data.type == "SystemMessage" and data.message then
				local general = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
				if general then
					general:DisplaySystemMessage(data.message)
				end
			end
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	local function redeemCode()
		if codeText == "" then
			return
		end

		local ok, result = pcall(function()
			return Packets.queries.RedeemCode.invoke({ code = codeText })
		end)

		if ok and result then
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
			setFeedbackText(tostring((result or {}).message or "Already redeemed or invalid code."))
			setFeedbackColor(Color3.fromRGB(255, 0, 0))
		end

		task.delay(2.5, function()
			setFeedbackText(nil :: any)
		end)
	end

	local function invokeProfileAction(action: string, payload: any?)
		local store = require(script.Parent.Parent.Parent.store.GameStore).get()

		local ok, result = pcall(function()
			return Packets.queries.ProfileAction.invoke({
				action = action,
				payload = if type(payload) == "string" then payload else nil,
			})
		end)

		if ok and result then
			if result.success then
				store:PushNotification("success", tostring(result.message))
			else
				store:PushNotification("error", tostring(result.message))
			end
		else
			store:PushNotification("error", "Profile rewards are unavailable.")
		end
	end

	local function invokeTycoonAction(action: string)
		local store = require(script.Parent.Parent.Parent.store.GameStore).get()

		local ok, result = pcall(function()
			return Packets.queries.TycoonAction.invoke({ action = action })
		end)

		if ok and result then
			if result.success then
				store:PushNotification("success", tostring(result.message))
				if action == "Rebirth" then
					setCanRebirth(false)
				end
				setModal("None")
				setBlur(0)
			else
				store:PushNotification("error", tostring(result.message))
			end
		else
			store:PushNotification("error", "Tycoon actions are unavailable.")
		end
	end

	return e(React.Fragment, nil, {
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

return MenuRouter

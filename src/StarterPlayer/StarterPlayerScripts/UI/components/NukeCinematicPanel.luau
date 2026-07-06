--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)

local Theme = require(script.Parent.Parent.theme.Theme)
local useSpringBinding = require(script.Parent.Parent.hooks.useSpringBinding)

local e = React.createElement
local localPlayer = Players.LocalPlayer
local cachedPackets = nil
local nextPacketsRetryAt = 0

local function packetsNamespaceReady(): boolean
	local storage = ReplicatedStorage:FindFirstChild("BytenetStorage")
	local namespaceValue = storage and storage:FindFirstChild("ArmouredTycoon")
	return namespaceValue ~= nil and namespaceValue:IsA("StringValue") and namespaceValue.Value ~= ""
end

local function getPackets()
	if RunService:IsStudio() and not RunService:IsRunning() then
		return nil
	end

	if not packetsNamespaceReady() then
		return nil
	end

	if os.clock() < nextPacketsRetryAt then
		return nil
	end

	if not cachedPackets then
		local ok, result = pcall(function()
			return require(ReplicatedStorage.Network.Packets)
		end)
		if not ok then
			nextPacketsRetryAt = os.clock() + 2
			return nil
		end
		cachedPackets = result
	end

	return cachedPackets
end

local CLICK_BATCH_INTERVAL = 0.18
local CALLSIGNS = {
	"KEEP CLICKING",
	"ARMOUR CORE NEEDS INPUT",
	"DON'T LET THEM WIN",
	"DEFLECTION FIELD RISING",
	"BREAK THE LOCK",
	"YOU ARE ALMOST THERE",
	"THE STRIKE IS LOSING FORCE",
	"FINAL IMPACT WINDOW",
	"DO NOT STOP",
	"COUNTERFORCE CLIMBING",
}

local function selectNuke(snapshot)
	return snapshot.nukeCinematic
end

local function getQuote(score: number): string
	if score >= 100 then
		return "FIELD MAXED"
	elseif score >= 88 then
		return "FINAL PUSH"
	end

	return CALLSIGNS[(math.floor(score / 10) % #CALLSIGNS) + 1]
end

local function getRootPosition(): Vector3?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root.Position
	end

	return nil
end

local function avatarImage(userId: string?): string
	if not userId or userId == "" then
		return ""
	end

	return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local function playerBadge(name: string?, userId: string?, score: number, color: Color3, anchorPoint: Vector2, position: UDim2)
	local fill = math.clamp(score / 100, 0, 1)
	return e("Frame", {
		AnchorPoint = anchorPoint,
		BackgroundTransparency = 1,
		Position = position,
		Size = UDim2.fromOffset(180, 170),
	}, {
		Avatar = e("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundColor3 = Color3.fromRGB(8, 10, 14),
			BorderSizePixel = 0,
			Image = avatarImage(userId),
			Position = UDim2.new(0.5, 0, 0, 0),
			ScaleType = Enum.ScaleType.Crop,
			Size = UDim2.fromOffset(92, 92),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e("UIStroke", {
				Color = color,
				Thickness = 3,
				Transparency = 0.05,
			}),
		}),
		Score = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Position = UDim2.new(0.5, 0, 0, 98),
			Size = UDim2.new(1, 0, 0, 34),
			Text = tostring(score),
			TextColor3 = color,
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.08,
		}, {
			SizeLimit = e("UITextSizeConstraint", {
				MaxTextSize = 32,
				MinTextSize = 16,
			}),
		}),
		Name = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Body,
			Position = UDim2.new(0.5, 0, 0, 132),
			Size = UDim2.new(1, 0, 0, 20),
			Text = string.upper(name or "UNKNOWN"),
			TextColor3 = Color3.fromRGB(238, 242, 248),
			TextSize = 13,
			TextTruncate = Enum.TextTruncate.AtEnd,
		}),
		Track = e("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundColor3 = Color3.fromRGB(12, 14, 19),
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, 0),
			Size = UDim2.new(0.88, 0, 0, 7),
		}, {
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Fill = e("Frame", {
				BackgroundColor3 = color,
				BorderSizePixel = 0,
				Size = UDim2.new(fill, 0, 1, 0),
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
		}),
	})
end

local function NukeCinematicPanel(props)
	props = props or {}

	local nuke = props.nuke
	if not nuke then
		local useGameStore = require(script.Parent.Parent.store.useGameStore)
		nuke = useGameStore(selectNuke)
	end

	local localClicks = React.useRef(0)
	local lastFlush = React.useRef(os.clock())
	local visible = nuke ~= nil
	local progress = useSpringBinding(if visible then 1 else 0, 18, 0)
	local currentScore = if nuke then (if nuke.role == "launcher" then nuke.launcherScore or 0 else nuke.defenderScore or 0) else 0
	local chargeProgress = useSpringBinding(math.clamp(currentScore / 100, 0, 1), 20, 0)

	React.useEffect(function()
		if not nuke or nuke.action == "End" then
			return nil
		end

		local sessionId = nuke.sessionId
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(CLICK_BATCH_INTERVAL)
				local count = localClicks.current
				local now = os.clock()
				local window = now - lastFlush.current
				localClicks.current = 0
				lastFlush.current = now

				if count > 0 then
					local Packets = getPackets()
					if Packets then
						Packets.packets.NukeClickBatch.send({
							sessionId = sessionId,
							count = count,
							clientWindow = window,
						})
					end
				end
			end
		end)

		return function()
			alive = false
		end
	end, { if nuke then nuke.sessionId else "" })

	if not nuke then
		return nil
	end

	local launcherScore = nuke.launcherScore or 0
	local defenderScore = nuke.defenderScore or 0
	local ownScore = if nuke.role == "launcher" then launcherScore else defenderScore
	local mashActive = nuke.action == "MashStart" or launcherScore > 0 or defenderScore > 0
	local resultActive = nuke.action == "Result"
	local won = resultActive and nuke.winnerName == localPlayer.Name
	local rangeText = ""
	local rangeColor = Color3.fromRGB(255, 238, 220)
	local rootPosition = getRootPosition()
	if rootPosition and nuke.targetPosition and nuke.deathRange then
		local playerDistance = (rootPosition - nuke.targetPosition).Magnitude
		local kilometers = playerDistance / 1000
		local deathKilometers = nuke.deathRange / 1000
		if playerDistance <= nuke.deathRange then
			rangeText = `DEATH RANGE: {string.format("%.2f", kilometers)} KM / {string.format("%.2f", deathKilometers)} KM`
			rangeColor = Color3.fromRGB(255, 78, 58)
		else
			rangeText = `OUTSIDE CORE BLAST: {string.format("%.2f", kilometers)} KM`
			rangeColor = Color3.fromRGB(120, 210, 255)
		end
	end

	return e("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		GroupTransparency = progress:map(function(value)
			return 1 - value
		end),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, {
		TopBar = e("Frame", {
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.new(1, 0, 0, 72),
			Visible = mashActive,
		}),
		BottomBar = e("Frame", {
			AnchorPoint = Vector2.new(0, 1),
			BackgroundColor3 = Color3.fromRGB(0, 0, 0),
			BackgroundTransparency = 0.05,
			BorderSizePixel = 0,
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 92),
			Visible = mashActive,
		}),
		Header = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Position = UDim2.new(0.5, 0, 0, 42),
			Size = UDim2.new(0.86, 0, 0, 48),
			Text = string.upper(nuke.message or "NUCLEAR INBOUND"),
			TextColor3 = if resultActive then (if won then Color3.fromRGB(80, 255, 135) else Color3.fromRGB(255, 70, 70)) else Color3.fromRGB(255, 236, 218),
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.06,
		}, {
			SizeLimit = e("UITextSizeConstraint", {
				MaxTextSize = 42,
				MinTextSize = 16,
			}),
		}),
		Range = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Position = UDim2.new(0.5, 0, 0, 92),
			Size = UDim2.new(0.82, 0, 0, 26),
			Text = rangeText,
			TextColor3 = rangeColor,
			TextSize = 18,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.18,
			Visible = rangeText ~= "" and not resultActive,
		}),
		Launcher = playerBadge(nuke.launcherName, nuke.launcherUserId, launcherScore, Color3.fromRGB(255, 108, 45), Vector2.new(0, 0.5), UDim2.new(0, 58, 0.5, 42)),
		Defender = playerBadge(nuke.defenderName, nuke.defenderUserId, defenderScore, Color3.fromRGB(90, 195, 255), Vector2.new(1, 0.5), UDim2.new(1, -58, 0.5, 42)),
		Button = e("TextButton", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			AutoButtonColor = true,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BorderSizePixel = 0,
			Font = Theme.Fonts.Display,
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(220, 220),
			Text = "",
			TextTransparency = 1,
			Visible = mashActive and not resultActive,
			ZIndex = 80,
			[React.Event.Activated] = function()
				localClicks.current += 1
			end,
		}, {
			Aspect = e("UIAspectRatioConstraint", { AspectRatio = 1 }),
			Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			Stroke = e("UIStroke", {
				Color = Color3.fromRGB(255, 125, 45),
				Thickness = 5,
				Transparency = 0,
			}),
			Fill = e("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(255, 130, 45),
				BackgroundTransparency = 0.62,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = chargeProgress:map(function(value)
					local size = math.clamp(0.2 + value * 0.8, 0.2, 1)
					return UDim2.fromScale(size, size)
				end),
				ZIndex = 81,
			}, {
				Corner = e("UICorner", { CornerRadius = UDim.new(1, 0) }),
			}),
			Center = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Font = Theme.Fonts.Display,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.9, 0.44),
				Text = tostring(ownScore),
				TextColor3 = Color3.fromRGB(5, 7, 10),
				TextScaled = true,
				ZIndex = 82,
			}, {
				SizeLimit = e("UITextSizeConstraint", {
					MaxTextSize = 62,
					MinTextSize = 24,
				}),
			}),
			Caption = e("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundTransparency = 1,
				Font = Theme.Fonts.Body,
				Position = UDim2.new(0.5, 0, 1, -28),
				Size = UDim2.new(0.9, 0, 0, 18),
				Text = "CLICK",
				TextColor3 = Color3.fromRGB(24, 27, 32),
				TextSize = 14,
				ZIndex = 82,
			}),
			SizeLimit = e("UITextSizeConstraint", {
				MaxTextSize = 54,
				MinTextSize = 22,
			}),
		}),
		Quote = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Position = UDim2.new(0.5, 0, 0.5, 124),
			Size = UDim2.new(0.7, 0, 0, 32),
			Text = getQuote(ownScore),
			TextColor3 = Color3.fromRGB(255, 245, 235),
			TextSize = 24,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.18,
			Visible = mashActive and not resultActive,
		}),
		Result = e("TextLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			Position = UDim2.fromScale(0.5, 0.56),
			Size = UDim2.new(0.78, 0, 0, 82),
			Text = if won then "VICTORY" else "FAILED",
			TextColor3 = if won then Color3.fromRGB(80, 255, 135) else Color3.fromRGB(255, 70, 70),
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.04,
			Visible = resultActive,
		}),
	})
end

return NukeCinematicPanel

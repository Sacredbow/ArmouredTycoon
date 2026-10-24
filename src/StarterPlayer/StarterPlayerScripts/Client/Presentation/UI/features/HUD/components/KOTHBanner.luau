--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local Theme = require(script.Parent.Parent.Parent.Parent.shared.Theme)
local useSpringBinding = require(script.Parent.Parent.Parent.Parent.hooks.useSpringBinding)

local e = React.createElement

local ORANGE = Color3.fromRGB(255, 145, 42)

local function colorToHex(color: Color3): string
	return string.format(
		"#%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

local function selectKOTH(snapshot)
	return snapshot.kothAnnouncement
end

local function buildMessage(announcement): string
	local name = `<font color="{colorToHex(announcement.teamColor)}">{announcement.playerName}</font>`
	local orange = colorToHex(ORANGE)

	if announcement.minutes then
		return `<font color="{orange}">{name} has been King of the Hill for {announcement.minutes} minutes.</font>`
	end

	return `<font color="{orange}">{name} is now King of the Hill.</font>`
end

local function KOTHBanner(props)
	props = props or {}

	local announcement = props.announcement
	local store = nil
	if not announcement then
		local useGameStore = require(script.Parent.Parent.Parent.Parent.store.useGameStore)
		local GameStore = require(script.Parent.Parent.Parent.Parent.store.GameStore)
		announcement = useGameStore(selectKOTH)
		store = GameStore.get()
	end

	local visible, setVisible = React.useState(false)
	local progress = useSpringBinding(if visible then 1 else 0, 13, 0)

	React.useEffect(function()
		if not announcement then
			return nil
		end

		setVisible(true)

		local cancelled = false
		task.delay(announcement.duration, function()
			if not cancelled then
				setVisible(false)
				task.delay(0.25, function()
					if not cancelled and store then
						store.DismissKOTHAnnouncement(announcement.id)
					end
				end)
			end
		end)

		return function()
			cancelled = true
		end
	end, { if announcement then announcement.id else 0 })

	if not announcement then
		return nil
	end

	return e("CanvasGroup", {
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		GroupTransparency = progress:map(function(value)
			return 1 - value
		end),
		Position = progress:map(function(value)
			return UDim2.new(0.5, 0, 0, 26 - (1 - value) * 12)
		end),
		Size = UDim2.new(0, 760, 0, 42),
	}, {
		Text = e("TextLabel", {
			BackgroundTransparency = 1,
			Font = Theme.Fonts.Display,
			RichText = true,
			Size = UDim2.fromScale(1, 1),
			Text = buildMessage(announcement),
			TextScaled = true,
			TextStrokeColor3 = Color3.fromRGB(0, 0, 0),
			TextStrokeTransparency = 0.1,
			TextWrapped = false,
		}, {
			SizeLimit = e("UITextSizeConstraint", {
				MaxTextSize = 28,
				MinTextSize = 12,
			}),
		}),
	})
end

return KOTHBanner

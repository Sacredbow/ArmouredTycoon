local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local React = require(ReplicatedStorage.Packages.react)
local e = React.createElement

type ReactProps = { [any]: any }
type ReactChildren = { [any]: any }?

local function playSound(name: string)
	local sfx = SoundService:FindFirstChild("SFX")
	local sound = sfx and sfx:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		sound:Play()
	end
end

local function buttonProps(onActivated: (() -> ())?)
	return {
		AutoButtonColor = true,
		BorderSizePixel = 0,
		[React.Event.Activated] = function()
			playSound("ClickSound")
			if onActivated then
				onActivated()
			end
		end,
		[React.Event.MouseEnter] = function()
			playSound("HoverSound")
		end,
	}
end

local function corner(radius: number?)
	return e("UICorner", {
		CornerRadius = UDim.new(0, radius or 8),
	})
end

local function stroke(color: Color3?, thickness: number?)
	return e("UIStroke", {
		Color = color or Color3.fromRGB(0, 0, 0),
		Thickness = thickness or 2,
	})
end

local function gradient(first: Color3, second: Color3, rotation: number?)
	return e("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, first),
			ColorSequenceKeypoint.new(1, second),
		}),
		Rotation = rotation or 0,
	})
end

local function gradientRich(stops: { ColorSequenceKeypoint }, rotation: number?)
	return e("UIGradient", {
		Color = ColorSequence.new(stops),
		Rotation = rotation or 0,
	})
end

local function glassGradient(rotation: number?)
	return e("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.48, Color3.fromRGB(210, 220, 240)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.92),
			NumberSequenceKeypoint.new(0.5, 0.96),
			NumberSequenceKeypoint.new(1, 0.99),
		}),
		Rotation = rotation or 90,
	})
end

local function shimmerGradient(accent: Color3, rotation: number?)
	return e("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(0.5, accent),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.8),
			NumberSequenceKeypoint.new(0.5, 0.55),
			NumberSequenceKeypoint.new(1, 0.8),
		}),
		Rotation = rotation or 45,
	})
end

local function noticeGradient(rotation: number?)
	return e("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(10, 12, 18)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(14, 20, 16)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(8, 16, 12)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(6, 10, 8)),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.3, 0),
			NumberSequenceKeypoint.new(0.7, 0),
			NumberSequenceKeypoint.new(1, 0.05),
		}),
		Rotation = rotation or 135,
	})
end

local function formatDuration(seconds: number): string
	local remaining = math.max(0, math.floor(tonumber(seconds) or 0))
	local days = math.floor(remaining / 86400)
	remaining %= 86400
	local hours = math.floor(remaining / 3600)
	remaining %= 3600
	local minutes = math.floor(remaining / 60)

	if days > 0 then
		return `{days}d {hours}h {minutes}m`
	elseif hours > 0 then
		return `{hours}h {minutes}m`
	end

	return `{math.max(minutes, 1)}m`
end

local EASING = {
	OutSine = function(t)
		return math.sin((t * math.pi) / 2)
	end,
	OutQuad = function(t)
		return 1 - ((1 - t) * (1 - t))
	end,
	OutCubic = function(t)
		return 1 - ((1 - t) ^ 3)
	end,
	OutQuart = function(t)
		return 1 - ((1 - t) ^ 4)
	end,
	OutBack = function(t)
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * ((t - 1) ^ 3) + c1 * ((t - 1) ^ 2)
	end,
	OutElastic = function(t)
		if t == 0 or t == 1 then
			return t
		end
		local c4 = (2 * math.pi) / 3
		return 2 ^ (-10 * t) * math.sin((t * 10 - 0.75) * c4) + 1
	end,
}

local function useTweenNumber(target: number, duration: number?, easingStyle: string?)
	local value, setValue = React.useState(target)

	React.useEffect(function()
		local cancelled = false
		local start = value
		local dur = duration or 0.35
		local steps = math.max(1, math.floor(dur / 0.016))
		local easeFn = EASING[easingStyle or "OutCubic"]

		task.spawn(function()
			for step = 1, steps do
				if cancelled then
					return
				end
				local alpha = step / steps
				setValue(start + ((target - start) * easeFn(alpha)))
				task.wait(0.016)
			end
			if not cancelled then
				setValue(target)
			end
		end)

		return function()
			cancelled = true
		end
	end, { target })

	return value
end

local function TitleLine(props: ReactProps?)
	props = props or {}
	return e("Frame", {
		BackgroundColor3 = props.color or Color3.fromRGB(89, 169, 255),
		BorderSizePixel = 0,
		Position = props.position or UDim2.new(),
		Size = props.size or UDim2.fromOffset(64, 3),
		Visible = props.visible ~= false,
	}, {
		Corner = e("UICorner", {
			CornerRadius = UDim.new(1, 0),
		}),
		Gradient = e("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(89, 169, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 219)),
			}),
		}),
	})
end

local function textLabel(props: ReactProps, children: ReactChildren?)
	local labelProps: ReactProps = table.clone(props)
	labelProps.BackgroundTransparency = labelProps.BackgroundTransparency or 1
	labelProps.BorderSizePixel = 0
	labelProps.Font = labelProps.Font or Enum.Font.FredokaOne
	labelProps.TextColor3 = labelProps.TextColor3 or Color3.fromRGB(255, 255, 255)
	labelProps.TextScaled = if labelProps.TextScaled == nil then true else labelProps.TextScaled
	labelProps.TextWrapped = if labelProps.TextWrapped == nil then true else labelProps.TextWrapped
	return e("TextLabel", labelProps, children)
end

local function imageButton(props: ReactProps, children: ReactChildren?)
	local imageProps: ReactProps = table.clone(props)
	for key, value in buttonProps(imageProps.onActivated) do
		imageProps[key] = value
	end
	imageProps.onActivated = nil
	imageProps.BackgroundTransparency = imageProps.BackgroundTransparency or 1
	imageProps.BorderSizePixel = 0
	return e("ImageButton", imageProps, children)
end

local function solidButton(props: ReactProps, children: ReactChildren?)
	local buttonPropsTable: ReactProps = table.clone(props)
	local onActivated = buttonPropsTable.onActivated
	buttonPropsTable.onActivated = nil
	for key, value in buttonProps(onActivated) do
		buttonPropsTable[key] = value
	end
	buttonPropsTable.BorderSizePixel = 0
	buttonPropsTable.Font = buttonPropsTable.Font or Enum.Font.FredokaOne
	buttonPropsTable.TextScaled = if buttonPropsTable.TextScaled == nil then true else buttonPropsTable.TextScaled
	buttonPropsTable.TextWrapped = true
	return e("TextButton", buttonPropsTable, children)
end

return {
	PlaySound = playSound,
	ButtonProps = buttonProps,
	Corner = corner,
	Stroke = stroke,
	Gradient = gradient,
	GradientRich = gradientRich,
	GlassGradient = glassGradient,
	ShimmerGradient = shimmerGradient,
	NoticeGradient = noticeGradient,
	FormatDuration = formatDuration,
	UseTweenNumber = useTweenNumber,
	TitleLine = TitleLine,
	TextLabel = textLabel,
	ImageButton = imageButton,
	SolidButton = solidButton,
}

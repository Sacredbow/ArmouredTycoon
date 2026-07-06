local TweenService = game:GetService("TweenService")

local RotatingTips = {}
RotatingTips.__index = RotatingTips

local DEFAULT_TIPS = {
	"[Tip]: More droppers = more income.",
	"[Note]: Ths game is STILL in BETA, more updates are coming!",
	"[Tip]: Armour upgrades change combat outcomes.",
	"[Tip]: Saving early unlocks powerful upgrades.",
	"[Fun Fact]: These loading shots are hand-made!",
	"[Tip]: Not all armour is equal, choose wisely.",
	"[Fun Fact]: Australia is wider than the moon.",
	"[Fun Fact]: Bananas are berries, strawberries arent!",
	"[Tip]: Turn on the electricity to use electric-powered facilities",
	"[Fun Fact]: This game is fun!",
	"[Fun Fact]: Sacredbow1 is the Main Developer of this game!",
	"[Fun Fact]: Pineapples take 2 years to grow.",
}

local function shuffle(array)
	for i = #array, 2, -1 do
		local j = math.random(i)
		array[i], array[j] = array[j], array[i]
	end
end

function RotatingTips.new(config)
	local self = setmetatable({}, RotatingTips)

	self.Label = config.Label
	self.Tips = config.Tips or table.clone(DEFAULT_TIPS)
	self._shuffledTips = table.clone(self.Tips)
	shuffle(self._shuffledTips)
	self._index = 1

	self.FadeTime = config.FadeTime or 0.6
	self.DisplayTime = config.DisplayTime or 3
	self.DelayBetween = config.DelayBetween or 0.5

	self._running = false

	self._tweenInfo = TweenInfo.new(self.FadeTime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

	return self
end

function RotatingTips:_fade(transparency)
	if not self.Label then
		return
	end

	local tween = TweenService:Create(self.Label, self._tweenInfo, { TextTransparency = transparency })
	tween:Play()
	tween.Completed:Wait()
end

function RotatingTips:Start()
	if self._running or not self.Label then
		return
	end
	self._running = true

	task.spawn(function()
		while self._running do
			if #self.Tips == 0 then
				task.wait(1)
				continue
			end

			self.Label.Text = self._shuffledTips[self._index]

			self:_fade(0)

			task.wait(self.DisplayTime)

			self:_fade(1)
			task.wait(self.DelayBetween)

			self._index += 1
			if self._index > #self._shuffledTips then
				shuffle(self._shuffledTips)
				self._index = 1
			end
		end
	end)
end

function RotatingTips:Stop()
	self._running = false
end

function RotatingTips:Hide()
	if self.Label then
		TweenService:Create(
			self.Label,
			TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ TextTransparency = 1 }
		):Play()
	end
end

function RotatingTips:AddTip(text)
	table.insert(self.Tips, text)
end

function RotatingTips:ClearTips()
	table.clear(self.Tips)
end

return RotatingTips

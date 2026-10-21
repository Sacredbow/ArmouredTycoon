-- Effects shown while a custom proximity prompt is active.

local module = {
	_beams = setmetatable({}, { __mode = "k" }),
	_highlights = setmetatable({}, { __mode = "k" }),
}

function module:CreateBeam(Part1: BasePart, Part2: BasePart?, Conf)
	if not Part2 then
		return
	end

	self:DestroyBeam(Part1, Part2)

	local fromAttachment = Instance.new("Attachment")
	fromAttachment.Name = "BeamFrom"
	fromAttachment.Parent = Part1

	local toAttachment = Instance.new("Attachment")
	toAttachment.Name = "BeamTo"
	toAttachment.Parent = Part2

	local beam = Instance.new("Beam")
	beam.Attachment0 = fromAttachment
	beam.Attachment1 = toAttachment
	beam.Width0 = Conf.Beam.BeamWidth.Value
	beam.Width1 = Conf.Beam.BeamWidth.Value
	beam.Color = ColorSequence.new(Conf.Beam.BeamColor.Value)
	beam.Transparency = NumberSequence.new(Conf.Beam.BeamTransparency.Value)
	beam.FaceCamera = true
	beam.Name = "PromptBeam"
	beam.Parent = Part1

	self._beams[Part1] = {
		fromAttachment = fromAttachment,
		toAttachment = toAttachment,
		beam = beam,
		part2 = Part2,
	}
end

function module:DestroyBeam(Part1: BasePart, Part2: BasePart?)
	local owned = self._beams[Part1]
	if owned then
		if owned.beam then owned.beam:Destroy() end
		if owned.fromAttachment then owned.fromAttachment:Destroy() end
		if owned.toAttachment then owned.toAttachment:Destroy() end
		self._beams[Part1] = nil
		return
	end

	-- Clean up legacy instances from before ownership tracking was introduced.
	local beam = Part1:FindFirstChild("PromptBeam")
	if beam then beam:Destroy() end
	local fromAttachment = Part1:FindFirstChild("BeamFrom")
	if fromAttachment then fromAttachment:Destroy() end
	if Part2 then
		local toAttachment = Part2:FindFirstChild("BeamTo")
		if toAttachment then toAttachment:Destroy() end
	end
end

function module:CreateHighlight(Part1: BasePart, Conf)
	self:DestroyHighlight(Part1)

	local highlight = Instance.new("Highlight")
	highlight.Name = "PromptHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineColor = Conf.Highlight.HighlightColor.Value
	highlight.OutlineTransparency = Conf.Highlight.HighlightTransparency.Value
	highlight.Parent = Part1

	self._highlights[Part1] = highlight
end

function module:DestroyHighlight(Part1: Instance)
	local highlight = self._highlights[Part1]
	if highlight then
		highlight:Destroy()
		self._highlights[Part1] = nil
		return
	end

	local legacy = Part1:FindFirstChild("PromptHighlight")
	if legacy then legacy:Destroy() end
end

return module

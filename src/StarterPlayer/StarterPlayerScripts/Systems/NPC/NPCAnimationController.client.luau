--!strict
-- Client-side NPC animation controller.
--
-- Discovers registered NPCs anywhere under Workspace.Tycoons (no hardcoded paths),
-- loads their animations from the shared registry and plays them.
--
-- Default state: plays the "Idle" animation for every registered NPC it finds.
-- Other client systems (e.g. dialogue) can switch a specific NPC's animation with:
--   npc:SetAttribute("AnimationOverride", "Talking")
--   npc:SetAttribute("AnimationOverride", nil) -- returns to Idle

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPCAnimationRegistry = require(ReplicatedStorage.Shared.Interaction.NPCAnimationRegistry)

type AnimationType = NPCAnimationRegistry.AnimationType

type NPCState = {
	animator: Animator,
	tracks: { [string]: AnimationTrack },
	current: AnimationTrack?,
	connections: { RBXScriptConnection },
}

local tracked: { [Model]: NPCState } = {}

local function ensureAnimator(humanoid: Humanoid): Animator
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	return animator
end

local function playTrack(model: Model, state: NPCState, animType: string)
	local track = state.tracks[animType]
	if not track then
		local animation = NPCAnimationRegistry.Get(animType :: AnimationType, model.Name)
		if not animation then
			return
		end
		track = state.animator:LoadAnimation(animation)
		track.Looped = true -- Idle/Talking loop until switched; adjust if you add one-shot types
		state.tracks[animType] = track
	end

	if state.current == track and track.IsPlaying then
		return
	end

	if state.current then
		state.current:Stop(0.2)
	end
	track:Play(0.2)
	state.current = track
end

local function untrack(model: Model)
	local state = tracked[model]
	if not state then
		return
	end
	tracked[model] = nil
	for _, connection in state.connections do
		connection:Disconnect()
	end
	if state.current then
		state.current:Stop(0.2)
	end
end

local function trackNPC(instance: Instance)
	if not instance:IsA("Model") or tracked[instance] then
		return
	end
	-- Only animate models whose name is registered as an NPC
	if not NPCAnimationRegistry.Has(instance.Name) then
		return
	end

	local humanoid = instance:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		local child = instance:WaitForChild("Humanoid")
		if child and child:IsA("Humanoid") then
			humanoid = child
		end
	end
	if not humanoid then
		return 
	end

	local state: NPCState = {
		animator = ensureAnimator(humanoid),
		tracks = {},
		current = nil,
		connections = {},
	}
	tracked[instance] = state

	table.insert(state.connections, instance:GetAttributeChangedSignal("AnimationOverride"):Connect(function()
		local override = instance:GetAttribute("AnimationOverride")
		if typeof(override) == "string" then
			playTrack(instance, state, override)
		else
			playTrack(instance, state, "Idle")
		end
	end))

	table.insert(state.connections, instance.AncestryChanged:Connect(function(_, parent)
		if not parent then
			untrack(instance)
		end
	end))

	playTrack(instance, state, "Idle")
end

-- Listen for NPCs appearing later (stage purchased, tycoon cloned in, streaming)
-- BEFORE scanning, so nothing slips through between scan and connect.
local tycoons = Workspace:WaitForChild("Tycoons", 30)
if not tycoons then
	warn("[NPCAnimationController] Workspace.Tycoons not found - no NPCs to animate")
	return
end

tycoons.DescendantAdded:Connect(function(descendant)
	trackNPC(descendant)
end)

-- NPCs that already exist in the map
for _, descendant in tycoons:GetDescendants() do
	trackNPC(descendant)
end
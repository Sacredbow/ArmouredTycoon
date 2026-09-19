--!strict
-- Shared NPC animation registry.
-- Maps NPC model name -> Animation instance, grouped by animation type.
-- Required by both server and client. Register new NPCs and animation types here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type AnimationType = "Idle" | "Talking"

local function getAnimation(animationName: string): Animation
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local animations = assets and assets:FindFirstChild("Animations")
	local animation = animations and animations:FindFirstChild(animationName)
	if not animation or not animation:IsA("Animation") then
		warn(`[NPCAnimationRegistry] Missing Animation '{animationName}' in ReplicatedStorage.Assets.Animations`)
		return
	end
	return animation :: Animation
end

local NPCAnimations: { [AnimationType]: { [string]: Animation } } = {
	Idle = {
		Lakester = getAnimation("Lakester_Idle"),
	},
	Talking = {},
}

local NPCAnimationRegistry = {}

-- Returns the Animation registered for an NPC, or nil (with a warning) if unregistered.
function NPCAnimationRegistry.Get(animType: AnimationType, npcName: string): Animation?
	local byName = NPCAnimations[animType]
	if not byName then
		warn(`[NPCAnimationRegistry] Unknown animation type '{animType}' (expected "Idle" or "Talking")`)
		return nil
	end

	local animation = byName[npcName]
	if not animation then
		warn(`[NPCAnimationRegistry] No '{animType}' animation registered for NPC '{npcName}'`)
	end
	return animation
end

-- True if any animation type is registered for this NPC name.
function NPCAnimationRegistry.Has(npcName: string): boolean
	for _, byName in NPCAnimations do
		if byName[npcName] ~= nil then
			return true
		end
	end
	return false
end

return NPCAnimationRegistry
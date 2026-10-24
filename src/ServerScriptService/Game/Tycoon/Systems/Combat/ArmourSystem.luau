--!strict
-- Consumes ArmourPickup contact intents on the ECS frame.
const ReplicatedStorage = game:GetService("ReplicatedStorage")
local function EquipVest(Character: Model, Template: Model, HealthBonus: number)
	const Vest = Template:Clone()
	const Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if Humanoid then
		Humanoid.MaxHealth += HealthBonus
		Humanoid.Health += HealthBonus
	end
	const Torso = Character:FindFirstChild("Torso") or Character:FindFirstChild("UpperTorso")
	if Torso and Torso:IsA("BasePart") and Vest.PrimaryPart then
		Vest.Parent = Character
		Vest:PivotTo(Torso.CFrame * CFrame.new(0, 0.2, 0) * CFrame.Angles(math.rad(-5), 0, 0))
		const Weld = Instance.new("WeldConstraint")
		Weld.Part0 = Torso
		Weld.Part1 = Vest.PrimaryPart
		Weld.Parent = Vest.PrimaryPart
	end
end

return function(Context: any)
	const World = Context.world
	const Components = Context.Components
	for Entity, Player, Queue in World:query(Components.PlayerRef, Components.ContactIntent) do
		const Remaining = {}
		for _, Intent in Queue do
			if Intent.Action == "ArmourPickup" then
				const Data = Intent.Data
				const Owner = Data and Data.TycoonEntity and World:get(Data.TycoonEntity, Components.Owner)
				if
					Owner
					and Owner.player == Player
					and Data.Part.Transparency == 0
					and World:get(Entity, Components.ArmourEquipped) ~= true
					and Player.Character
				then
					World:set(Entity, Components.ArmourEquipped, true)
					EquipVest(Player.Character, Data.Template, Data.Health)
				end
			else
				Remaining[#Remaining + 1] = Intent
			end
		end
		if #Remaining == 0 then
			World:remove(Entity, Components.ContactIntent)
		else
			World:set(Entity, Components.ContactIntent, Remaining)
		end
	end
end

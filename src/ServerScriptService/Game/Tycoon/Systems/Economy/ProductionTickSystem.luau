--!strict
--[[
	@class ProductionTickSystem

	Production owns the authoritative economy loop. Dropper movement is a
	client-side presentation effect announced with a compact unreliable packet.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ECS = require(ReplicatedStorage.Shared.Core.ECS)
local Packets = require(ReplicatedStorage.Shared.Platform.Network.Packets)

local function announceDropperVisual(dropper: Instance, spawnPart: BasePart)
	local packet = Packets.packets.DropperVisual
	local tycoon = dropper:FindFirstAncestorOfClass("Model")
	if not packet or not tycoon then
		return
	end

	local origin = tycoon:GetPivot().Position
	local targets = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - origin).Magnitude <= 700 then
			table.insert(targets, player)
		end
	end
	if #targets == 0 then
		return
	end

	packet.sendToList({
		dropper = dropper,
		spawnPart = spawnPart,
	}, targets)
end

local function formatAmount(amount: number): string
	local rounded = math.round(amount * 10) / 10
	if rounded == math.floor(rounded) then
		return tostring(rounded)
	end

	return string.format("%.1f", rounded)
end

return function(context: any)
	local world = context.world
	local components = context.Components
	local dt = context.dt

	for entity, producer in world:query(components.Producer) do
		if producer.paused == true then
			continue
		end

		local tycoonEntity = producer.tycoonEntity
		local state = if tycoonEntity then world:get(tycoonEntity, components.TycoonState) else nil
		if not state or state.active == false then
			world:delete(entity)
			continue
		end

		producer.elapsed = (producer.elapsed or 0) + dt
		if producer.elapsed >= producer.interval then
			producer.elapsed -= producer.interval

			local dropper = producer.dropper
			local spawnPart = producer.spawnPart
			if not dropper or not dropper.Parent or not spawnPart or not spawnPart.Parent then
				world:delete(entity)
				continue
			end

			announceDropperVisual(dropper, spawnPart)

			if state.owner then
				state.collectorAmount = (state.collectorAmount or 0) + (producer.value * (state.cashMultiplier or 1))

				local label = state.collectorDisplayLabel
				if label and label.Parent then
					label.Text = formatAmount(state.collectorAmount)
				end
			end
		end

		world:set(entity, components.Producer, producer)
		if tycoonEntity then
			world:set(tycoonEntity, components.TycoonState, state)
		end
	end
end

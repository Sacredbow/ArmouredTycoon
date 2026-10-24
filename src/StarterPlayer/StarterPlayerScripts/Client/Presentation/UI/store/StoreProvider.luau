--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)

local GameStore = require(script.Parent.GameStore)

local function StoreProvider(props)
	local store = GameStore.get()

	React.useEffect(function()
		if RunService:IsStudio() and not RunService:IsRunning() then
			return
		end
		store.Start()
	end, { store })

	return props.children
end

return StoreProvider

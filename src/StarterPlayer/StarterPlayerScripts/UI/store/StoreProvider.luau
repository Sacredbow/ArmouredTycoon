--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)

local GameStore = require(script.Parent.GameStore)

local StoreContext = React.createContext(nil)

local e = React.createElement

local function StoreProvider(props)
	local store = GameStore.get()

	React.useEffect(function()
		if RunService:IsStudio() and not RunService:IsRunning() then
			return
		end
		store:Start()
	end, { store })

	return e(StoreContext.Provider, {
		value = store,
	}, props.children)
end

return StoreProvider

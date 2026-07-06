--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)

local GameStore = require(script.Parent.GameStore)

local StoreContext = React.createContext(nil)

local e = React.createElement

local function StoreProvider(props)
	local store = GameStore.get()
	if not (RunService:IsStudio() and not RunService:IsRunning()) then
		store:Start()
	end

	return e(StoreContext.Provider, {
		value = store,
	}, props.children)
end

return StoreProvider

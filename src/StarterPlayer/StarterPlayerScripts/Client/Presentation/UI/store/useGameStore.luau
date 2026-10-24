--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)

local GameStore = require(script.Parent.GameStore)

return function(selector)
	local store = GameStore.get()
	local selected, setSelected = React.useState(function()
		return selector(store.GetSnapshot())
	end)

	React.useEffect(function()
		local function update()
			setSelected(selector(store.GetSnapshot()))
		end

		update()
		return store.Subscribe(update)
	end, { store, selector })

	return selected
end

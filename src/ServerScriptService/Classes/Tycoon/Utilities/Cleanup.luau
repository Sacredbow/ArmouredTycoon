--!strict
--[[
	@class Cleanup

	@desc
	Generic delayed-destroy helper shared across tycoon systems.
	Destroys an instance after a lifetime if it still has a parent.
]]

--// Module

const Cleanup = {}

--// Public API

function Cleanup.destroyLater(Instance: Instance, Lifetime: number)
	task.delay(Lifetime, function()
		if Instance.Parent then
			Instance:Destroy()
		end
	end)
end

return Cleanup


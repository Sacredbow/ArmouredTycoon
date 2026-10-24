--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)

local function stepNumber(current: number, target: number, response: number, dt: number): number
	local alpha = 1 - math.exp(-response * dt)
	local nextValue = current + (target - current) * alpha

	if math.abs(nextValue - target) < 0.001 then
		return target
	end

	return nextValue
end

return function(target: number, response: number?, initial: number?)
	local springResponse = response or 12
	local binding, setBinding = React.useBinding(if initial ~= nil then initial else target)

	React.useEffect(function()
		local current = binding:getValue()
		local stepConnection: RBXScriptConnection? = RunService.RenderStepped:Connect(function(dt)
			if current == target then
				return
			end

			current = stepNumber(current, target, springResponse, dt)
			setBinding(current)
		end)

		return function()
			if stepConnection then
				stepConnection:Disconnect()
				stepConnection = nil
			end
		end
	end, { target, springResponse })

	return binding
end

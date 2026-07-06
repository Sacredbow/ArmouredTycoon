--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)

local function stepNumber(current: number, target: number, response: number, dt: number): number
	local alpha = 1 - math.exp(-response * dt)
	local nextValue = current + (target - current) * alpha

	if math.abs(nextValue - target) < 0.5 then
		return target
	end

	return nextValue
end

return function(target: number, response: number?)
	local value, setValue = React.useState(target)

	React.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function(dt)
			setValue(function(previous)
				if previous == target then
					return previous
				end

				return stepNumber(previous, target, response or 12, dt)
			end)
		end)

		return function()
			connection:Disconnect()
		end
	end, { target, response })

	return value
end

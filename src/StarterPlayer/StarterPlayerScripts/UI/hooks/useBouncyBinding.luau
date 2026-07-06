--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local React = require(ReplicatedStorage.Packages.react)

return function(target: number, frequency: number?, damping: number?, initial: number?)
	local binding, setBinding = React.useBinding(if initial ~= nil then initial else target)

	React.useEffect(function()
		local current = binding:getValue()
		local velocity = 0
		local omega = (frequency or 16) * 2
		local zeta = damping or 0.78

		local stepConnection: RBXScriptConnection? = RunService.RenderStepped:Connect(function(dt)
			local displacement = current - target
			local acceleration = (-omega * omega * displacement) - (2 * zeta * omega * velocity)

			velocity += acceleration * dt
			current += velocity * dt

			if math.abs(current - target) < 0.0008 and math.abs(velocity) < 0.0008 then
				current = target
				velocity = 0
			end

			setBinding(current)
		end)

		return function()
			if stepConnection then
				stepConnection:Disconnect()
				stepConnection = nil
			end
		end
	end, { target, frequency, damping })

	return binding
end

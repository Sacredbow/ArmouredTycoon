local Runner = {}
Runner.__index = Runner

export type Context = {
	world: any,
	Components: {[string]: number},
	dt: number,
	elapsed: number,
}

type System = (context: Context) -> ()

function Runner.new(name: string, world: any, Components: {[string]: number})
	return setmetatable({
		_name = name,
		_world = world,
		_components = Components,
		_systems = {},
		_elapsed = 0,
		_connection = nil,
	}, Runner)
end

function Runner:AddSystem(name: string, system: System)
	table.insert(self._systems, {
		name = name,
		run = system,
	})
end

function Runner:Step(dt: number)
	self._elapsed += dt

	local context = {
		world = self._world,
		Components = self._components,
		dt = dt,
		elapsed = self._elapsed,
	}

	for _, system in ipairs(self._systems) do
		local ok, err = pcall(system.run, context)
		if not ok then
			warn(`[ECS:{self._name}] {system.name} failed: {err}`)
		end
	end
end

function Runner:Start(signal)
	if self._connection then
		return
	end

	self._connection = signal:Connect(function(dt)
		self:Step(dt)
	end)
end

function Runner:Stop()
	if not self._connection then
		return
	end

	self._connection:Disconnect()
	self._connection = nil
end

return Runner

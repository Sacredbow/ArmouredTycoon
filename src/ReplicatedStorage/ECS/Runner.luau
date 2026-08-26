--!strict
--[[
	@class Runner

	@desc
	ECS system runner. Registers a set of systems and steps them each
	frame with a shared context (world, component map, dt, elapsed).
	Each system is wrapped in pcall so a failing system does not
	cascade into the rest of the frame.
]]

--// Types

export type Context = {
	world: any,
	Components: { [string]: number },
	dt: number,
	elapsed: number,
}

type System = (context: Context) -> ()

--// Module

local Runner = {}
Runner.__index = Runner

--// Constructor

function Runner.new(name: string, world: any, Components: { [string]: number })
	return setmetatable({
		_name = name,
		_world = world,
		_components = Components,
		_systems = {},
		_elapsed = 0,
		_connection = nil,
	}, Runner)
end

--// Public API

function Runner:AddSystem(name: string, system: System)
	table.insert(self._systems, {
		name = name,
		run = system,
	})
end

function Runner:Step(dt: number)
	self._elapsed += dt

	const Context = {
		world = self._world,
		Components = self._components,
		dt = dt,
		elapsed = self._elapsed,
	}

	for _, System in self._systems do
		const Ok, Err = pcall(System.run, Context)
		if not Ok then
			warn(`[ECS:{self._name}] {System.name} failed: {Err}`)
		end
	end
end

function Runner:Start(Signal)
	if self._connection then
		return
	end

	self._connection = Signal:Connect(function(dt)
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

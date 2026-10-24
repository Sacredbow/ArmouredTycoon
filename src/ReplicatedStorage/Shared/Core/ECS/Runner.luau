--!strict
--[[
	@class Runner

	@desc
	Planck-backed ECS scheduler. Keeps the existing shared-context system
	interface while giving server and client loops deterministic phase ordering.
]]

--// Modules

local Planck = require(script.Parent.Parent.Packages.Planck)

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

function Runner.new(name: string, world: any, Components: { [string]: number })
	return setmetatable({
		_name = name,
		_world = world,
		_components = Components,
		_systems = {},
		_elapsed = 0,
		_scheduler = nil,
		_phase = nil,
		_context = nil,
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
	if self._scheduler then
		return
	end

	const Scheduler = Planck.Scheduler.new()
	const Phase = Planck.Phase.new(`{self._name} ECS`)

	-- Run the phase from the supplied RunService signal.
	Scheduler:insert(Phase, Signal)

	-- Planck computes delta time for the frame clock once. All ECS systems
	-- then receive the same context and elapsed time for deterministic ordering.
	Scheduler:addSystem(function()
		const Dt = Scheduler:getDeltaTime()
		self._elapsed += Dt
		self._context = {
			world = self._world,
			Components = self._components,
			dt = Dt,
			elapsed = self._elapsed,
		}
	end, Phase)

	for _, System in self._systems do
		Scheduler:addSystem(function()
			if not self._context then
				return
			end

			System.run(self._context)
		end, Phase)
	end

	self._scheduler = Scheduler
	self._phase = Phase
end

function Runner:Stop()
	if not self._scheduler then
		return
	end

	self._scheduler:cleanup()
	self._scheduler = nil
	self._phase = nil
	self._context = nil
end

return Runner

--!strict
--[[
	@class ECSRuntimeClient

	@desc
	Client-side ECS runner. Registers systems that must run on every
	render step (character management, projectile casting, scheduled
	tasks) and kicks them off with RunService.RenderStepped.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Runner = require(ReplicatedStorage.ECS.Runner)

const CharacterManagerSystem = require(script.Parent.CharacterManagerSystem)
const ProjectileCastSystem = require(script.Parent.ProjectileCastSystem)
const ScheduledTaskSystem = require(script.Parent.ScheduledTaskSystem)

--// Bootstrap

const RunnerInstance = Runner.new("Client", ECS.world, ECS.Components)
RunnerInstance:AddSystem("CharacterManagerSystem", CharacterManagerSystem)
RunnerInstance:AddSystem("ProjectileCastSystem", ProjectileCastSystem)
RunnerInstance:AddSystem("ScheduledTaskSystem", ScheduledTaskSystem)
RunnerInstance:Start(RunService.RenderStepped)

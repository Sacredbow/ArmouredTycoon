--!strict
--[[
	@class ECSRuntimeClient

	@desc
	Client-side ECS runner. Registers systems that must run on every
	render step (character management and projectile casting) and kicks them off with RunService.RenderStepped.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

--// Modules

const ECS = require(ReplicatedStorage.ECS)
const Runner = require(ReplicatedStorage.ECS.Runner)

const CharacterManagerSystem = require(script.Parent.CharacterManagerSystem)

--// Bootstrap

const RunnerInstance = Runner.new("Client", ECS.world, ECS.Components)
RunnerInstance:AddSystem("CharacterManagerSystem", CharacterManagerSystem)
RunnerInstance:Start(RunService.RenderStepped)

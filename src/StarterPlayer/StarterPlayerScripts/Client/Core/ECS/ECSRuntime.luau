--!strict
--[[
	@class ECSRuntimeClient

	@desc
	Client-side ECS runner. Registers systems that must run on every
	render step (character movement and projectile casting) and kicks them off with RunService.RenderStepped.
]]

--// Services

const ReplicatedStorage = game:GetService("ReplicatedStorage")
const RunService = game:GetService("RunService")

--// Modules

const ECS = require(ReplicatedStorage.Shared.Core.ECS)
const Runner = require(ReplicatedStorage.Shared.Core.ECS.Runner)

const CharacterMovementSystem = require(ReplicatedStorage.Shared.Game.Character.CharacterMovementSystem)

--// Bootstrap

const RunnerInstance = Runner.new("Client", ECS.world, ECS.Components)
RunnerInstance:AddSystem("CharacterMovementSystem", CharacterMovementSystem.Run)
RunnerInstance:Start(RunService.RenderStepped)

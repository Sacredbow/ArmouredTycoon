local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ECS = require(ReplicatedStorage.ECS)
local Runner = require(ReplicatedStorage.ECS.Runner)

local CharacterManagerSystem = require(script.Parent.CharacterManagerSystem)
local ProjectileCastSystem = require(script.Parent.ProjectileCastSystem)
local ScheduledTaskSystem = require(script.Parent.ScheduledTaskSystem)

local runner = Runner.new("Client", ECS.world, ECS.Components)
runner:AddSystem("CharacterManagerSystem", CharacterManagerSystem)
runner:AddSystem("ProjectileCastSystem", ProjectileCastSystem)
runner:AddSystem("ScheduledTaskSystem", ScheduledTaskSystem)
runner:Start(RunService.RenderStepped)

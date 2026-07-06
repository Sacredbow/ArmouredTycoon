--!strict

local components = script.Parent:WaitForChild("FrameworkComponents")
local Main = require(components:WaitForChild("Main"))

Main.start(script)

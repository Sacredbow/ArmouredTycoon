--!strict

local components = script.Parent.Parent:WaitForChild("Combat"):WaitForChild("Effects")
local Registry = require(components:WaitForChild("Registry"))

Registry.start()

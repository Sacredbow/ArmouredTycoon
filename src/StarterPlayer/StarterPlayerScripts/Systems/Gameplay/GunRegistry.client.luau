--!strict

local components = script.Parent.Parent:WaitForChild("RegistryComponents")
local Registry = require(components:WaitForChild("Registry"))

Registry.start()

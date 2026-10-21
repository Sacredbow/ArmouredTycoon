--!strict
--[[
	Legacy path retained for configuration assets only. Tycoon gameplay is
	created by ECS.TycoonFactory and processed by ECS.TycoonRuntime.
	There is intentionally no Tycoon class or constructor here.
]]
local Factory = require(game:GetService("ServerScriptService").ECS.TycoonFactory)
return table.freeze({
	spawn = Factory.spawn,
})
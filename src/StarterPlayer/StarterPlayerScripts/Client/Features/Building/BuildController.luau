--!strict
--[[
	Client build placement is currently paused. The server BuildService remains
	the authoritative ECS feature boundary, so this module only exposes the
	standard lifecycle hook used by the client module loader.
]]

return {
	OnStart = function() end,
}

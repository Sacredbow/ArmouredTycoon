--!strict
--[[
	@class FPSSystem (entry script)

	@desc
	Gameplay entry point for the server-side ACS combat engine.
	All implementation now lives in the sibling FPS-System module
	(Core + Handlers); this Script merely boots it once.
]]

--// Modules

const FPS = require(script.Parent:WaitForChild("FPS-System")) :: {
	Init: () -> (),
}



FPS.Init()
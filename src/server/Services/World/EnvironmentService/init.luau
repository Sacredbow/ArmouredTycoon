
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LightningModule = require(script.LightningModule)



local EnvironmentService = {}

EnvironmentService.__index = EnvironmentService

local FULL_DAY_LENGTH = 600  
local currentTime = 6
local timeSpeed = 24 / FULL_DAY_LENGTH  

local DAWN_START = 5
local DAY_START = 6
local DUSK_START = 16
local NIGHT_START = 17

local presets = {
	night = {
		Brightness = 0,
		OutdoorAmbient = Color3.fromRGB(30, 30, 60),
		Ambient = Color3.fromRGB(50, 50, 100),
		FogEnd = 3500,
	},
	dawn = {
		Brightness = 1,
		OutdoorAmbient = Color3.fromRGB(100, 80, 70),
		Ambient = Color3.fromRGB(150, 120, 100),
		FogEnd = 4000,
	},
	day = {
		Brightness = 1.1,
		OutdoorAmbient = Color3.fromRGB(128, 128, 128),
		Ambient = Color3.fromRGB(255, 255, 255),
		FogEnd = 7000,
	},
	dusk = {
		Brightness = 1,
		OutdoorAmbient = Color3.fromRGB(80, 70, 90),
		Ambient = Color3.fromRGB(130, 110, 140),
		FogEnd = 3800,
	},
}



local function lerp(a, b, t)
	return a + (b - a) * t
end

local function lerpColor(a, b, t)
	return Color3.new(
		lerp(a.R, b.R, t),
		lerp(a.G, b.G, t),
		lerp(a.B, b.B, t)
	)
end

local function blend(a, b, t)
	return {
		Brightness = lerp(a.Brightness, b.Brightness, t),
		OutdoorAmbient = lerpColor(a.OutdoorAmbient, b.OutdoorAmbient, t),
		Ambient = lerpColor(a.Ambient, b.Ambient, t),
		FogEnd = lerp(a.FogEnd, b.FogEnd, t),
	}
end





local lightsAreOn = false

function EnvironmentService:_SetStreetLights(enabled)
	if lightsAreOn == enabled then return end
	lightsAreOn = enabled

	for _, prop in ipairs(self.Props:GetChildren()) do
		if prop.Name == "StreetLights" and prop:IsA("Model") then
			for _, item in ipairs(prop:GetDescendants()) do
				if item:IsA("MeshPart") then
					item.Transparency = enabled and 0 or 1
					item.CanCollide = enabled
				elseif item:IsA("SurfaceLight") then
					item.Brightness = enabled and 1 or 0
				elseif item:IsA("Beam") then
					item.Enabled = enabled
				end
			end
		end
	end
end





function EnvironmentService:_UpdateLighting(hour)
	hour = hour % 24
	Lighting.ClockTime = hour

	if hour < DAWN_START then
		self:_Apply(blend(presets.night, presets.dawn, hour / DAWN_START))
		self:_SetStreetLights(true)

	elseif hour < DAY_START then
		self:_Apply(blend(presets.dawn, presets.day, (hour - DAWN_START) / (DAY_START - DAWN_START)))
		self:_SetStreetLights(false)

	elseif hour < DUSK_START then
		self:_Apply(presets.day)
		self:_SetStreetLights(false)

	elseif hour < NIGHT_START then
		self:_Apply(blend(presets.day, presets.dusk, (hour - DUSK_START) / (NIGHT_START - DUSK_START)))
		self:_SetStreetLights(true)

	else
		self:_Apply(blend(presets.dusk, presets.night, (hour - NIGHT_START) / (24 - NIGHT_START)))
		self:_SetStreetLights(true)
	end
end



function EnvironmentService:_Apply(props)
	for k, v in pairs(props) do
		Lighting[k] = v
	end
end




function EnvironmentService:_InitDayNight()
	local last = os.clock()

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = now - last
		last = now

		currentTime += dt * timeSpeed
		self:_UpdateLighting(currentTime)
	end)
end




function EnvironmentService:_InitWeather()
	task.spawn(function()
		while task.wait(180) do
			--self:_Rain()
			self:_Lightining()
		end
	end)
end

--function EnvironmentService:_Rain()
	
--	local RandomNumber = math.random(1, 1)
	
--	if RandomNumber == 1 then
--		--local Sky = self.LightingPackage.Sky:Clone()
--		--local Rain = self.LightingPackage.Rain:Clone()
		
		
--		--Sky.Parent = workspace
--		--Rain.Parent = workspace
		
		
--		if self.ReturnRequest then
--			self.ReturnRequest:FireAllClients("Rain")
			
--			task.wait(3333)
--		end
		
--		task.delay(80, function()
			
--			--Sky:Destroy()
--			--Rain:Destroy()
--		end)
--	end 


--end


function EnvironmentService:_Lightining()
	local RNG = math.random(1, 6)
	if RNG == 6 then
		LightningModule.StartStorm(Vector3.new(50,0,0), 400, 80)
	end
	
end



function EnvironmentService.new(dependencies)
	local self = setmetatable({}, EnvironmentService)

	self.LightingPackage = dependencies.LightingPackage
	self.Props = dependencies.Props
	self.ReturnRequest = dependencies.ReturnRequest
	
	

	return self
end


function EnvironmentService:Init()
	self:_InitDayNight()
	self:_InitWeather()

end

return EnvironmentService
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EnvironmentShared = require(ReplicatedStorage.EnvironmentShared)

local ClientSignals = {}

export type ClientSignalPayload = {
	kind: string,
	valueString: string?,
	valueNumber: number?,
	valueInstance: Instance?,
	position: Vector3?,
	amount: number?,
	weatherKind: string?,
	weatherDuration: number?,
	windDirection: Vector3?,
	windSpeed: number?,
	windPower: number?,
	rainIntensity: number?,
	thunderChance: number?,
	lightingWeight: number?,
}

local cachedPackets: any? = nil
local nextPacketsRetryAt = 0

local function packetsNamespaceReady(): boolean
	local storage = ReplicatedStorage:FindFirstChild("BytenetStorage")
	local namespaceValue = storage and storage:FindFirstChild("ArmouredTycoon")
	return namespaceValue ~= nil and namespaceValue:IsA("StringValue") and namespaceValue.Value ~= ""
end
local function getPackets()
	if RunService:IsStudio() and not RunService:IsRunning() then
		return nil
	end

	if RunService:IsClient() and not packetsNamespaceReady() then
		return nil
	end

	if os.clock() < nextPacketsRetryAt then
		return nil
	end

	if not cachedPackets then
		local ok, packets = pcall(function()
			return require(ReplicatedStorage.Network.Packets)
		end)

		if not ok then
			nextPacketsRetryAt = os.clock() + 2
			warn(`[ClientSignals] Packets unavailable: {packets}`)
			return nil
		end

		cachedPackets = packets
	end

	return cachedPackets
end

local function disconnectPacketConnection(connection: any?)
	if not connection then
		return
	end

	if typeof(connection) == "RBXScriptConnection" then
		connection:Disconnect()
	elseif type(connection) == "function" then
		connection()
	elseif type(connection) == "table" and type(connection.Disconnect) == "function" then
		connection:Disconnect()
	end
end

local function encodeWeather(payload: ClientSignalPayload, weather: EnvironmentShared.WeatherState)
	payload.weatherKind = weather.kind
	payload.weatherDuration = weather.duration
	payload.windDirection = weather.windDirection
	payload.windSpeed = weather.windSpeed
	payload.windPower = weather.windPower
	payload.rainIntensity = weather.rainIntensity
	payload.thunderChance = weather.thunderChance
	payload.lightingWeight = weather.lightingWeight
end

local function decodeWeather(payload: ClientSignalPayload): EnvironmentShared.WeatherState?
	local kind = payload.weatherKind
	if typeof(kind) ~= "string" then
		return nil
	end

	local base = EnvironmentShared.getWeather(kind :: EnvironmentShared.WeatherKind)
	if not base then
		return nil
	end

	return {
		kind = base.kind,
		duration = payload.weatherDuration or base.duration,
		windDirection = payload.windDirection or base.windDirection,
		windSpeed = payload.windSpeed or base.windSpeed,
		windPower = payload.windPower or base.windPower,
		rainIntensity = payload.rainIntensity or base.rainIntensity,
		thunderChance = payload.thunderChance or base.thunderChance,
		lightingWeight = payload.lightingWeight or base.lightingWeight,
	}
end

function ClientSignals.Encode(kind: string, value: any?): ClientSignalPayload
	local payload: ClientSignalPayload = {
		kind = kind,
	}

	if kind == "Weather" and typeof(value) == "table" then
		encodeWeather(payload, value :: EnvironmentShared.WeatherState)
	elseif kind == "CashCollected" and typeof(value) == "table" then
		if typeof(value.amount) == "number" then
			payload.amount = value.amount
		end
		if typeof(value.origin) == "Vector3" then
			payload.position = value.origin
		end
	elseif typeof(value) == "number" then
		payload.valueNumber = value
	elseif typeof(value) == "string" then
		payload.valueString = value
	elseif typeof(value) == "Instance" then
		payload.valueInstance = value
	elseif typeof(value) == "Vector3" then
		payload.position = value
	end

	return payload
end

function ClientSignals.Decode(payload: ClientSignalPayload): (string, any?)
	if payload.kind == "Weather" then
		return payload.kind, decodeWeather(payload)
	elseif payload.kind == "CashCollected" then
		return payload.kind, {
			amount = payload.amount or payload.valueNumber or 0,
			origin = payload.position or Vector3.zero,
		}
	end

	local value: any? = payload.valueNumber
	if value == nil then
		value = payload.valueString
	end
	if value == nil then
		value = payload.valueInstance
	end
	if value == nil then
		value = payload.position
	end

	return payload.kind, value
end

function ClientSignals.Send(player: Player, kind: string, value: any?)
	local Packets = getPackets()
	if not Packets then
		return
	end

	Packets.packets.ClientSignal.sendTo(ClientSignals.Encode(kind, value), player)
end

function ClientSignals.SendAll(kind: string, value: any?)
	local Packets = getPackets()
	if not Packets then
		return
	end

	Packets.packets.ClientSignal.sendToAll(ClientSignals.Encode(kind, value))
end

function ClientSignals.Listen(callback: (string, any?, ClientSignalPayload, Player?) -> ())
	local disconnected = false
	local activeConnection: any? = nil

	task.spawn(function()
		local Packets = getPackets()
		while not disconnected and not Packets do
			task.wait(0.25)
			Packets = getPackets()
		end

		if disconnected or not Packets then
			return
		end

		activeConnection = Packets.packets.ClientSignal.listen(function(payload: ClientSignalPayload, player: Player?)
			local kind, value = ClientSignals.Decode(payload)
			callback(kind, value, payload, player)
		end)
	end)

	local function disconnect()
		disconnected = true
		disconnectPacketConnection(activeConnection)
		activeConnection = nil
	end

	return {
		Disconnect = disconnect,
		Destroy = disconnect,
	}
end

return ClientSignals


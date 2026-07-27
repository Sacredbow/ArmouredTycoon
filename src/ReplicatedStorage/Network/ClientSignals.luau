--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')

local EnvironmentShared = require(ReplicatedStorage.EnvironmentShared)

local ClientSignals = {}

local REMOTE_NAME = 'ClientSignalRemote'

export type ClientSignalPayload = {
	kind: string,
	valueBoolean: boolean?,
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

local function getRemote(): RemoteEvent?
	local parent = script.Parent
	local remote = parent:FindFirstChild(REMOTE_NAME)
	if remote and remote:IsA('RemoteEvent') then
		return remote
	end

	if RunService:IsServer() then
		remote = Instance.new('RemoteEvent')
		remote.Name = REMOTE_NAME
		remote.Parent = parent
		return remote
	end

	local waited = parent:WaitForChild(REMOTE_NAME, 10)
	if waited and waited:IsA('RemoteEvent') then
		return waited
	end

	warn('[ClientSignals] ClientSignalRemote was not available before timeout')
	return nil
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
	if typeof(kind) ~= 'string' then
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

	if kind == 'Weather' and typeof(value) == 'table' then
		encodeWeather(payload, value :: EnvironmentShared.WeatherState)
	elseif kind == 'CashCollected' and typeof(value) == 'table' then
		if typeof(value.amount) == 'number' then
			payload.amount = value.amount
		end
		if typeof(value.origin) == 'Vector3' then
			payload.position = value.origin
		end
	elseif typeof(value) == 'number' then
		payload.valueNumber = value
	elseif typeof(value) == 'boolean' then
		payload.valueBoolean = value
	elseif typeof(value) == 'string' then
		payload.valueString = value
	elseif typeof(value) == 'Instance' then
		payload.valueInstance = value
	elseif typeof(value) == 'Vector3' then
		payload.position = value
	end

	return payload
end

function ClientSignals.Decode(payload: ClientSignalPayload): (string, any?)
	if payload.kind == 'Weather' then
		return payload.kind, decodeWeather(payload)
	elseif payload.kind == 'CashCollected' then
		return payload.kind, {
			amount = payload.amount or payload.valueNumber or 0,
			origin = payload.position or Vector3.zero,
		}
	end

	local value: any? = payload.valueNumber
	if value == nil then
		value = payload.valueBoolean
	end
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
	local remote = getRemote()
	if not remote then
		return
	end

	remote:FireClient(player, ClientSignals.Encode(kind, value))
end

function ClientSignals.SendAll(kind: string, value: any?)
	local remote = getRemote()
	if not remote then
		return
	end

	remote:FireAllClients(ClientSignals.Encode(kind, value))
end

function ClientSignals.Listen(callback: (string, any?, ClientSignalPayload, Player?) -> ())
	local remote = getRemote()
	if not remote then
		return {
			Disconnect = function() end,
			Destroy = function() end,
		}
	end

	local connection: RBXScriptConnection
	if RunService:IsServer() then
		connection = remote.OnServerEvent:Connect(function(player: Player, payload: ClientSignalPayload)
			local kind, value = ClientSignals.Decode(payload)
			callback(kind, value, payload, player)
		end)
	else
		connection = remote.OnClientEvent:Connect(function(payload: ClientSignalPayload)
			local kind, value = ClientSignals.Decode(payload)
			callback(kind, value, payload, nil)
		end)
	end

	return {
		Disconnect = function()
			connection:Disconnect()
		end,
		Destroy = function()
			connection:Disconnect()
		end,
	}
end

return ClientSignals

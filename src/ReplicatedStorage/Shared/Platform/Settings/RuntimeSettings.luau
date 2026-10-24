--!strict

local RuntimeSettings = {}

export type SettingValue = boolean | number | string
export type SettingMap = { [string]: SettingValue }
export type SettingConnection = {
	Disconnect: (SettingConnection) -> (),
	Destroy: (SettingConnection) -> (),
}

local SettingsConfig = require(script.Parent.SettingsConfig)

local values: SettingMap = {}
local observers: { [string]: { (SettingValue?) -> () } } = {}

for name, value in SettingsConfig.default_settings do
	values[name] = value :: SettingValue
end

values.CameraControllerOwnsOffset = false

local function removeObserver(name: string, callback: (SettingValue?) -> ())
	local callbacks = observers[name]
	if not callbacks then
		return
	end

	for index = #callbacks, 1, -1 do
		if callbacks[index] == callback then
			table.remove(callbacks, index)
			break
		end
	end
end

function RuntimeSettings.Set(name: string, value: SettingValue)
	if values[name] == value then
		return
	end

	values[name] = value
	local callbacks = observers[name]
	if not callbacks then
		return
	end

	for _, callback in table.clone(callbacks) do
		callback(value)
	end
end

function RuntimeSettings.Get(name: string): SettingValue?
	return values[name]
end

function RuntimeSettings.GetBoolean(name: string, fallback: boolean): boolean
	local value = values[name]
	if typeof(value) == "boolean" then
		return value
	end
	return fallback
end

function RuntimeSettings.GetNumber(name: string, fallback: number): number
	local value = values[name]
	if typeof(value) == "number" then
		return value
	end
	return fallback
end

function RuntimeSettings.Observe(name: string, callback: (SettingValue?) -> ()): SettingConnection
	local callbacks = observers[name]
	if not callbacks then
		callbacks = {}
		observers[name] = callbacks
	end

	table.insert(callbacks, callback)
	callback(values[name])

	local disconnected = false
	local connection = {} :: SettingConnection
	function connection:Disconnect()
		if disconnected then
			return
		end
		disconnected = true
		removeObserver(name, callback)
	end
	connection.Destroy = connection.Disconnect

	return connection
end

function RuntimeSettings.Export(): SettingMap
	return table.clone(values)
end

return RuntimeSettings

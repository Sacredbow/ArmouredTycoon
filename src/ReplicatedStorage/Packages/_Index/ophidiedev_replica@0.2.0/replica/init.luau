local RunService = game:GetService("RunService")

export type ReplicaServer = typeof(require(script.ReplicaServer))
export type ReplicaClient = typeof(require(script.ReplicaClient))

if RunService:IsServer() then
	local Replica = require(script.ReplicaServer)
	Replica.default = require(script.ReplicaServer)
	return Replica
else
	local server = script:FindFirstChild("ReplicaServer")
	if server then
		server:Destroy()
	end

	local Replica = require(script.ReplicaClient)
	Replica.default = require(script.ReplicaClient)

	return Replica
end

--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Observers = require(ReplicatedStorage.Packages.Observers)


export type Policy = {
	Rate: number,
	Burst: number,
	Validate: ((any, Player) -> boolean)?,
}

type Bucket = {
	Tokens: number,
	UpdatedAt: number,
}

type PlayerBuckets = {
	Aggregate: Bucket,
	Packets: { [string]: Bucket },
}

type Metrics = {
	Accepted: number,
	Dropped: number,
}

local AGGREGATE_RATE = 60
local AGGREGATE_BURST = 120

local BucketsByPlayer: { [Player]: PlayerBuckets } = {}
local MetricsByPacket: { [string]: Metrics } = {}

local NetworkGuard = {}

local function Consume(bucket: Bucket, rate: number, burst: number, now: number): boolean
	bucket.Tokens = math.min(burst, bucket.Tokens + math.max(0, now - bucket.UpdatedAt) * rate)
	bucket.UpdatedAt = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

function NetworkGuard.Allow(player: Player, packetName: string, policy: Policy, data: any): boolean
	assert(policy.Rate > 0 and policy.Burst >= 1, "NetworkGuard policy must have a positive rate and burst")
	local metrics = MetricsByPacket[packetName]
	if not metrics then
		metrics = { Accepted = 0, Dropped = 0 }
		MetricsByPacket[packetName] = metrics
	end

	if player.Parent ~= Players then
		metrics.Dropped += 1
		return false
	end

	local now = os.clock()
	local playerBuckets = BucketsByPlayer[player]
	if not playerBuckets then
		playerBuckets = {
			Aggregate = { Tokens = AGGREGATE_BURST, UpdatedAt = now },
			Packets = {},
		}
		BucketsByPlayer[player] = playerBuckets
	end

	if not Consume(playerBuckets.Aggregate, AGGREGATE_RATE, AGGREGATE_BURST, now) then
		metrics.Dropped += 1
		return false
	end

	local packetBucket = playerBuckets.Packets[packetName]
	if not packetBucket then
		packetBucket = { Tokens = policy.Burst, UpdatedAt = now }
		playerBuckets.Packets[packetName] = packetBucket
	end

	if not Consume(packetBucket, policy.Rate, policy.Burst, now) then
		metrics.Dropped += 1
		return false
	end
	if policy.Validate then
		local validCall, validPayload = pcall(policy.Validate, data, player)
		if not validCall or not validPayload then
			metrics.Dropped += 1
			return false
		end
	end

	metrics.Accepted += 1
	return true
end

function NetworkGuard.Listen(packet: any, packetName: string, policy: Policy, handler: (any, Player) -> ()): () -> ()
	return packet.listen(function(data: any, player: Player?)
		if player and NetworkGuard.Allow(player, packetName, policy, data) then
			handler(data, player)
		end
	end)
end

function NetworkGuard.Query(packet: any, packetName: string, policy: Policy, handler: (any, Player) -> any): () -> ()
	return packet.listen(function(data: any, player: Player?)
		if player and NetworkGuard.Allow(player, packetName, policy, data) then
			return handler(data, player)
		end
		return { success = false, message = "Request rejected." }
	end)
end

function NetworkGuard.GetMetrics(): { [string]: Metrics }
	local snapshot = {}
	for name, metrics in MetricsByPacket do
		snapshot[name] = table.clone(metrics)
	end
	return snapshot
end


Observers.observePlayer(function(_player: Player)
	return function()
		BucketsByPlayer[_player] = nil
	end
end)

return NetworkGuard

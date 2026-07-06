--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local TutorialSignals = {}

local REMOTE_NAME = "TutorialSignal"
local PROTOCOL_VERSION = 1

export type TutorialKind =
	"TycoonClaimed"
	| "TycoonAvailable"
	| "Perfect!"
	| "Now purchase your first button!"
	| "Claim your money"
	| "Congrats! Tutorial Completed."

local function getActionId(kind: TutorialKind): number
	if kind == "TycoonClaimed" then
		return 1
	elseif kind == "TycoonAvailable" then
		return 2
	elseif kind == "Perfect!" then
		return 3
	elseif kind == "Now purchase your first button!" then
		return 4
	elseif kind == "Claim your money" then
		return 5
	else
		return 6
	end
end

local function getKindFromActionId(actionId: number): TutorialKind?
	if actionId == 1 then
		return "TycoonClaimed"
	elseif actionId == 2 then
		return "TycoonAvailable"
	elseif actionId == 3 then
		return "Perfect!"
	elseif actionId == 4 then
		return "Now purchase your first button!"
	elseif actionId == 5 then
		return "Claim your money"
	elseif actionId == 6 then
		return "Congrats! Tutorial Completed."
	end

	return nil
end

local function getNetworkFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("Network")
	if folder and folder:IsA("Folder") then
		return folder
	end

	if RunService:IsServer() then
		local created = Instance.new("Folder")
		created.Name = "Network"
		created.Parent = ReplicatedStorage
		return created
	end

	return ReplicatedStorage:WaitForChild("Network") :: Folder
end

local function getRemote(): RemoteEvent?
	local folder = getNetworkFolder()
	local existing = folder:FindFirstChild(REMOTE_NAME)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end

	if RunService:IsServer() then
		local remote = Instance.new("RemoteEvent")
		remote.Name = REMOTE_NAME
		remote.Parent = folder
		return remote
	end

	local remote = folder:WaitForChild(REMOTE_NAME, 30)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end

	warn("[TutorialSignals] TutorialSignal remote was not available on the client.")
	return nil
end

local function packKind(kind: TutorialKind): number
	local actionId = getActionId(kind :: TutorialKind)
	return bit32.bor(bit32.lshift(PROTOCOL_VERSION, 8), actionId)
end

local function unpackKind(packed: any): TutorialKind?
	if typeof(packed) ~= "number" then
		return nil
	end

	local version = bit32.rshift(packed, 8)
	if version ~= PROTOCOL_VERSION then
		return nil
	end

	local actionId = bit32.band(packed, 0xff)
	return getKindFromActionId(actionId)
end

function TutorialSignals.Send(player: Player, kind: TutorialKind, target: string?)
	local remote = getRemote()
	local packed = packKind(kind)
	if not remote then
		return
	end

	remote:FireClient(player, packed, target)
end

function TutorialSignals.SendAll(kind: TutorialKind, target: string?)
	local remote = getRemote()
	local packed = packKind(kind)
	if not remote then
		return
	end

	remote:FireAllClients(packed, target)
end

function TutorialSignals.Listen(callback: (TutorialKind, string?) -> ()): RBXScriptConnection?
	local remote = getRemote()
	if not remote then
		return nil
	end

	return remote.OnClientEvent:Connect(function(packed: any, target: any?)
		local kind = unpackKind(packed)
		if not kind then
			return
		end

		callback(kind :: TutorialKind, if typeof(target) == "string" then target else nil)
	end)
end

return TutorialSignals

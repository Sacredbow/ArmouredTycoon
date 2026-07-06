local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMESPACE_NAME = "ArmouredTycoon"
local CLIENT_NAMESPACE_TIMEOUT = 12

local function waitForClientNamespace(): boolean
	local storage = ReplicatedStorage:FindFirstChild("BytenetStorage") or ReplicatedStorage:WaitForChild("BytenetStorage", CLIENT_NAMESPACE_TIMEOUT)
	if not storage then
		warn(`Bytenet namespace {NAMESPACE_NAME} was not ready: BytenetStorage did not replicate in time`)
		return false
	end

	local namespaceValue = storage:FindFirstChild(NAMESPACE_NAME)
	local deadline = os.clock() + CLIENT_NAMESPACE_TIMEOUT
	while os.clock() < deadline do
		if namespaceValue and namespaceValue:IsA("StringValue") and namespaceValue.Value ~= "" then
			return true
		end

		namespaceValue = storage:FindFirstChild(NAMESPACE_NAME)
		task.wait(0.05)
	end

	warn(`Bytenet namespace {NAMESPACE_NAME} was not ready before timeout`)
	return false
end

if RunService:IsClient() and RunService:IsRunning() then
	waitForClientNamespace()
end

local ByteNet = require(ReplicatedStorage.Packages["bytenet-max"])

return ByteNet.defineNamespace(NAMESPACE_NAME, function()
	return {
		packets = {
			Notification = ByteNet.definePacket({
				value = ByteNet.struct({
					kind = ByteNet.string,
					message = ByteNet.optional(ByteNet.string),
				}),
			}),

			CombatEffect = ByteNet.definePacket({
				value = ByteNet.struct({
					kind = ByteNet.string,
					position = ByteNet.optional(ByteNet.vec3),
					intensity = ByteNet.optional(ByteNet.float32),
				}),
			}),

			WeaponState = ByteNet.definePacket({
				value = ByteNet.struct({
					kind = ByteNet.string,
					weaponName = ByteNet.optional(ByteNet.string),
					stance = ByteNet.optional(ByteNet.int8),
					lean = ByteNet.optional(ByteNet.int8),
				}),
			}),

			StatSync = ByteNet.definePacket({
				value = ByteNet.struct({
					stat = ByteNet.string,
					value = ByteNet.int32,
				}),
			}),

			KOTHAnnouncement = ByteNet.definePacket({
				value = ByteNet.struct({
					playerName = ByteNet.string,
					teamColor = ByteNet.color3,
					minutes = ByteNet.optional(ByteNet.int32),
				}),
			}),

			InventoryAction = ByteNet.definePacket({
				value = ByteNet.struct({
					action = ByteNet.string,
					tool = ByteNet.optional(ByteNet.inst),
				}),
			}),

			NPCConversation = ByteNet.definePacket({
				value = ByteNet.struct({
					action = ByteNet.string,
					conversationId = ByteNet.optional(ByteNet.string),
					npcName = ByteNet.optional(ByteNet.string),
					npcLine = ByteNet.optional(ByteNet.string),
					turnCount = ByteNet.optional(ByteNet.int8),
					maxTurns = ByteNet.optional(ByteNet.int8),
					reason = ByteNet.optional(ByteNet.string),
					options = ByteNet.optional(ByteNet.array(ByteNet.struct({
						id = ByteNet.string,
						text = ByteNet.string,
						tone = ByteNet.string,
					}))),
				}),
			}),

			NPCConversationChoice = ByteNet.definePacket({
				value = ByteNet.struct({
					action = ByteNet.string,
					conversationId = ByteNet.string,
					optionId = ByteNet.optional(ByteNet.string),
				}),
			}),

			NPCSpeech = ByteNet.definePacket({
				value = ByteNet.struct({
					adornee = ByteNet.inst,
					message = ByteNet.string,
				}),
			}),

			NukeCinematic = ByteNet.definePacket({
				value = ByteNet.struct({
					action = ByteNet.string,
					sessionId = ByteNet.optional(ByteNet.string),
					role = ByteNet.optional(ByteNet.string),
					phase = ByteNet.optional(ByteNet.string),
					message = ByteNet.optional(ByteNet.string),
					launcherName = ByteNet.optional(ByteNet.string),
					defenderName = ByteNet.optional(ByteNet.string),
					launcherUserId = ByteNet.optional(ByteNet.string),
					defenderUserId = ByteNet.optional(ByteNet.string),
					winnerName = ByteNet.optional(ByteNet.string),
					targetPosition = ByteNet.optional(ByteNet.vec3),
					sourcePosition = ByteNet.optional(ByteNet.vec3),
					distance = ByteNet.optional(ByteNet.float32),
					deathRange = ByteNet.optional(ByteNet.float32),
					timeLeft = ByteNet.optional(ByteNet.float32),
					launcherScore = ByteNet.optional(ByteNet.int32),
					defenderScore = ByteNet.optional(ByteNet.int32),
				}),
			}),

			NukeClickBatch = ByteNet.definePacket({
				value = ByteNet.struct({
					sessionId = ByteNet.string,
					count = ByteNet.int32,
					clientWindow = ByteNet.float32,
				}),
			}),

			ClientSignal = ByteNet.definePacket({
				value = ByteNet.struct({
					kind = ByteNet.string,
					valueString = ByteNet.optional(ByteNet.string),
					valueNumber = ByteNet.optional(ByteNet.float32),
					valueInstance = ByteNet.optional(ByteNet.inst),
					position = ByteNet.optional(ByteNet.vec3),
					amount = ByteNet.optional(ByteNet.float32),
					weatherKind = ByteNet.optional(ByteNet.string),
					weatherDuration = ByteNet.optional(ByteNet.float32),
					windDirection = ByteNet.optional(ByteNet.vec3),
					windSpeed = ByteNet.optional(ByteNet.float32),
					windPower = ByteNet.optional(ByteNet.float32),
					rainIntensity = ByteNet.optional(ByteNet.float32),
					thunderChance = ByteNet.optional(ByteNet.float32),
					lightingWeight = ByteNet.optional(ByteNet.float32),
				}),
			}),

			NukeTarget = ByteNet.definePacket({
				value = ByteNet.struct({
					target = ByteNet.string,
				}),
			}),
		},
	}
end)

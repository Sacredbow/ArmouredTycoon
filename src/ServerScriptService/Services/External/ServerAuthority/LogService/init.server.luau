local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(script.Config)

local LoggingEvent = require(ServerScriptService.Signals.LogSignal)

local secretLoaded, webhookURL = pcall(function()
	return HttpService:GetSecret(Config.WebhookSecretName)
end)
if not secretLoaded then
	webhookURL = nil
end

local requestQueue = {}
local isProcessing = false

local function schedule(delay: number, callback: () -> (), _name: string?)
	task.delay(delay, callback)
end

local function getRetryDelaySeconds(responseHeaders)
	if type(responseHeaders) ~= "table" then
		return Config.DefaultRetryDelay
	end

	local retryAfter = responseHeaders["Retry-After"] or responseHeaders["retry-after"]
	local retryNumber = tonumber(retryAfter)
	if retryNumber then
		if retryNumber > 30 then
			return retryNumber / 1000
		end

		return retryNumber
	end

	return Config.DefaultRetryDelay
end

local function ProcessQueue()
	if isProcessing then
		return
	end

	isProcessing = true

	local function processNext()
		if #requestQueue == 0 then
			isProcessing = false
			return
		end

		local requestData = table.remove(requestQueue, 1)
		local success, response = pcall(function()
			return HttpService:RequestAsync({
				Url = requestData.url,
				Method = "POST",
				Headers = {
					["Content-Type"] = "application/json",
				},
				Body = HttpService:JSONEncode(requestData.data),
			})
		end)

		if not success then
			warn(response)
		elseif not response.Success then
			if response.StatusCode == 429 then
				local retries = requestData.retries or 0
				if retries < Config.MaxRetries then
					local retryDelay = getRetryDelaySeconds(response.Headers)
					table.insert(requestQueue, 1, {
						url = requestData.url,
						data = requestData.data,
						retries = retries + 1,
					})
					schedule(retryDelay, processNext, "LogService:Retry")
					return
				end
			end

			warn(
				string.format(
					"[LogService] Webhook request failed with status %s: %s",
					tostring(response.StatusCode),
					tostring(response.StatusMessage)
				)
			)
		end

		schedule(Config.RateLimitDelay, processNext, "LogService:RateLimit")
	end

	processNext()
end

local function EnqueueRequest(url, data)
	if url == nil then
		return
	end

	table.insert(requestQueue, { url = url, data = data, retries = 0 })
	ProcessQueue()
end

local function formatVector3(vector)
	if typeof(vector) ~= "Vector3" then
		return "N/A"
	end

	return string.format("(%.2f, %.2f, %.2f)", vector.X, vector.Y, vector.Z)
end

local function formatHistory(history)
	if type(history) ~= "table" or #history == 0 then
		return "No samples"
	end

	local lines = {}
	for index, sample in ipairs(history) do
		lines[index] = string.format("%d. %s @ %s", index, formatVector3(sample.Position), tostring(sample.Time or "?"))
	end

	return table.concat(lines, "\n")
end

local function addField(fields, name, value, inline)
	if value == nil or value == "" then
		return
	end

	table.insert(fields, {
		name = tostring(name),
		value = tostring(value),
		inline = inline == true,
	})
end

local function getServerUptime()
	return math.floor(workspace.DistributedGameTime)
end

local function getOwnedTycoonName(player)
	local Team = player.Team
	return if Team then Team.Name else nil
end

local function getReasonPresentation(reason)
	local presentations = {
		["Teleport Exploits"] = {
			Title = "Anti-Cheat Enforcement • Teleport",
			Color = 15158332,
		},
		["Speed Exploits"] = {
			Title = "Anti-Cheat Enforcement • Speed",
			Color = 16098851,
		},
		["Jump Exploits"] = {
			Title = "Anti-Cheat Enforcement • Jump",
			Color = 16763904,
		},
		["Noclip Exploits"] = {
			Title = "Anti-Cheat Enforcement • Noclip",
			Color = 10038562,
		},
	}

	for keyword, presentation in presentations do
		if string.find(reason, keyword, 1, true) then
			return presentation
		end
	end

	return {
		Title = "Anti-Cheat Enforcement",
		Color = 16711680,
	}
end

local function formatEvidenceJson(evidence)
	if type(evidence) ~= "table" then
		return nil
	end

	local success, encoded = pcall(function()
		return HttpService:JSONEncode(evidence)
	end)
	if not success then
		return nil
	end

	if #encoded > 900 then
		encoded = string.sub(encoded, 1, 897) .. "..."
	end

	return "```json\n" .. encoded .. "\n```"
end

local function SnapshotPlayer(player)
	if not player then
		return nil
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChild("Humanoid")
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	local tycoonName = getOwnedTycoonName(player)

	return {
		Name = player.Name,
		DisplayName = player.DisplayName,
		UserId = player.UserId,
		AccountAge = player.AccountAge,
		Team = player.Team and player.Team.Name or "None",
		HasTycoon = tycoonName and "Yes" or "No",
		TycoonName = tycoonName or "None",
		Position = humanoidRootPart and humanoidRootPart.Position or nil,
		Health = humanoid and humanoid.Health or nil,
		FloorMaterial = humanoid and tostring(humanoid.FloorMaterial) or "Unknown",
		PlaceId = game.PlaceId,
		JobId = game.JobId,
		PrivateServerId = game.PrivateServerId,
		ServerUptime = getServerUptime(),
		PlayerCount = #Players:GetPlayers(),
		IsStudio = RunService:IsStudio(),
	}
end

local function Embed(kickedPlayer, reason, evidence)
	if not kickedPlayer then
		return
	end

	reason = tostring(reason or "Unknown")
	local snap = SnapshotPlayer(kickedPlayer)
	if not snap then
		return
	end
	local incidentId = HttpService:GenerateGUID(false)
	local presentation = getReasonPresentation(reason)

	local fields = {
		{
			name = "Incident",
			value = "`" .. incidentId .. "`",
			inline = false,
		},
		{
			name = "Player",
			value = snap.Name .. " (`" .. snap.UserId .. "`)",
			inline = false,
		},
		{
			name = "Profile",
			value = "[View Profile](https://www.roblox.com/users/" .. snap.UserId .. "/profile)",
			inline = true,
		},
		{
			name = "Display Name",
			value = snap.DisplayName,
			inline = true,
		},
		{
			name = "Account Age",
			value = tostring(snap.AccountAge) .. " days",
			inline = true,
		},
		{
			name = "Reason",
			value = reason,
			inline = false,
		},
	}

	addField(fields, "Team", snap.Team, true)
	addField(fields, "Has Tycoon", snap.HasTycoon, true)
	addField(fields, "Tycoon", snap.TycoonName, true)
	addField(fields, "Position", formatVector3(snap.Position), true)
	addField(fields, "Health", snap.Health, true)
	addField(fields, "Floor Material", snap.FloorMaterial, true)
	addField(
		fields,
		"Server Context",
		string.format(
			"Place: `%s`\nJob: `%s`\nPrivate Server: `%s`\nUptime: `%ss`\nPlayers: `%d`\nStudio: `%s`",
			tostring(snap.PlaceId),
			snap.JobId ~= "" and snap.JobId or "No JobId",
			snap.PrivateServerId ~= "" and snap.PrivateServerId or "None",
			snap.ServerUptime,
			snap.PlayerCount,
			tostring(snap.IsStudio)
		),
		false
	)

	if type(evidence) == "table" then
		addField(fields, "Current Position", formatVector3(evidence.CurrentPosition), true)
		addField(fields, "Last Valid Position", formatVector3(evidence.LastPosition), true)
		addField(fields, "Speed", evidence.Speed and string.format("%.2f", evidence.Speed), true)
		addField(
			fields,
			"Height Above Ground",
			evidence.HeightAboveGround and string.format("%.2f", evidence.HeightAboveGround),
			true
		)
		addField(
			fields,
			"Teleport Distance",
			evidence.TeleportDistance and string.format("%.2f", evidence.TeleportDistance),
			true
		)
		addField(
			fields,
			"Vertical Delta",
			evidence.VerticalDelta and string.format("%.2f", evidence.VerticalDelta),
			true
		)
		addField(fields, "Violations", evidence.Violations, true)
		addField(fields, "Noclip Strikes", evidence.NoclipStrikes, true)
		addField(fields, "Teleport Strikes", evidence.TeleportStrikes, true)
		addField(fields, "Humanoid State", evidence.HumanoidState, true)
		addField(fields, "Movement History", formatHistory(evidence.PositionHistory), false)
		addField(fields, "Raw Evidence", formatEvidenceJson(evidence), false)
	end

	local embed = {
		title = presentation.Title,
		description = "**ServerAuthority detected anomalous behaviour from a player.**",
		type = "rich",
		color = presentation.Color,
		thumbnail = {
			url = "https://www.roblox.com/headshot-thumbnail/image?userId="
				.. snap.UserId
				.. "&width=420&height=420&format=png",
		},
		fields = fields,
		footer = {
			text = "ServerAuthority • Automated Log • " .. incidentId,
		},
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}

	local data = {
		content = nil,
		embeds = { embed },
	}

	EnqueueRequest(webhookURL, data)
end

LoggingEvent:Connect(function(kickedPlayer, reason, evidence)
	Embed(kickedPlayer, reason, evidence)
end)

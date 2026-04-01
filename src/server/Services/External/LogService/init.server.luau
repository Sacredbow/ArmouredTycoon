local HTTPService = game:GetService("HttpService")


local LoggingEvent =  Instance.new("BindableEvent")
LoggingEvent.Name = "Logging"
LoggingEvent.Parent = script




local requestQueue = {}
local isProcessing = false
local RATE_LIMIT_DELAY = 2

local WebhookURL = "https://discord.com/api/webhooks/1459542770975903955/TyPlc_-S13AkDSpb2lPDjDynLfTsWmab0KQtnl3aD6enhvYMTGgLBa5Dqb9aso0q1KQ3"
local function ProcessQueue()
	if isProcessing then return end
	isProcessing = true

	while #requestQueue > 0 do
		local requestData = table.remove(requestQueue, 1)
		local success, errorMessage = pcall(function()
			HTTPService:PostAsync(
				requestData.url,
				HTTPService:JSONEncode(requestData.data)
			)
		end)

		if not success then
			warn(errorMessage)
		end

	

		task.wait(RATE_LIMIT_DELAY)
	end

	isProcessing = false
end

local function EnqueueRequest(url, data, snap)
	table.insert(requestQueue, { url = url, data = data, snap = snap })
	ProcessQueue()
end


local function SnapshotPlayer(player)
	if not player then return nil end
	return {
		Name = player.Name,
		UserId = player.UserId,
		AccountAge = player.AccountAge
	}
end


local function Embed(KickedPlayer, Reason)
	if not KickedPlayer then return end
	Reason = tostring(Reason or "Unknown")
	local snap = SnapshotPlayer(KickedPlayer)

	local embed = {
		title = " Anti-Cheat Enforcement",
		description = "**SentraGuard™ detected Anomalous Behaviour from a player.**",
		type = "rich",
		color = 16711680, 
		thumbnail = {
			url = "https://www.roblox.com/headshot-thumbnail/image?userId=" 
				.. snap.UserId .. "&width=420&height=420&format=png"
		},
		fields = {
			{
				name = "👤 Player",
				value = snap.Name .. " (`" .. snap.UserId .. "`)",
				inline = false
			},
			{
				name = "📄 Profile",
				value = "[View Profile](https://www.roblox.com/users/" .. snap.UserId .. "/profile)",
				inline = true
			},
			{
				name = "📆 Account Age",
				value = tostring(snap.AccountAge) .. " days",
				inline = true
			},
			{
				name = "⚠️ Reason",
				value = Reason,
				inline = false
			}
		},
		footer = {
			text = "SentraGuard™ • Automated Log"
		},
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
	}

	local Data = {
		content = nil,
		embeds = { embed }
	}

	EnqueueRequest(WebhookURL, Data, snap)
end


LoggingEvent.Event:Connect(function(KickedPlayer, Reason)
	Embed(KickedPlayer, Reason)
end)



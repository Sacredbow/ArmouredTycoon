--!strict
--[[
	@class FollowService

	@desc
	Checks if a player follows a Roblox user via the Friends API.
	Uses roproxy.com to avoid official API rate limits.
	Supports cursor-based pagination for large follow lists.
]]

--// Services

const HTTPService = game:GetService("HttpService")

--// Constants

const REQUEST_TIMEOUT = 10
const BASE_URL = "http://friends.roproxy.com/v1/users/"

--// Module

local FollowService = {}

--// Public API

function FollowService.IsFollowing(Follower: number, BeingFollowed: number, Cursor: string?): boolean
	Cursor = Cursor or ""
	local Url = BASE_URL .. Follower .. "/followings?&cursor=" .. Cursor .. "&sortOrder=Asc&limit=100"

	local Success, Response = pcall(function()
		return HTTPService:RequestAsync({
			Url = Url,
			Method = "GET",
			Timeout = REQUEST_TIMEOUT,
		})
	end)

	if not Success then
		warn(`[FollowService] HTTP request failed for user {Follower}: {tostring(Response)}`)
		return false
	end

	if not Response.Success then
		warn(`[FollowService] API returned status {Response.StatusCode} for user {Follower}`)
		return false
	end

	local Success2, Body = pcall(function()
		return HTTPService:JSONDecode(Response.Body)
	end)

	if not Success2 then
		warn(`[FollowService] Failed to decode response body for user {Follower}`)
		return false
	end

	for _, Entry in Body.data do
		if Entry.id == BeingFollowed then
			return true
		end
	end

	if Body.nextPageCursor then
		return FollowService.IsFollowing(Follower, BeingFollowed, Body.nextPageCursor)
	end

	return false
end

return FollowService

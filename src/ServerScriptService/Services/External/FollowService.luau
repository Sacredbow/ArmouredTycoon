local HTTPService = game:GetService("HttpService")

local FollowService = {}

function FollowService.IsFollowing(follower: number, beingFollowed: number, cursor: string)
	cursor = cursor or ""
	local url = "http://friends.roproxy.com/v1/users/" .. follower .. "/followings?&cursor=" .. cursor .. "&sortOrder=Asc&limit=100"

	local response = HTTPService:RequestAsync({ Url = url, Method = "GET" })

	if response.Success then
		local body = HTTPService:JSONDecode(response.Body)
		for _, v in pairs(body.data) do
			if v.id == beingFollowed then return true end
		end
		if body.nextPageCursor then
			return FollowService.IsFollowing(follower, beingFollowed, body.nextPageCursor)
		end
	end
	return false
end

return FollowService
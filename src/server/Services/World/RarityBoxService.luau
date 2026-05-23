local _Gm = game
local _Svc = setmetatable({}, {
	__index = function(_, k)
		return _Gm:GetService(k)
	end,
})

local _P = _Svc.Players
local _SSS = _Svc.ServerScriptService

local _Rarity = require(_SSS.Modules.RarityModule)
local _Follow = require(_SSS.Services.External.FollowService)

local _CFG = table.freeze({
	_i = 60,
	_l = 30,
})

local _K = function(a, b)
	return tostring(a) .. tostring(b)
end

local _RID = tonumber(_K(1372, 952359))
local _FOLLOW_TARGETS = table.freeze({ _RID })

local _R = table.freeze({
	Common = { cash = { 3000, 5000 } },
	Uncommon = { cash = { 10000, 15000 } },
	Rare = { cash = { 35000, 50000 } },
	Legendary = { cash = { 55000, 70000 } },
	Mythical = { cash = { 100000, 180000 }, emerald = { 40, 80 }, requiresFollow = true },
	Divine = { cash = { 300000, 350000 }, emerald = { 80, 120 }, requiresFollow = true },
})

local _bx = {}

local RarityBoxService = {}
RarityBoxService.__index = RarityBoxService

local function _rng(range)
	return math.random(range[1], range[2])
end

local function _follows(uid)
	for _, id in ipairs(_FOLLOW_TARGETS) do
		if _Follow.IsFollowing(uid, id, "") then
			return true
		end
	end
	return false
end

local function _safeStat(plr, n)
	local ls = plr:FindFirstChild("leaderstats")
	if not ls then
		return nil
	end
	return ls:FindFirstChild(n)
end

function RarityBoxService.new(returnRequest, gunRarity)
	local self = setmetatable({}, RarityBoxService)
	self.ReturnRequest = returnRequest
	self.GunRarity = gunRarity
	self.BoxFolder = Instance.new("Folder")
	self.BoxFolder.Name = "RarityBoxes"
	self.BoxFolder.Parent = workspace
	self.SpawnPoints = workspace:WaitForChild("BoxSpawnPoints")
	return self
end

function RarityBoxService:_GiveReward(player, boxName)
	local spec = _R[boxName]
	if not spec then
		return
	end

	if spec.requiresFollow and not _follows(player.UserId) then
		self.ReturnRequest:FireClient(player, "NotFollowing")
		return
	end

	local c = _safeStat(player, "Cash")
	local e = _safeStat(player, "Emerald")

	if c and spec.cash then
		c.Value += _rng(spec.cash)
	end
	if e and spec.emerald then
		e.Value += _rng(spec.emerald)
	end
end

function RarityBoxService:_SpawnBox()
	local sp = self.SpawnPoints:GetChildren()
	if #sp == 0 then
		return
	end

	local pick = sp[math.random(1, #sp)]
	local raw = _Rarity:SpawnRandomBox()
	if not raw then
		return
	end

	local b = raw:Clone()
	local pp = b.PrimaryPart
	if not pp then
		return
	end

	if b.Name == "Divine" then
		self.GunRarity:FireAllClients("Divine")
	end

	b:PivotTo(pick.CFrame)
	b.Parent = self.BoxFolder

	task.delay(_CFG._l, function()
		if b.Parent then
			b:Destroy()
		end
	end)

	local _lock = false
	pp.Touched:Connect(function(hit)
		if _lock then
			return
		end

		local plr = _P:GetPlayerFromCharacter(hit.Parent)
		if not plr then
			return
		end

		_lock = true
		_bx[1] = plr
		self:_GiveReward(_bx[1], b.Name)
		_bx[1] = nil

		if b.Parent then
			b:Destroy()
		end
	end)
end

function RarityBoxService:Init()
	task.spawn(function()
		while task.wait(_CFG._i) do
			self:_SpawnBox()
		end
	end)
end

return RarityBoxService

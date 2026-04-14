--!optimize 2

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.Parent.Parent.ProfileStore)

local Logger = require(ReplicatedStorage.Loader.Logger)
local Signal = require(ReplicatedStorage.Signal)
local Replica = require(ReplicatedStorage.ReplicaServer)

local Profile: typeof(ProfileStore.New(...))
local PlayerDataLoaded = Signal.new() :: Signal.Signal<Player>
local Token = Replica.Token("PlayerData")

local IS_STUDIO = RunService:IsStudio()
local PROFILE_STORE_KEY = "PlayerData"
local ERROR_MESSAGE = "Failed to load player data. Please rejoin."
local SUCESS_MESSAGE = "Player data loaded successfully!"
local KICK_MESSAGE = "Profile session ended. Please rejoin."

local PlayerDataManager = {
	_template = nil :: {[any]: any},
	_dataStoreKey = nil :: string,
	_cache = {},
}

local Template: {number} = {
	Cash = 0,
	Rebirth = 0,
	Level = 0,
	
	CurrentDay = 0,
	LastClaimed = 0,
	ClaimedRewards = {}
}

local function buildLeaderstats(player: Player): Folder
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = 0
	cash.Parent = leaderstats
	
	local rebirth = Instance.new("IntValue")
	rebirth.Name = "Rebirth"
	rebirth.Value = 0
	rebirth.Parent = leaderstats
	
	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 0
	level.Parent = leaderstats
	
	leaderstats.Parent = player
	
	return leaderstats
end

function PlayerDataManager.getCacheData(self: PlayerDataManager, player: Player): CacheData?
	if self._cache[player] then
		return self._cache[player]
	end
end

local function onPlayerAdded(self: PlayerDataManager, player: Player): ()
	Profile = ProfileStore.New(PROFILE_STORE_KEY, Template)
	
	local PlayerProfile = Profile:StartSessionAsync("Player_"..player.UserId, {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	
	if not PlayerProfile then
		Logger:warn(ERROR_MESSAGE)
	end
	
	PlayerProfile:AddUserId(player.UserId)
	PlayerProfile:Reconcile()
	
	PlayerProfile.OnSessionEnd:Connect(function()
		player:Kick(KICK_MESSAGE)
		PlayerProfile:EndSession()
		
		Logger:warn("Profile session ended.")
	end)
	
	if player.Parent ~= Players then
		PlayerProfile:EndSession()
		
		return
	end
	
	local PlayerReplica = Replica.New({
		Token = Token,
		Data = PlayerProfile.Data,
		Tags = { Player = player },
	})
	
	self._cache[player] = {
		Profile = PlayerProfile,
		Replica = PlayerReplica,
		Data = PlayerProfile.Data
	}
	buildLeaderstats(player)

	PlayerReplica:Replicate()
	
	PlayerDataLoaded:Fire(player)
	
	Logger:warn(SUCESS_MESSAGE)
end

local function onPlayerRemoving(self: PlayerDataManager, player: Player): ()
	local profilee = PlayerDataManager.getCacheData(self, player)
	
	if not profilee then
		return
	end
	
	profilee.Profile:EndSession()
end

Players.PlayerRemoving:Connect(function(player)
	onPlayerRemoving(PlayerDataManager, player)
end)

if not IS_STUDIO then
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			onPlayerRemoving(PlayerDataManager, player)
		end
	end)
end

function PlayerDataManager.Init()
	local self = PlayerDataManager
	
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			onPlayerAdded(self, player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		onPlayerAdded(self, player)
	end)
end

type PlayerDataManager = typeof(PlayerDataManager)

return PlayerDataManager :: PlayerDataManager

-- ServerScriptService.Economy.ScrapManager
-- Spawns physical Scrap piles out in the danger zone; players store them (E) as a stacking
-- inventory Tool or throw one pile's worth back (F). Scrap read/write goes through ScrapWallet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local ScrapWallet = require(Modules:WaitForChild("ScrapWallet"))

local SC = GameConfig.Scrap

local dropScrapEvent = Net.event("ScrapEvents", "DropScrap")

local activePiles: { [BasePart]: boolean } = {}

-- Clean up any leftover piles from a previous run
for _, child in ipairs(Workspace:GetChildren()) do
	if child.Name == "ScrapPile" then
		child:Destroy()
	end
end

local purifier = Workspace:WaitForChild("Purifier", 15)

local function removeScrapPile(pile: BasePart)
	activePiles[pile] = nil
	if pile and pile.Parent then
		pile:Destroy()
	end
end

local function spawnScrapPile(pos: Vector3?): BasePart?
	if not purifier then
		purifier = Workspace:FindFirstChild("Purifier")
		if not purifier then
			return nil
		end
	end

	local pile = Instance.new("Part")
	pile.Name = "ScrapPile"
	pile.Size = Vector3.new(1.6, 1.2, 2)

	if pos then
		pile.Position = pos
	else
		local angle = math.random() * math.pi * 2
		local dist = math.random(SC.SpawnMinDist, SC.SpawnMaxDist)
		pile.Position = purifier.Position + Vector3.new(math.cos(angle) * dist, 2, math.sin(angle) * dist)
	end

	pile.Anchored = false
	pile.CanCollide = true
	pile.Friction = 0.8
	pile.Material = Enum.Material.Metal
	pile.Color = Color3.fromRGB(120, 110, 90)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Store in Inventory [E]"
	prompt.ObjectText = "Scrap"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 8
	prompt.ClickablePrompt = false
	prompt.Parent = pile

	prompt.Triggered:Connect(function(player)
		removeScrapPile(pile)
		ScrapWallet.Add(player, SC.PerPile)
		print(player.Name .. " stored scrap in their inventory.")
	end)

	pile.Parent = Workspace
	activePiles[pile] = true
	return pile
end

-- Drop (F): throw exactly one pile's worth back into the world
dropScrapEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end

	if not ScrapWallet.TrySpend(player, SC.PerPile) then
		return
	end

	local root = char.HumanoidRootPart
	local spawnPos = root.Position + root.CFrame.LookVector * 4
	local spawned = spawnScrapPile(spawnPos)
	if spawned then
		spawned.AssemblyLinearVelocity = root.CFrame.LookVector * SC.ThrowVelocity + Vector3.new(0, 10, 0)
	end

	print(player.Name .. " dropped and threw scrap with F.")
end)

-- Initial piles
for _ = 1, SC.MaxPiles do
	spawnScrapPile()
end

-- Periodic top-up
task.spawn(function()
	while true do
		task.wait(SC.RespawnCheckInterval)
		local count = 0
		for _ in pairs(activePiles) do
			count += 1
		end
		if count < SC.MaxPiles then
			spawnScrapPile()
		end
	end
end)

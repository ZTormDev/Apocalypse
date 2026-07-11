-- ServerScriptService.Economy.ScrapManager
-- Owns Scrap dropping/pickup only. Scrap Junk piles are now spawned by the central,
-- Points-based SpawnManager (via ScrapPileFactory); this script no longer runs a spawn loop.
-- Players throw one plaque back with G (spends 1 scrap); anyone can pick a thrown plaque up
-- with E. Scrap read/write goes through ScrapWallet.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local ScrapWallet = require(Modules:WaitForChild("ScrapWallet"))
local PickupVfx = require(Modules:WaitForChild("PickupVfx"))

local SC = GameConfig.Scrap

local dropScrapEvent = Net.event("ScrapEvents", "DropScrap")

-- Clean up any leftover piles / thrown plaques from a previous run
for _, child in ipairs(Workspace:GetChildren()) do
	if child.Name == "ScrapPile" or child.Name == "ScrapItemDropped" then
		child:Destroy()
	end
end

-- Drop (G): throw exactly 1 scrap plaque back into the world
dropScrapEvent.OnServerEvent:Connect(function(player)
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then
		return
	end

	-- Spends exactly 1 scrap to throw 1 physical plaque
	if not ScrapWallet.TrySpend(player, 1) then
		return
	end

	local root = char.HumanoidRootPart
	local spawnPos = root.Position + root.CFrame.LookVector * 3 + Vector3.new(0, 1, 0)

	local scrapItemAsset = ReplicatedStorage:FindFirstChild("ScrapItemAsset")
	if scrapItemAsset then
		local dropModel = scrapItemAsset:Clone()
		dropModel.Name = "ScrapItemDropped"
		dropModel:ScaleTo(0.7) -- Make the dropped plaque smaller

		local union = dropModel:FindFirstChild("Scrap Metal") or dropModel:FindFirstChildOfClass("UnionOperation")
		if union then
			union.Anchored = false
			union.CanCollide = true
			union.Massless = false

			-- Add ProximityPrompt for players to collect it
			local prompt = Instance.new("ProximityPrompt")
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt.ActionText = "Pick Up Plaque"
			prompt.ObjectText = "Scrap"
			prompt.MaxActivationDistance = 8
			prompt.ClickablePrompt = false
			prompt.Parent = union

			prompt.Triggered:Connect(function(collectingPlayer)
				PickupVfx.absorb(union, prompt, collectingPlayer, function()
					dropModel:Destroy()
					ScrapWallet.Add(collectingPlayer, 1)
				end)
			end)

			dropModel:PivotTo(CFrame.new(spawnPos))
			dropModel.Parent = workspace

			-- Launch the plaque forward physically
			union.AssemblyLinearVelocity = root.CFrame.LookVector * SC.ThrowVelocity + Vector3.new(0, 8, 0)
		else
			dropModel:Destroy()
		end
	end

	print(player.Name .. " dropped 1 scrap plaque using G.")
end)

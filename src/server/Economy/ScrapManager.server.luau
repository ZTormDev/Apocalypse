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

local activePiles: { [Model]: boolean } = {}

-- Clean up any leftover piles from a previous run
for _, child in ipairs(Workspace:GetChildren()) do
	if child.Name == "ScrapPile" then
		child:Destroy()
	end
end

local purifier = Workspace:WaitForChild("Purifier", 15)

local function removeScrapPile(pile: Model)
	activePiles[pile] = nil
	if pile and pile.Parent then
		pile:Destroy()
	end
end

local function spawnScrapPile(pos: Vector3?): Model?
	if not purifier then
		purifier = Workspace:FindFirstChild("Purifier")
		if not purifier then
			return nil
		end
	end

	local junkAsset = ReplicatedStorage:FindFirstChild("ScrapJunkPartsAsset")
	if not junkAsset then
		warn("ScrapJunkPartsAsset not found in ReplicatedStorage!")
		return nil
	end

	local model = junkAsset:Clone()
	model.Name = "ScrapPile"

	-- Resolve the primary part (first Part found inside the inner Model)
	local innerModel = model:FindFirstChild("Model")
	local parts = innerModel and innerModel:GetChildren() or {}
	local primaryPart = nil
	for _, p in ipairs(parts) do
		if p:IsA("BasePart") then
			primaryPart = p
			break
		end
	end

	if not primaryPart then
		model:Destroy()
		return nil
	end

	model.PrimaryPart = primaryPart
	primaryPart.Anchored = true
	primaryPart.CanCollide = true
	primaryPart.Massless = true

	-- Weld all subparts to the primaryPart (and anchor all of them)
	for _, p in ipairs(parts) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = true
			p.Massless = true

			if p ~= primaryPart then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primaryPart
				weld.Part1 = p
				weld.Parent = p
			end
		end
	end

	-- Scale the model to be a bit smaller (0.8)
	model:ScaleTo(0.8)

	-- Positioning: Use raycasting to snap the model flat to the floor
	local targetPos = nil
	if pos then
		targetPos = pos
	else
		local angle = math.random() * math.pi * 2
		local dist = math.random(SC.SpawnMinDist, SC.SpawnMaxDist)
		local spawnPos = purifier.Position + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)

		local rayOrigin = Vector3.new(spawnPos.X, 150, spawnPos.Z)
		local rayDirection = Vector3.new(0, -200, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { purifier, model }

		local result = Workspace:Raycast(rayOrigin, rayDirection, params)
		if result then
			targetPos = result.Position
		else
			targetPos = Vector3.new(spawnPos.X, 2, spawnPos.Z)
		end
	end

	model:PivotTo(CFrame.new(targetPos))

	-- Setup Health attributes
	model:SetAttribute("Health", SC.MaxHealth)
	model:SetAttribute("MaxHealth", SC.MaxHealth)

	-- Billboard Health Bar + Name Gui (always visible within range)
	local bgui = Instance.new("BillboardGui")
	bgui.Name = "HealthGui"
	bgui.Size = UDim2.new(0, 90, 0, 26)
	bgui.StudsOffset = Vector3.new(0, 4.5, 0)
	bgui.MaxDistance = 40 -- only render within a considerable range
	bgui.AlwaysOnTop = true
	bgui.Adornee = primaryPart
	bgui.Enabled = true

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 14)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = "Scrap Junk"
	nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.5
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextScaled = true
	nameLabel.Parent = bgui

	local bg = Instance.new("Frame")
	bg.Name = "BarBackground"
	bg.Position = UDim2.new(0, 0, 0, 18)
	bg.Size = UDim2.new(1, 0, 0, 8)
	bg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	bg.BorderSizePixel = 0
	bg.Parent = bgui

	local uiCorner1 = Instance.new("UICorner")
	uiCorner1.CornerRadius = UDim.new(0, 3)
	uiCorner1.Parent = bg

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bg

	local uiCorner2 = Instance.new("UICorner")
	uiCorner2.CornerRadius = UDim.new(0, 3)
	uiCorner2.Parent = fill

	bgui.Parent = model

	-- Update the health bar fill on damage (always visible, name stays put)
	model:GetAttributeChangedSignal("Health"):Connect(function()
		local h = model:GetAttribute("Health") or 0
		local maxH = model:GetAttribute("MaxHealth") or 100
		fill.Size = UDim2.new(math.clamp(h / maxH, 0, 1), 0, 1, 0)
	end)

	model.Parent = Workspace
	activePiles[model] = true
	return model
end

-- Drop (F): throw exactly 1 scrap plaque back into the world
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
			prompt.ActionText = "Pick Up Plaque"
			prompt.ObjectText = "Scrap"
			prompt.MaxActivationDistance = 8
			prompt.ClickablePrompt = false
			prompt.Parent = union

			prompt.Triggered:Connect(function(collectingPlayer)
				dropModel:Destroy()
				local Wallet = require(game.ServerScriptService.modules.ScrapWallet)
				Wallet.Add(collectingPlayer, 1)
			end)

			dropModel:PivotTo(CFrame.new(spawnPos))
			dropModel.Parent = workspace

			-- Launch the plaque forward physically
			union.AssemblyLinearVelocity = root.CFrame.LookVector * SC.ThrowVelocity + Vector3.new(0, 8, 0)
		else
			dropModel:Destroy()
		end
	end

	print(player.Name .. " dropped 1 scrap plaque using F.")
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
		for pile in pairs(activePiles) do
			if pile and pile.Parent then
				count += 1
			else
				activePiles[pile] = nil
			end
		end
		if count < SC.MaxPiles then
			spawnScrapPile()
		end
	end
end)

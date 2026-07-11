--!strict
-- ServerScriptService.modules.ScrapPileFactory
-- Builds a single mineable "Scrap Junk" pile at a given position. Extracted from ScrapManager
-- so the central SpawnManager (Points-based) can create piles without ScrapManager owning a
-- spawn loop. The pile's damage/destruction is handled by CombatManager; the physical scrap
-- drops it yields on destruction are handled there too.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))

local Modules = script.Parent
local ScrapVfx = require(Modules:WaitForChild("ScrapVfx"))

local SC = GameConfig.Scrap

local ScrapPileFactory = {}

-- Creates a ScrapPile model snapped flat to the floor at `targetPos` (or resolved via a
-- downward raycast if `snapToFloor` is true). Returns the model, or nil if the asset/parts
-- are missing.
function ScrapPileFactory.spawn(targetPos: Vector3): Model?
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
	ScrapVfx.attachHitSparks(primaryPart)

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

	model:ScaleTo(0.8)

	-- Snap flat to the floor beneath the target position
	local rayOrigin = Vector3.new(targetPos.X, targetPos.Y + 150, targetPos.Z)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	local result = Workspace:Raycast(rayOrigin, Vector3.new(0, -400, 0), params)
	local finalPos = result and result.Position or targetPos

	model:PivotTo(CFrame.new(finalPos))

	-- Health attributes
	model:SetAttribute("Health", SC.MaxHealth)
	model:SetAttribute("MaxHealth", SC.MaxHealth)

	-- Billboard health bar + name
	local bgui = Instance.new("BillboardGui")
	bgui.Name = "HealthGui"
	bgui.Size = UDim2.new(0, 90, 0, 26)
	bgui.StudsOffset = Vector3.new(0, 4.5, 0)
	bgui.MaxDistance = 40
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

	model:GetAttributeChangedSignal("Health"):Connect(function()
		local h = model:GetAttribute("Health") or 0
		local maxH = model:GetAttribute("MaxHealth") or 100
		fill.Size = UDim2.new(math.clamp(h / maxH, 0, 1), 0, 1, 0)
	end)

	model.Parent = Workspace
	return model
end

return ScrapPileFactory

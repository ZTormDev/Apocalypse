-- ServerScriptService.Combat.CombatManager
-- Server-authoritative validation for both starter weapons. The client only ever suggests a
-- target (machete) or a direction (pistol); the server independently re-checks range/cooldown/
-- ammo and applies all damage. Also owns the player's PistolAmmo attribute.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local Net = require(Shared:WaitForChild("Net"))
local Tags = require(Shared:WaitForChild("Tags"))

local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local ScrapVfx = require(Modules:WaitForChild("ScrapVfx"))
local PickupVfx = require(Modules:WaitForChild("PickupVfx"))

local MACHETE = GameConfig.Machete
local PISTOL = GameConfig.Pistol

local macheteAttackEvent = Net.event("CombatEvents", "MacheteAttack")
local pistolFireEvent = Net.event("CombatEvents", "PistolFire")

-- ---------------------------------------------------------------------------------------
-- Scrap Machete (melee)
-- ---------------------------------------------------------------------------------------
local lastAttackTime: { [Player]: number } = {}

macheteAttackEvent.OnServerEvent:Connect(function(player, target)
	if typeof(target) ~= "Instance" or not target:IsDescendantOf(workspace) then
		return
	end

	local isMycomorph = CollectionService:HasTag(target, Tags.Mycomorph)
	local isScrap = (target.Name == "ScrapPile")

	if not isMycomorph and not isScrap then
		return
	end

	local char = player.Character
	local tool = char and char:FindFirstChild("Scrap Machete")
	if not tool then
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local now = os.clock()
	if now - (lastAttackTime[player] or 0) < MACHETE.ServerCooldown then
		return
	end

	local targetRoot = target.PrimaryPart
	if not targetRoot then
		return
	end

	local dist = (targetRoot.Position - root.Position).Magnitude
	if dist > MACHETE.ServerRange then
		return
	end

	lastAttackTime[player] = now

	-- Replicate machete hit to all clients for sound and visual playback
	macheteAttackEvent:FireAllClients(player, target, isScrap)

	if isMycomorph then
		local humanoid = target:FindFirstChild("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid:TakeDamage(MACHETE.Damage)
		end
	elseif isScrap then
		local currentHealth = target:GetAttribute("Health") or 0
		if currentHealth > 0 then
			local newHealth = math.max(0, currentHealth - MACHETE.Damage)
			target:SetAttribute("Health", newHealth)

			if newHealth <= 0 then
				local dropPos = targetRoot.Position

				-- The pile's PrimaryPart is a thin flat root at ground level, but the visible
				-- junk chunks stack several studs above and around it -- spawning the burst
				-- from just above the root buries it inside that geometry. Use the model's
				-- full bounding box so the burst starts clear above the whole pile instead.
				local boundingCFrame, boundingSize = target:GetBoundingBox()
				local burstPos = boundingCFrame.Position - Vector3.new(0, boundingSize.Y / 2, 0)
				ScrapVfx.destroyBurst(burstPos)

				target:Destroy()

				-- Spawn physical scrap items on the ground
				local SC = GameConfig.Scrap
				local scrapItemAsset = ReplicatedStorage:FindFirstChild("ScrapItemAsset")
				if scrapItemAsset then
					for i = 1, SC.PerPile do
						local dropModel = scrapItemAsset:Clone()
						dropModel.Name = "ScrapItemDropped"
						dropModel:ScaleTo(0.7)

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
									local ScrapWallet = require(game.ServerScriptService.modules.ScrapWallet)
									ScrapWallet.Add(collectingPlayer, 1) -- Each plaque yields exactly 1 scrap
								end)
							end)

							-- Scatter slightly on spawn
							dropModel:PivotTo(CFrame.new(dropPos + Vector3.new(
								math.random(-1, 1),
								math.random(1, 2),
								math.random(-1, 1)
							)))

							dropModel.Parent = workspace

							-- Apply physical dispersion impulse
							union.AssemblyLinearVelocity = Vector3.new(
								math.random(-8, 8),
								math.random(10, 18),
								math.random(-8, 8)
							)
						else
							dropModel:Destroy()
						end
					end
				else
					-- Fallback: award directly if asset is missing
					local ScrapWallet = require(game.ServerScriptService.modules.ScrapWallet)
					ScrapWallet.Add(player, SC.PerPile)
				end
				print(player.Name .. " mined and destroyed a ScrapPile.")
			else
				ScrapVfx.hit(targetRoot)
			end
		end
	end
end)

-- ---------------------------------------------------------------------------------------
-- Improvised Pistol (ranged): server does its own raycast along the aimed direction
-- ---------------------------------------------------------------------------------------
local lastPistolFire: { [Player]: number } = {}

local function initAmmo(player: Player)
	player:SetAttribute("PistolAmmo", PISTOL.StartingAmmo)
end

Players.PlayerAdded:Connect(initAmmo)
for _, player in ipairs(Players:GetPlayers()) do
	initAmmo(player)
end

pistolFireEvent.OnServerEvent:Connect(function(player, direction)
	if typeof(direction) ~= "Vector3" or direction.Magnitude == 0 then
		return
	end
	direction = direction.Unit

	local char = player.Character
	local tool = char and char:FindFirstChild("Improvised Pistol")
	if not tool then
		return
	end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local now = os.clock()
	if now - (lastPistolFire[player] or 0) < PISTOL.ServerCooldown then
		return
	end

	local ammo = player:GetAttribute("PistolAmmo") or 0
	if ammo <= 0 then
		return
	end

	lastPistolFire[player] = now
	player:SetAttribute("PistolAmmo", ammo - 1)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local origin = root.Position + Vector3.new(0, 1, 0)
	local targetPosition = origin + direction * PISTOL.Range
	local result = workspace:Raycast(origin, direction * PISTOL.Range, params)

	if result then
		targetPosition = result.Position
		local hitPart = result.Instance
		local model = hitPart:FindFirstAncestorOfClass("Model")
		if model and CollectionService:HasTag(model, Tags.Mycomorph) then
			local humanoid = model:FindFirstChild("Humanoid")
			if humanoid and humanoid.Health > 0 then
				humanoid:TakeDamage(PISTOL.Damage)
			end
		end
	end

	-- Replicate the shot to all clients for visual tracers
	pistolFireEvent:FireAllClients(player, origin, targetPosition)
end)

Players.PlayerRemoving:Connect(function(player)
	lastAttackTime[player] = nil
	lastPistolFire[player] = nil
end)

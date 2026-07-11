--!strict
-- ServerScriptService.modules.PickupVfx
-- Generic "absorb toward player" animation for ProximityPrompt pickups: instead of vanishing
-- the instant E is pressed, the item flies to (and shrinks into) the collecting player over a
-- short dynamic Lerp before actually being removed, following their real-time position.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioManager = require(Shared:WaitForChild("AudioManager"))

local PickupVfx = {}

local ABSORB_TIME = 0.45

-- Disables `prompt` immediately, locks/interpolates `part` toward `player`'s HumanoidRootPart
-- while shrinking it, then calls `onComplete`. This follows the player dynamically if they move.
function PickupVfx.absorb(part: BasePart, prompt: ProximityPrompt, player: Player, onComplete: () -> ())
	prompt.Enabled = false

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		onComplete()
		return
	end

	-- Play global pickup sound on the player's Head using the AudioManager
	local head = char:FindFirstChild("Head")
	if head then
		AudioManager.play("ItemPickup", head)
	end

	-- Force server network ownership so replication is authoritative and smooth
	pcall(function()
		part:SetNetworkOwner(nil)
	end)

	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false

	local startCFrame = part.CFrame
	local startSize = part.Size
	local startTime = os.clock()

	-- Connect to Heartbeat to update target position in real-time as the player moves
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock() - startTime
		local alpha = math.clamp(elapsed / ABSORB_TIME, 0, 1)

		if not root or not root.Parent then
			connection:Disconnect()
			onComplete()
			return
		end

		-- Quad Out Easing Curve: alpha * (2 - alpha)
		local t = alpha * (2 - alpha)

		-- Dynamically get the current player position
		local targetCFrame = CFrame.new(root.Position + Vector3.new(0, 0.5, 0))
		part.CFrame = startCFrame:Lerp(targetCFrame, t)
		part.Size = startSize:Lerp(startSize * 0.15, t)

		if alpha >= 1 then
			connection:Disconnect()
			onComplete()
		end
	end)
end

return PickupVfx

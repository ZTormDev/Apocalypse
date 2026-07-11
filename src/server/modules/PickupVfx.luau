--!strict
-- ServerScriptService.modules.PickupVfx
-- Generic "absorb toward player" animation for ProximityPrompt pickups: instead of vanishing
-- the instant E is pressed, the item flies to (and shrinks into) the collecting player over a
-- short tween before actually being removed.
local TweenService = game:GetService("TweenService")

local PickupVfx = {}

local ABSORB_TIME = 0.45

-- Disables `prompt` immediately (so it can't be re-triggered mid-animation), tweens `part`
-- toward `player`'s HumanoidRootPart while shrinking it, then calls `onComplete` (typically
-- Destroy the model + award the pickup). `part` is anchored for the duration of the tween so
-- physics doesn't fight it; if the player has no character, `onComplete` fires immediately.
function PickupVfx.absorb(part: BasePart, prompt: ProximityPrompt, player: Player, onComplete: () -> ())
	prompt.Enabled = false

	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then
		onComplete()
		return
	end

	-- A world item the player has walked up to is usually physics-owned by THAT client (Roblox
	-- auto-assigns network ownership of nearby unanchored parts). While the client owns it, the
	-- server's CFrame tween does NOT replicate back to that client -- the item just sits there
	-- and then vanishes on Destroy, with no visible animation. Forcing ownership back to the
	-- server (must happen while still unanchored) makes the server authoritative so the tween
	-- replicates to everyone. Wrapped in pcall since SetNetworkOwner errors on anchored parts.
	pcall(function()
		part:SetNetworkOwner(nil)
	end)

	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false

	-- EaseOut (not In): the item lifts and starts flying toward the player immediately, so the
	-- motion is perceptible even when picked up from point-blank range. EaseIn crammed almost
	-- all of the movement into the final frames, which read as an instant disappearance.
	local tweenInfo = TweenInfo.new(ABSORB_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(part, tweenInfo, {
		CFrame = CFrame.new(root.Position + Vector3.new(0, 1, 0)),
		Size = part.Size * 0.15,
	})

	tween.Completed:Connect(function()
		onComplete()
	end)
	tween:Play()
end

return PickupVfx

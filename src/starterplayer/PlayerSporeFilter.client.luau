-- StarterPlayerScripts.PlayerSporeFilter
-- Local prediction for the dome boundary: gas mask equip/unequip, the camera-based toxicity
-- screen filter, and the breath particle loop. The stat UI that used to live here was removed
-- (a replacement HUD is planned) -- this script is purely visual/cosmetic prediction now; the
-- server (PurifierManager) remains authoritative for FilterOxygen/damage.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")

-- Hide Roblox's native top-right health/status HUD.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
player.CharacterAdded:Connect(function(char)
	character = char
end)

local localMask = nil

local function updateLocalGasMask(isOutside)
	if not character then
		return
	end
	if isOutside then
		-- If a gas mask (local or server) already exists in the character, do nothing
		if character:FindFirstChild("GasMask") then
			return
		end

		local maskAsset = ReplicatedStorage:FindFirstChild("GasMask")
		if maskAsset then
			localMask = maskAsset:Clone()
			localMask.Name = "GasMask"
			localMask:SetAttribute("IsLocal", true)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid:AddAccessory(localMask)
			end
		end
	else
		if localMask then
			localMask:Destroy()
			localMask = nil
		end
	end
end

local function setupCharacterConnections(char)
	char.ChildAdded:Connect(function(child)
		if child.Name == "GasMask" and not child:GetAttribute("IsLocal") then
			-- The server replicated the real accessory; destroy our local predictive clone
			if localMask then
				localMask:Destroy()
				localMask = nil
			end
		end
	end)
end

if player.Character then
	setupCharacterConnections(player.Character)
end
player.CharacterAdded:Connect(function(char)
	character = char
	setupCharacterConnections(char)
end)

local stateFolder = ReplicatedStorage:WaitForChild("SporeTideState")
local purifier = workspace:WaitForChild("Purifier")

-- Visual effect setup
local colorCorrection = Lighting:FindFirstChild("ToxEffect")
if not colorCorrection then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "ToxEffect"
	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	colorCorrection.Saturation = 0
	colorCorrection.Contrast = 0
	colorCorrection.Parent = Lighting
end

-- Screen tint management: driven purely by the camera's world position (not the character's),
-- and applied instantly (no tween) so it snaps the moment the camera crosses the dome boundary --
-- this matters when the camera itself is outside the dome while the character isn't (e.g. free
-- cam, third-person orbit near the edge, etc).
local currentScreenTint = "safe"
local function updateScreenTint(isOutside)
	if isOutside and currentScreenTint ~= "toxic" then
		currentScreenTint = "toxic"
		colorCorrection.TintColor = Color3.fromRGB(190, 230, 190) -- Softer green tint (reduced intensity)
		colorCorrection.Saturation = -0.25                        -- Less extreme desaturation
		colorCorrection.Contrast = 0.05                           -- Softer contrast bump
	elseif not isOutside and currentScreenTint ~= "safe" then
		currentScreenTint = "safe"
		colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
		colorCorrection.Saturation = 0
		colorCorrection.Contrast = 0
	end
end

-- Prediction loop
RunService.RenderStepped:Connect(function()
	-- 1. Screen tint: purely camera-position-based, evaluated every frame regardless of
	-- character state so it always reflects exactly where the player is looking from.
	local camera = workspace.CurrentCamera
	if camera then
		local domeRadius = stateFolder:GetAttribute("DomeRadius") or 50.0
		local cameraIsOutside = (camera.CFrame.Position - purifier.Position).Magnitude > domeRadius
		updateScreenTint(cameraIsOutside)
	end

	-- 2. Predict local gas mask equipment (character-position-based, gameplay-authoritative)
	if character and character:FindFirstChild("HumanoidRootPart") and character:FindFirstChild("Humanoid") then
		local root = character.HumanoidRootPart
		local humanoid = character.Humanoid

		if humanoid.Health > 0 then
			local distance = (root.Position - purifier.Position).Magnitude
			local domeRadius = stateFolder:GetAttribute("DomeRadius") or 50.0
			updateLocalGasMask(distance > domeRadius)
		end
	end
end)

-- Periodic Gas Mask Breath/Exhalation Particle Emission
task.spawn(function()
	while true do
		task.wait(3.2) -- Exhale breath particles every 3.2 seconds
		if character and character.Parent then
			local mask = character:FindFirstChild("GasMask")
			if mask then
				local handle = mask:FindFirstChild("Handle")
				local emitter = handle and handle:FindFirstChild("BreathParticles", true) -- Recursive search
				if emitter then
					-- Emit a larger, more visible puff of 5 to 6 particles
					emitter:Emit(math.random(5, 6))
					print("GasMask exhaled breath particles.")
				end
			end
		end
	end
end)

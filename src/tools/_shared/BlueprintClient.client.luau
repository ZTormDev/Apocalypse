-- Blueprint build-mode client. ONE script shared by every buildable blueprint Tool (Wall,
-- Electric Fence, ...) via a common $path in the Rojo project -- it reads which structure it is
-- from Tool.Name and looks the rest up in GameConfig, so a new buildable is just a new config
-- row plus mapping the same script into its Tool.
--
-- Equip the blueprint to enter build mode: a ghost tracks the cursor, R rotates it (hinged
-- around the connection point when snapped), and clicking places it, consuming one charge.
-- The placement math is the shared PlacementGeometry module -- the exact same code the server
-- uses to validate -- so the preview can never disagree with what actually gets built.
local Tool = script.Parent
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local PlacementGeometry = require(Shared:WaitForChild("PlacementGeometry"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local placeStructureEvent = Net.event("BuildEvents", "PlaceStructure")

local structureType = Tool.Name -- "Wall" or "Electric Fence"
local def = GameConfig.Structures[structureType]
local size = def.Size

local BUILD = GameConfig.Building
local MAX_REACH = BUILD.MaxReach
local VALID_COLOR = BUILD.GhostValidColor
local INVALID_COLOR = BUILD.GhostInvalidColor
local VALID_TRANSPARENCY = BUILD.GhostValidTransparency
local INVALID_TRANSPARENCY = BUILD.GhostInvalidTransparency

local ghost = nil
local rotationY = 0
local lastRawPos = nil
local renderConn = nil

local function stopGhost()
	if ghost then
		ghost:Destroy()
		ghost = nil
	end
	if renderConn then
		renderConn:Disconnect()
		renderConn = nil
	end
end

local function startGhost()
	stopGhost()
	rotationY = 0

	ghost = Instance.new("Part")
	ghost.Name = "PlacementGhost"
	ghost.Size = size
	ghost.Material = Enum.Material.ForceField
	ghost.Color = VALID_COLOR
	ghost.Transparency = VALID_TRANSPARENCY
	ghost.Anchored = true
	ghost.CanCollide = false
	ghost.CanQuery = false
	ghost.CanTouch = false
	ghost.CastShadow = false
	-- Parented to the Tool itself (not Workspace) so if the server destroys the tool
	-- (last charge consumed), the ghost is torn down automatically as its child -- no reliance
	-- on Destroying/Unequipped firing in time. A Part's own CFrame still renders correctly in
	-- world space regardless of its parent.
	ghost.Parent = Tool

	renderConn = RunService.RenderStepped:Connect(function()
		if not ghost then
			return
		end
		if not mouse.Target then
			return
		end

		lastRawPos = mouse.Hit.Position
		local cf = PlacementGeometry.computeSnappedCFrame(lastRawPos, rotationY, size)
		ghost.CFrame = cf

		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local inReach = root and (lastRawPos - root.Position).Magnitude <= MAX_REACH
		local valid = inReach
			and PlacementGeometry.isWithinBuildZone(cf.Position)
			and not PlacementGeometry.isObstructed(cf, size, { char, ghost })

		if valid then
			ghost.Color = VALID_COLOR
			ghost.Transparency = VALID_TRANSPARENCY
		else
			ghost.Color = INVALID_COLOR
			ghost.Transparency = INVALID_TRANSPARENCY
		end
	end)
end

Tool.Equipped:Connect(startGhost)
Tool.Unequipped:Connect(stopGhost)

UserInputService.InputBegan:Connect(function(input, processed)
	if not ghost then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		rotationY += math.rad(90)
	end
end)

Tool.Activated:Connect(function()
	if not ghost or not lastRawPos then
		return
	end
	placeStructureEvent:FireServer(structureType, lastRawPos, rotationY)
end)

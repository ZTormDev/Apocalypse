-- ReplicatedStorage.Scrap.ScrapDropScript
-- While the Scrap tool is equipped, F drops one pile's worth (server handles the amount).
local Tool = script.Parent
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local dropEvent = Net.event("ScrapEvents", "DropScrap")

local connection = nil

Tool.Equipped:Connect(function()
	connection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			dropEvent:FireServer()
		end
	end)
end)

Tool.Unequipped:Connect(function()
	if connection then
		connection:Disconnect()
		connection = nil
	end
end)

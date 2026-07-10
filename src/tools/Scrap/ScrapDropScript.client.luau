-- ReplicatedStorage.Scrap.ScrapDropScript
local Tool = script.Parent
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScrapEvents = ReplicatedStorage:WaitForChild("ScrapEvents")
local dropEvent = ScrapEvents:WaitForChild("DropScrap")

local connection = nil

Tool.Equipped:Connect(function()
	connection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
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

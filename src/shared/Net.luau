--!strict
-- ReplicatedStorage.Shared.Net
-- Replaces the six hand-copied "find-or-create Folder + RemoteEvent" blocks that each manager
-- used to carry. Context-aware: on the server it creates the instance if missing; on the
-- client it waits for the server-created one to replicate. Both sides call it identically.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local isServer = RunService:IsServer()

local Net = {}

-- Returns the named RemoteEvent folder directly under ReplicatedStorage.
function Net.getFolder(name: string): Folder
	if isServer then
		local existing = ReplicatedStorage:FindFirstChild(name)
		if existing then
			return existing :: Folder
		end
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = ReplicatedStorage
		return folder
	end
	return ReplicatedStorage:WaitForChild(name) :: Folder
end

-- Returns the named RemoteEvent inside `folder`.
function Net.getEvent(folder: Instance, name: string): RemoteEvent
	if isServer then
		local existing = folder:FindFirstChild(name)
		if existing then
			return existing :: RemoteEvent
		end
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
		return event
	end
	return folder:WaitForChild(name) :: RemoteEvent
end

-- Convenience: fetch (or create) a folder and one of its events in a single call.
function Net.event(folderName: string, eventName: string): RemoteEvent
	return Net.getEvent(Net.getFolder(folderName), eventName)
end

return Net

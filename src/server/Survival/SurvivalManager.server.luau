-- ServerScriptService.Survival.SurvivalManager
-- Boots the shared SurvivalService (Health + Hunger simulation). The logic lives in the module
-- so ConsumableManager can call heal()/feed() on the same state; this script just starts it.
local ServerScriptService = game:GetService("ServerScriptService")
local Modules = ServerScriptService:WaitForChild("modules")
local SurvivalService = require(Modules:WaitForChild("SurvivalService"))

SurvivalService.start()

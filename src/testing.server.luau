local Players = game:GetService("Players")

local playerDataService = require(game.ReplicatedStorage.PlayerDataService).server

Players.PlayerAdded:Connect(function(player)
	local data = playerDataService.getPlayerDataAsync(player)

	if data then
		while task.wait(1) do
			data.coins:Increment(20)
		end
	end
end)

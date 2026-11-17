local Players = game:GetService("Players")

local playerDataService = require(game.ReplicatedStorage.PlayerDataService).server

Players.PlayerAdded:Connect(function(player)
	local data = playerDataService.getPlayerDataAsync(player)

	if data then
		local pet = data.pets:Insert({
			name = "Cat",
			scale = 1,
			mutations = {}
		})

		task.wait(2)

		pet.mutations:Insert("Lava")
		pet.mutations:Insert("T-T")
	end
end)

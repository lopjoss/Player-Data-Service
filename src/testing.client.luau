local playerData = require(game.ReplicatedStorage.PlayerDataService).client.getPlayerDataAsync()

playerData.coins:OnChanged():Connect(function(value: number, previousValue: number)
    print(value)
end)

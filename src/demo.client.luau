local playerData = require(game.ReplicatedStorage.PlayerDataService).client.getPlayerDataAsync()

playerData.pets:OnAdded():Connect(function(pet)
    print("PET ADDED:", pet)

    pet.mutations:OnAdded():Connect(function(mutation)
        print(`{pet.name.value} GOT A MUTATION: {mutation.value}`)
    end)
end)

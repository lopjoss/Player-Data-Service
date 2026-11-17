local playerDataService = require(game.ReplicatedStorage.Libs.PlayerDataService.Main)

type schema = {
	coins : number,
	discovered : {number},
	pets : {
		{
			name : string,
			scale : number,
			mutations : {string}
		}
	},
}

local template : schema = {
	coins = 0,
	discovered = {},
	pets = {}
}

return playerDataService.init<<schema>>(template)

local playerDataService = require(game.ReplicatedStorage.Libs.PlayerDataService.Main)

type schema = {
	coins : number,
	discovered : {number},
	inv : {
		pets : {
			{
				name : string,
				mutations : {
					[string] : {
						strengths : {
							a1 : {
								b1 : {
									[string] : {
										[number] : {
											c1 : boolean,
										},
									}
								},
							},
						},
					}
				},
			}
		},
	},
}

local template : schema = {
	coins = 0,
	discovered = {},
	inv = {
		pets = {
			{
				name = "Dog",
				mutations = {
					hi = {
						strengths = {
							a1 = {
								b1 = {
									hi = {
										[1] = {
											c1 = true
										}
									}
								}
							}
						}
					}
				}
			}
		}
	}
}

return playerDataService.init<<schema>>(template)

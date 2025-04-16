Config = {}

Config.Core = 'qb-core'
Config.Target = 'qb-target'
Config.Menu = 'qb-menu'
Config.VehicleKeys = 'qb-vehiclekeys'
Config.FuelSystem = 'LegacyFuel'

Config.JobNPC = {
    coords = vector4(156.72, -3084.13, 7.03, 177.53),
    model = 'a_m_y_business_03',
    scenario = "WORLD_HUMAN_CLIPBOARD",
}

Config.Boxes = {
    models = {"prop_boxpile_06b", "prop_boxpile_06b", "prop_boxpile_06b"},
    coords = {
        vector4(147.89, -3082.57, 5.9, 176.58),
        vector4(143.8, -3082.21, 5.9, 182.13),
        vector4(140.99, -3082.62, 5.9, 182.04)
    }
}

Config.Vehicles = {
    forklift = {
        model = "forklift",
        coords = vector4(143.11, -3085.43, 5.9, 283.86),
        heading = 270.0
    },
    truck = {
        model = "packer",
        coords = vector3(164.71, -3069.53, 6.0),
        heading = 270.0
    },
    trailer = {
        model = "trflat",
        coords = vector3(165.41, -3075.22, 5.66),
        heading = 270.0
    }
}

Config.DeliveryLocations = {
    {
        npcCoords = vector4(853.16, -2432.72, 28.07, 165.41),
        blipSprite = 501,
        blipColor = 5
    },
    {
        npcCoords = vector4(929.5, -2308.08, 30.65, 72.87),
        blipSprite = 501,
        blipColor = 5
    },
    {
        npcCoords = vector4(930.8, -1802.9, 30.66, 260.94),
        blipSprite = 501,
        blipColor = 5
    },
    {
        npcCoords = vector4(882.18, -1670.76, 31.78, 93.01),
        blipSprite = 501,
        blipColor = 5
    }
}

Config.Job = {
    rewardMin = 1000,
    rewardMax = 1500,
    requiredBoxes = 3,
    boxDetectionRange = 6.0,
    deliveryRange = 20.0,
    reputationEnabled = true,
    reputationReward = 1,
    requireItems = false,
    requiredItems = {'workpermit'},
    requireJob = false,
    requiredJob = 'trucker'
}

Config.Debug = false
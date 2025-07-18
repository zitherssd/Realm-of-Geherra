local settlementTypes = {
    village = {
        description = "Basic settlement, offers peasants and militia.",
        population = 100,
        recruitable_units = {"Peasant", "Militia"},
        color = {0.8, 0.6, 0.2},
    },
    city = {
        description = "Large city, offers soldiers and archers.",
        population = 500,
        recruitable_units = {"Soldier", "Archer"},
        color = {0.7, 0.7, 0.7},
    },
    port = {
        description = "Coastal port, offers advanced units.",
        population = 300,
        recruitable_units = {"Crossbowman", "Archer"},
        color = {0.2, 0.4, 0.8},
    },
    fortress = {
        description = "Military fortress, offers elite units.",
        population = 200,
        recruitable_units = {"Knight", "Soldier"},
        color = {0.5, 0.5, 0.5},
    },
    -- Add more settlement types as needed
}

return settlementTypes
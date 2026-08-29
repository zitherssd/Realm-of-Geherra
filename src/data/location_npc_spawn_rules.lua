return {
    village = {
        npcs = {
            { troopType = "elder",        count = 1, chance = 1.0  },
            { troopType = "trader",       count = 1, chance = 0.50 },
        },
        actions = {
            { label = "Recruit Volunteers",   action = "startRecruitmentDialogue",
              cooldown = { key = "lastRecruitDay", days = 5 }                     }
        }
    },
    town = {
        npcs = {
            { troopType = "elder",        count = 1, chance = 1.0  },
            { troopType = "trader",       count = 3, chance = 0.60 },
            { troopType = "soldier",      count = 2, chance = 0.15 },
            { troopType = "tavern_keeper",count = 1, chance = 1.0  }
        },
        actions = {
        }
    },
    castle = {
        npcs = {
            { troopType = "elder",  count = 1, chance = 1.0  },
            { troopType = "trader", count = 1, chance = 0.65 },
            { troopType = "soldier",count = 1, chance = 0.85 },
            { troopType = "knight", count = 1, chance = 0.45 }
        },
        actions = {
            { label = "Request Audience", action = "requestAudience" },
            { label = "Train Troops",     action = "trainTroops"     }
        }
    },
    ruins = {
        npcs = {},
        actions = {
            { label = "Explore Ruins", action = "exploreRuin", cooldown = { key = "lastExploreDay", days = 30 } }
        }
    },
    shrine = {
        npcs = {},
        actions = {
            { label = "Pray", action = "pray", cooldown = { key = "lastPrayDay", days = 15 } }
        }
    },
    bandit_camp = {
        npcs = {},
        actions = {
            { label = "Attack Bandit Camp", action = "attackBanditCamp" }
        }
    },
    windmill = {
        npcs = {
            { troopType = "tavern_keeper", count = 1, chance = 1.0 }
        },
        actions = {}
    }
}

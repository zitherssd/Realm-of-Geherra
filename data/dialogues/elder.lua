return {
    -- Entry point. Routes based on quest state or no-offer.
    -- The player picks ASK ABOUT QUEST to hear details before accepting.
    ["elder_greeting"] = {
        id = "elder_greeting",
        speaker = "Village Elder",
        -- Show dedicated intro dialogue on first meeting
        introDialogue = "elder_intro",
        -- Route to active/ready/completed if player has a hunt_dogs quest (specific)
        checkQuest = "hunt_dogs",
        -- Route to active/ready for ANY quest this NPC has accepted (catches deliver_message, etc.)
        checkActiveQuest = true,
        states = {
            active = "elder_quest_active",
            ready_to_turn_in = "elder_quest_ready_to_turn_in",
            completed = "elder_quest_completed"
        },
        -- When no quests are available, show the quiet dialogue
        noOfferDialogue = "elder_no_offers",
        lines = {
            {
                text = "Welcome, traveler. How can I help you?",
                options = {
                    { text = "Ask about work.", next = "elder_ask_about_quest", requiresQuestPool = true, requiresQuestOffer = true, allowBeforeIntroduction = true },
                    { text = "Heard any rumours?", next = "elder_rumors" },
                    { text = "I must be going.", next = "end" }
                }
            }
        }
    },

    -- First meeting: elder introduces himself, player picks humble or boastful response
    ["elder_intro"] = {
        id = "elder_intro",
        speaker = "Village Elder",
        lines = {
            {
                text = "I am Bogdan the Elder, keeper of this village. And you are?",
                options = {
                    { text = "I am but a humble traveler, seeking coin and purpose.", action = "meet_npc", set = { "introduced_humble" }, next = "elder_greeting" },
                    { text = "I am a warrior of renown. My name will echo in these hills.", action = "meet_npc", set = { "introduced_boastful" }, next = "elder_greeting" }
                }
            }
        }
    },

    -- No quests available
    ["elder_no_offers"] = {
        id = "elder_no_offers",
        speaker = "Village Elder",
        lines = {
            {
                text = "It's quiet around these parts at the moment. The gods willing, something will turn up.",
                options = {
                    { text = "I'll check back later.", next = "end" }
                }
            }
        }
    },

    -- Player asked about quests — route to quest-specific offer via checkOffer
    ["elder_ask_about_quest"] = {
        id = "elder_ask_about_quest",
        speaker = "Village Elder",
        checkOffer = {
            hunt_dogs = "elder_offer_hunt_dogs",
            pilgrimage = "elder_offer_pilgrimage",
            deliver_message = "elder_offer_deliver_message",
            deliver_item = "elder_offer_deliver_item",
            rescue_daughter = "elder_offer_rescue_daughter"
        },
        lines = {
            {
                text = "Let me see what needs doing...",
                options = {
                    { text = "Go on.", next = "end" }
                }
            }
        }
    },

    -- Rumours
    ["elder_rumors"] = {
        id = "elder_rumors",
        speaker = "Village Elder",
        lines = {
            {
                text = "Strange times, stranger still. Folk say the old roads are stirring with trouble — bandits in the hills, creatures driven from the deep woods by something darker. Keep your blade sharp and your wits sharper.",
                options = {
                    { text = "Good advice.", next = "elder_greeting" }
                }
            }
        }
    },

    -- Quest-specific offer texts (routed by checkOffer on elder_ask_about_quest)

    ["elder_offer_hunt_dogs"] = {
        id = "elder_offer_hunt_dogs",
        speaker = "Village Elder",
        lines = {
            {
                text = "A pack of wild dogs came down from the eastern woods three nights ago. Old Marek's sheep are gone, and the children cannot play beyond the fence anymore. The villagers are scared, and I cannot blame them. Drive the pack off before they grow bolder — or we start losing more than livestock.",
                options = {
                    { text = "I will track them down.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Not my concern.", next = "elder_greeting" }
                }
            }
        }
    },

    ["elder_offer_pilgrimage"] = {
        id = "elder_offer_pilgrimage",
        speaker = "Village Elder",
        lines = {
            {
                text = "The shrine at {target} has not received tribute since before the first frost. The goddess remembers — and if we neglect her, she will neglect our fields come spring. I have prepared the offerings: bundles of herbs, a clay amphora of oil, and a spiralled token carved by my own hand. They must be placed upon the altar before the new moon. Our legs are old and the roads are not safe. Will you carry the offerings for the village?",
                options = {
                    { text = "I will carry the offerings.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "I cannot take this on now.", next = "elder_greeting" }
                }
            }
        }
    },

    ["elder_offer_deliver_message"] = {
        id = "elder_offer_deliver_message",
        speaker = "Village Elder",
        lines = {
            {
                text = "A sealed message must reach the elders of {target}. I have written of the strange lights flickering in the hills, of the livestock found with their throats torn out by no natural beast, of the earth trembling beneath the old barrows. The elder there is an old friend — if the same troubles plague them, we must share what we know before the snows seal the passes. Our runners are few and the roads grow perilous. Will you carry my dispatch?",
                options = {
                    { text = "I'll deliver the message.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Find someone else.", next = "elder_greeting" }
                }
            }
        }
    },

    ["elder_offer_deliver_item"] = {
        id = "elder_offer_deliver_item",
        speaker = "Village Elder",
        lines = {
            {
                text = "We have finished a run of bronze tools — axe-heads, ploughshares, knife blanks — and a pouch of crushed gem-dust bound for {target}. Their forge has been cold since winter took their master smith. Without these goods, their children will go without warm cloaks when the next frost comes, and their fields will lie fallow for Want of a ploughshare. The bundle is valuable and I need someone trustworthy to see it there safely. Will you carry it?",
                options = {
                    { text = "I'll transport the goods.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Too risky for me.", next = "elder_greeting" }
                }
            }
        }
    },

    ["elder_offer_rescue_daughter"] = {
        id = "elder_offer_rescue_daughter",
        speaker = "Village Elder",
        lines = {
            {
                text = "The gods have abandoned us... Bandits took my daughter at dawn. They came through the mist like wolves — seven or eight of them, armed with iron and wearing scraps of old uniforms. They dragged her into the wilds, toward {target}. She is only twelve summers old. She has her mother's eyes and her mother's courage, but she is just a child. I have no one else to turn to. Please — I am begging you — bring her back before they move on and I lose her forever.",
                options = {
                    { text = "I will find her. I swear it.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "I am sorry, but I cannot.", next = "elder_greeting" }
                }
            }
        }
    },

    -- Generic fallback offer (used if templateId doesn't match a specific offer)
    ["elder_request"] = {
        id = "elder_request",
        speaker = "Village Elder",
        lines = {
            {
                text = "I have a task that needs doing. The village will be grateful for your help.",
                options = {
                    { text = "I will do what I can.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Not my concern.", next = "elder_greeting" }
                }
            }
        }
    },

    -- Shared quest state nodes (used by all quest types)

    ["elder_quest_accepted"] = {
        id = "elder_quest_accepted",
        speaker = "Village Elder",
        lines = {
            {
                text = "Thank you. The village is counting on you. Return to me when the deed is done.",
                options = {
                    { text = "I will return when it is done.", next = "end" }
                }
            }
        }
    },

    ["elder_quest_active"] = {
        id = "elder_quest_active",
        speaker = "Village Elder",
        lines = {
            {
                text = "Have you made any progress? The village still needs your help.",
                options = {
                    { text = "I am still working on it.", next = "end" }
                }
            }
        }
    },

    ["elder_quest_ready_to_turn_in"] = {
        id = "elder_quest_ready_to_turn_in",
        speaker = "Village Elder",
        lines = {
            {
                text = "You have returned. Was your task successful?",
                options = {
                    { text = "Yes. It is done.", action = "turn_in_available_quest", next = "elder_quest_completed", requiresQuestPool = true, requiresReadyToTurnIn = true },
                    { text = "Not yet.", next = "end" }
                }
            }
        }
    },

    ["elder_quest_completed"] = {
        id = "elder_quest_completed",
        speaker = "Village Elder",
        lines = {
            {
                text = "You have our deepest thanks. The village will not forget what you have done.",
                options = {
                    { text = "Glad I could help.", next = "end" }
                }
            }
        }
    },

    ["village_recruit"] = {
        id = "village_recruit",
        speaker = "Village Elder",
        lines = {
            {
                text = "A few able-bodied villagers look eager to join a new cause.",
                options = {
                    { text = "Recruit them (10 favor).", action = "recruit_volunteers" },
                    { text = "Leave them be.", next = "end" }
                }
            }
        }
    }
}

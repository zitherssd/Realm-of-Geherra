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
                text = "Welcome, traveler. Speak what you seek.",
                options = {
                    { text = "What task stands before this village?", next = "elder_ask_about_quest", requiresQuestPool = true, requiresQuestOffer = true, allowBeforeIntroduction = true },
                    { text = "What word runs along the roads?", next = "elder_rumors" },
                    { text = "I take my leave.", next = "end" }
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
                text = "I am Bogdan, elder of this hearth. Name yourself.",
                options = {
                    { text = "A plain traveler, seeking fair coin and worthy labor.", action = "meet_npc", set = { "introduced_humble" }, next = "elder_greeting" },
                    { text = "A proven spear. My name will stand in these hills.", action = "meet_npc", set = { "introduced_boastful" }, next = "elder_greeting" }
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
                text = "No burden calls today. If the gods will, need will rise again.",
                options = {
                    { text = "Then I will return in due time.", next = "end" }
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
                text = "Let us weigh what must be done.",
                options = {
                    { text = "Speak.", next = "end" }
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
                text = "These are lean days. Men speak of raiders in the hills and beasts driven from deep timber by a darker thing. Keep edge on your blade, and measure in your mind.",
                options = {
                    { text = "Your counsel is sound.", next = "elder_greeting" }
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
                text = "Three nights past, wild dogs came out of the eastern wood. Marek's sheep are gone, and children no longer cross the fence. Drive the pack off before they learn to hunt closer to our hearths.",
                options = {
                    { text = "I will track them.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "This burden is not mine.", next = "elder_greeting" }
                }
            }
        }
    },

    ["elder_offer_pilgrimage"] = {
        id = "elder_offer_pilgrimage",
        speaker = "Village Elder",
        lines = {
            {
                text = "The shrine at {target} has stood without tribute since before first frost. If we forget the goddess, she may forget our fields. Herbs, oil, and a carved token are prepared. Set them on the altar before new moon.",
                options = {
                    { text = "I will carry the offerings.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "I cannot bear this errand now.", next = "elder_greeting" }
                }
            }
        }
    },

    ["elder_offer_deliver_message"] = {
        id = "elder_offer_deliver_message",
        speaker = "Village Elder",
        lines = {
            {
                text = "A sealed dispatch must reach the elders of {target}. I have written of hill-lights, torn flocks, and trembling earth beneath old barrows. If they suffer the same, we must share counsel before snow closes the passes.",
                options = {
                    { text = "I will carry your dispatch.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Find another courier.", next = "elder_greeting" }
                }
            }
        }
    },

    ["elder_offer_deliver_item"] = {
        id = "elder_offer_deliver_item",
        speaker = "Village Elder",
        lines = {
            {
                text = "We have finished bronze axe-heads, ploughshares, knife blanks, and a pouch of gem-dust for {target}. Their forge has been cold since winter took their smith. Without these goods, fields fail and children shiver. The bundle must travel under trustworthy hands.",
                options = {
                    { text = "I will carry the goods.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "The risk is too great for me.", next = "elder_greeting" }
                }
            }
        }
    },

    ["elder_offer_rescue_daughter"] = {
        id = "elder_offer_rescue_daughter",
        speaker = "Village Elder",
        lines = {
            {
                text = "At dawn, raiders took my daughter. Seven or eight, iron-armed, out of the mist. They drove her toward {target}. She is twelve summers only. I have no stronger hand to call. Bring her back before their trail is lost.",
                options = {
                    { text = "I swear by hearth and steel: I will find her.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "Forgive me. I cannot take this vow.", next = "elder_greeting" }
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
                text = "A burden stands before us, and this village needs a steady hand.",
                options = {
                    { text = "I will do what I can.", action = "accept_available_quest", next = "elder_quest_accepted", requiresQuestPool = true, requiresQuestOffer = true },
                    { text = "This matter is not mine.", next = "elder_greeting" }
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
                text = "You have our thanks. Return when the deed is complete.",
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
                text = "What word do you bring? This village still leans on your labor.",
                options = {
                    { text = "The work is still in motion.", next = "end" }
                }
            }
        }
    },

    ["elder_quest_ready_to_turn_in"] = {
        id = "elder_quest_ready_to_turn_in",
        speaker = "Village Elder",
        lines = {
            {
                text = "You have returned. Did the work hold true?",
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
                text = "You have our deep thanks. This village will remember your deed.",
                options = {
                    { text = "May your hearth stand secure.", next = "end" }
                }
            }
        }
    },

    ["village_recruit"] = {
        id = "village_recruit",
        speaker = "Village Elder",
        lines = {
            {
                text = "A few strong villagers ask to bind their lot to yours.",
                options = {
                    { text = "Take them into the warband (10 favor).", action = "recruit_volunteers" },
                    { text = "Leave them to their homes.", next = "end" }
                }
            }
        }
    }
}

local Action = {}

function Action.execute(location)
    require("src.core.state_manager").push("dialogue", {
        location = location,
        dialogueTree = {speaker = location.name, lines = {
            {text = "Arcane markings cover the tower walls.", options = {{text = "Leave", next = "end"}}},
        }},
    })
end

return Action

-- Unit Template Loader
-- Loads unit templates from CSV files and converts them to the game's format

local csv = require('lib.csv')

local UnitTemplateLoader = {}

-- Map CSV column names to unit template fields
local columnMapping = {
    -- Basic info
    name = "name",
    hp = "health",
    prot = "protection",
    mr = "magicResistance",
    mor = "morale",
    str = "strength",
    att = "attack",
    def = "defense",
    prec = "precision",
    enc = "encumbrance",
    mapmove = "speed",
    size = "scale",
    
    -- Equipment slots (we'll build these dynamically)
    -- wp1-wp7, armor1-armor4 will be handled separately
}

-- Convert CSV data to unit template format
function UnitTemplateLoader.csvToTemplate(csvRow)
    local template = {}
    
    -- Map basic fields
    for csvCol, templateField in pairs(columnMapping) do
        if csvRow[csvCol] then
            template[templateField] = csvRow[csvCol]
        end
    end
    
    -- Build equipment slots from weapon and armor columns
    local equipmentSlots = {}
    
    -- Add weapon slots
    for i = 1, 7 do
        local wpnCol = "wp" .. i
        if csvRow[wpnCol] and csvRow[wpnCol] ~= "" then
            table.insert(equipmentSlots, "weapon_" .. i)
        end
    end
    
    -- Add armor slots
    for i = 1, 4 do
        local armorCol = "armor" .. i
        if csvRow[armorCol] and csvRow[armorCol] ~= "" then
            table.insert(equipmentSlots, "armor_" .. i)
        end
    end
    
    -- If no equipment slots found, add default ones
    if #equipmentSlots == 0 then
        equipmentSlots = { "main_hand", "off_hand", "chest" }
    end
    
    template.equipmentSlots = equipmentSlots
    
    -- Add abilities based on special properties
    local abilities = {}
    
    -- Map boolean properties to abilities
    local abilityProperties = {
        "flying", "aquatic", "undead", "demon", "magicbeing", "stonebeing", 
        "animal", "coldblood", "female", "stealthy", "illusion", "spy", 
        "assassin", "immortal", "reinc", "formationfighter", "slave",
        "inspiring", "taskmaster", "beastmaster", "bodyguard", "waterbreathing",
        "iceprot", "invulnerable", "fear", "berserk", "regeneration"
    }
    
    for _, prop in ipairs(abilityProperties) do
        if csvRow[prop] and csvRow[prop] ~= 0 and csvRow[prop] ~= "" then
            table.insert(abilities, prop)
        end
    end
    
    template.abilities = abilities
    
    -- Set default values for missing fields
    template.controllable = template.controllable or false
    
    return template
end

-- Load all unit templates from CSV
function UnitTemplateLoader.loadFromCSV(filePath)
    local csvData = csv.loadFile(filePath)
    local templates = {}
    
    for _, row in ipairs(csvData) do
        if row.id and row.name then
            local template = UnitTemplateLoader.csvToTemplate(row)
            templates[row.id] = template
        end
    end
    
    return templates
end

-- Merge CSV templates with existing Lua templates
function UnitTemplateLoader.mergeTemplates(existingTemplates, csvTemplates)
    local merged = {}
    
    -- Copy existing templates
    for id, template in pairs(existingTemplates) do
        merged[id] = template
    end
    
    -- Add/override with CSV templates
    for id, template in pairs(csvTemplates) do
        merged[id] = template
    end
    
    return merged
end

return UnitTemplateLoader 
local AssetManager = {}

local loadedImages = {}
local loadedFonts = {}
local loadedSounds = {}
local loadedQuads = {}

AssetManager.paths = {
    images = "assets/sprites/",
    fonts = "assets/fonts/",
    sounds = "assets/sounds/",
}

function AssetManager:loadImage(filename)
    if not loadedImages[filename] then
        local path = self.paths.images .. filename
        local success, result = pcall(love.graphics.newImage, path)
        if success then
            loadedImages[filename] = result
        else
            print("AssetManager: Failed to load image '" .. path .. "': " .. tostring(result))
            -- Create a 16x16 magenta placeholder
            local data = love.image.newImageData(16, 16)
            data:mapPixel(function() return 1, 0, 1, 1 end)
            loadedImages[filename] = love.graphics.newImage(data)
        end
    end
    return loadedImages[filename]
end

function AssetManager:loadFont(filename, size)
    local key = filename .. tostring(size)
    if not loadedFonts[key] then
        local path = self.paths.fonts .. filename
        loadedFonts[key] = love.graphics.newFont(path, size)
    end
    return loadedFonts[key]
end

function AssetManager:loadSound(filename)
    if not loadedSounds[filename] then
        local path = self.paths.sounds .. filename
        loadedSounds[filename] = love.audio.newSource(path, "static")
    end
    return loadedSounds[filename]
end

return AssetManager
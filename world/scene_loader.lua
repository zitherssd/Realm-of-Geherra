-- world/scene_loader.lua
-- Load and manage scenes/locations

local SceneLoader = {}

local loadedScenes = {}

function SceneLoader.loadScene(sceneId, sceneData)
    loadedScenes[sceneId] = sceneData
end

function SceneLoader.getScene(sceneId)
    return loadedScenes[sceneId]
end

function SceneLoader.unloadScene(sceneId)
    loadedScenes[sceneId] = nil
end

function SceneLoader.isSceneLoaded(sceneId)
    return loadedScenes[sceneId] ~= nil
end

return SceneLoader

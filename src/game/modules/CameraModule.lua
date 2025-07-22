local CameraModule = {}

CameraModule.x = 0
CameraModule.y = 0

function CameraModule:follow(target_x, target_y, map_width, map_height, screen_width, screen_height)
    -- Center camera on target
    local half_w = screen_width / 2
    local half_h = screen_height / 2
    local cam_x = target_x - half_w
    local cam_y = target_y - half_h
    -- Clamp to map edges
    cam_x = math.max(0, math.min(cam_x, math.max(0, map_width - screen_width)))
    cam_y = math.max(0, math.min(cam_y, math.max(0, map_height - screen_height)))
    self.x = cam_x
    self.y = cam_y
end

return CameraModule 
function love.conf(t)
    t.window.width = 1024
    t.window.height = 768
    t.window.title = "Realm of Geherra"
    t.window.resizable = true
    
    t.version = "11.4"
    
    t.identity = "realm-of-geherra"
    t.appendidentity = false
    
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = true
    t.modules.math = true
    t.modules.mouse = true
    t.modules.physics = false
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = false
    t.modules.timer = true
    t.modules.touch = true
    t.modules.video = true
    t.modules.window = true
end

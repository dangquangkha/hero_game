-- your-game/main.lua

-- Nạp thư viện nếu cần
local CombatManager = require 'src.systems.combat.CombatManager'

local combat

function love.load()
    -- LÖVE settings cơ bản
    love.graphics.setBackgroundColor(0.1, 0.1, 0.1) -- Nền tối để đạn nổi bật
    
    -- Khởi tạo sàn đấu
    combat = CombatManager()
end

function love.update(dt)
    combat:update(dt)
end

function love.draw()
    combat:draw()
end
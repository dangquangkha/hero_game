-- your-game/src/entities/projectiles/BulletPatterns.lua

local BulletPatterns = {}

-- Import các class đạn đã tạo
local Bullet = require 'src.entities.projectiles.Bullet'
local HomingBullet = require 'src.entities.projectiles.HomingBullet'
local LaserBeam = require 'src.entities.projectiles.LaserBeam'

--[[ 
    Tham số chung cho các hàm:
    - manager: Object quản lý pool đạn (BulletManager)
    - x, y: Tọa độ xuất phát (Thường là tọa độ Boss)
    - properties: Bảng chứa màu sắc, sát thương, kích thước, v.v.
]]

-- 1. CIRCLE BURST (Tỏa tròn đều) - Dùng cho: Petal Orb (Phase 1)
function BulletPatterns.circleBurst(manager, x, y, count, speed, properties)
    local angleStep = (2 * math.pi) / count -- Tính góc chia đều cho 360 độ
    
    for i = 1, count do
        local angle = (i - 1) * angleStep
        local bullet = Bullet(x, y, angle, speed, properties)
        manager:add(bullet)
    end
end

-- 2. CONE (Bắn hình nón / chùm tia) - Dùng cho: Needle Dart (Phase 1)
function BulletPatterns.cone(manager, x, y, targetX, targetY, count, spreadAngle, speed, properties)
    -- Tính góc trung tâm nhắm thẳng vào player
    local baseAngle = math.atan2(targetY - y, targetX - x)
    
    -- Tính góc bắt đầu (nửa bên trái của chùm đạn)
    local startAngle = baseAngle - (spreadAngle / 2)
    local angleStep = spreadAngle / (count > 1 and (count - 1) or 1)
    
    for i = 1, count do
        local angle = startAngle + (i - 1) * angleStep
        local bullet = Bullet(x, y, angle, speed, properties)
        manager:add(bullet)
    end
end

-- 3. RANDOM SCATTER (Bắn rải rác ngẫu nhiên) - Dùng cho: Bouncing Star (Phase 1)
function BulletPatterns.scatter(manager, x, y, count, speedMin, speedMax, properties)
    for i = 1, count do
        -- Random một góc bất kỳ từ trên xuống dưới (ví dụ từ -10 độ đến 190 độ)
        local randomAngle = math.random() * math.pi + (math.pi / 2) - 0.5
        local randomSpeed = math.random(speedMin, speedMax)
        
        local bullet = Bullet(x, y, randomAngle, randomSpeed, properties)
        manager:add(bullet)
    end
end

-- 4. HEAVY RAIN (Mưa đạn rơi từ trên xuống) - Dùng cho: Tracking Wisp (Phase 1), Shattered Soul (Phase 3)
function BulletPatterns.rain(manager, startX, startY, width, count, speed, properties)
    local stepX = width / count
    
    for i = 1, count do
        -- Trải đều tọa độ X theo chiều rộng màn hình
        local spawnX = startX + (i - 1) * stepX
        -- Mưa luôn rơi thẳng xuống (góc 90 độ = pi/2)
        local angle = math.pi / 2 
        
        local bullet
        -- Hỗ trợ sinh HomingBullet nếu properties quy định
        if properties.isHoming then
            bullet = HomingBullet(spawnX, startY, angle, speed, properties)
        else
            bullet = Bullet(spawnX, startY, angle, speed, properties)
        end
        manager:add(bullet)
    end
end

-- 5. SPIRAL (Bắn xoắn ốc) - Dùng cho: Phantom Dagger (Phase 2), Vortex Ribbon (Phase 3)
-- Lưu ý: Spiral thường được gọi trong hàm update() của Boss bằng cách tăng dần thông số `currentSpiralAngle`
function BulletPatterns.spiralPulse(manager, x, y, arms, currentAngle, speed, properties)
    local angleStep = (2 * math.pi) / arms -- Số luồng xoắn ốc (arms)
    
    for i = 1, arms do
        local angle = currentAngle + (i - 1) * angleStep
        local bullet = Bullet(x, y, angle, speed, properties)
        manager:add(bullet)
    end
end

-- 6. PINCER (Bắn gọng kìm 2 bên) - Dùng cho: Boomerang Crescent (Phase 1)
function BulletPatterns.pincer(manager, x, y, targetX, targetY, speed, properties)
    local baseAngle = math.atan2(targetY - y, targetX - x)
    
    -- Góc bắn lệch hẳn sang hai bên (trái và phải)
    local angleLeft = baseAngle - (math.pi / 2.5)
    local angleRight = baseAngle + (math.pi / 2.5)
    
    manager:add(Bullet(x, y, angleLeft, speed, properties))
    manager:add(Bullet(x, y, angleRight, speed, properties))
end

-- 7. LASER SWEEP (Tạo tia Laser) - Dùng cho: Laser Lotus (Phase 2)
function BulletPatterns.spawnLaser(manager, sourceBoss, offsetX, offsetY, targetAngle, properties)
    -- Thay vì tạo đạn bay, nó tạo 1 object tia Laser
    local laser = LaserBeam(sourceBoss, offsetX, offsetY, targetAngle, properties)
    manager:add(laser)
end

return BulletPatterns
-- your-game/src/entities/bosses/types/DemonKing.lua

local class = require 'libs.middleclass.middleclass' -- Đảm bảo bạn đã cài đặt thư viện middleclass
-- Import lớp cha
local Boss = require 'src.entities.bosses.Boss'
local BulletPatterns = require 'src.entities.projectiles.BulletPatterns'

-- Kế thừa từ Base Boss
local DemonKing = class('DemonKing', Boss)

function DemonKing:initialize(x, y, combatManager)
    -- Gọi constructor của lớp cha và truyền vào HP đặc thù của Demon King (Ví dụ: 3000)
    Boss.initialize(self, x, y, combatManager, 3000)
    
    -- Nếu muốn Demon King có ngưỡng chuyển phase khác biệt (VD: 70% và 40%),
    -- bạn hoàn toàn có thể ghi đè tại đây:
    -- self.phaseManager:setThresholds({{hpRatio = 0.7, phase = 2}, {hpRatio = 0.4, phase = 3}})
end

-- Ghi đè hàm Hook khi chuyển Phase
function DemonKing:onPhaseChange(newPhase)
    -- Gọi logic dọn dẹp đạn cơ bản của lớp cha
    Boss.onPhaseChange(self, newPhase)
    
    -- Áp dụng thay đổi độ khó đặc thù của Demon King
    if newPhase == 2 then
        self.attackCooldown = 1.5 -- Đánh nhanh hơn
    elseif newPhase == 3 then
        self.attackCooldown = 0.8 -- Điên cuồng (Bullet Hell)
    end
end

-- Ghi đè hàm gọi đòn tấn công
function DemonKing:castAttack()
    self.state = "attacking"
    local player = self.combatManager.player
    local bManager = self.combatManager.bulletManager
    
    -- Lấy Phase hiện tại thông qua hàm của lớp cha
    local currentPhase = self:getCurrentPhase()
    
    -- Lựa chọn list chiêu thức dựa trên Phase
    if currentPhase == 1 then
        self:executePhase1Attacks(bManager, player)
    elseif currentPhase == 2 then
        self:executePhase2Attacks(bManager, player)
    elseif currentPhase == 3 then
        self:executePhase3Attacks(bManager, player)
    end
    
    -- Xoay vòng bộ 6 chiêu thức tuần tự
    self.currentAttackIndex = self.currentAttackIndex + 1
    if self.currentAttackIndex > 6 then
        self.currentAttackIndex = 1
    end
    
    self.state = "idle"
end

-- ==========================================
-- DANH SÁCH CHIÊU THỨC TỪNG PHASE
-- ==========================================

function DemonKing:executePhase1Attacks(bManager, player)
    local idx = self.currentAttackIndex
    
    if idx == 1 then
        -- 1. Petal Orb: Circle Burst 16 tia, bay chậm
        BulletPatterns.circleBurst(bManager, self.x, self.y, 16, 150, {radius = 6, color = {1, 0.5, 0.8}})
        
    elseif idx == 2 then
        -- 2. Needle Dart: Bắn nón 3 tia, khựng 1s rồi lao cực nhanh
        BulletPatterns.cone(bManager, self.x, self.y, player.x, player.y, 3, math.pi/4, 0, 
            {shape = "needle", color = {0.8, 1, 0.2}, delay = 1.0, acceleration = 800, maxSpeed = 1000})
            
    elseif idx == 3 then
        -- 3. Boomerang Crescent: Bắn 2 tia gọng kìm 
        BulletPatterns.pincer(bManager, self.x, self.y, player.x, player.y, 250, {radius = 8, color = {1, 1, 0}})
        
    elseif idx == 4 then
        -- 4. Bouncing Star: Bắn rải rác ngẫu nhiên lên trên, dội tường 1 lần
        BulletPatterns.scatter(bManager, self.x, self.y, 8, 200, 350, {type = "star", color = {1, 0.8, 0}, bounceCount = 1})
        
    elseif idx == 5 then
        -- 5. Pulsing Ring (Rào cản): Bắn chùm 8 tia xen kẽ
        BulletPatterns.circleBurst(bManager, self.x, self.y, 8, 120, {radius = 15, color = {0, 1, 1}})
        
    elseif idx == 6 then
        -- 6. Tracking Wisp: Mưa đạn rơi từ trên có tính năng đuổi 2 giây
        BulletPatterns.rain(bManager, 0, 0, love.graphics.getWidth(), 10, 100, 
            {isHoming = true, target = player, homingPower = 1.5, homingDuration = 2.0, color = {0.3, 0.1, 0.9}})
    end
end

function DemonKing:executePhase2Attacks(bManager, player)
    local idx = self.currentAttackIndex
    
    -- Ở Phase 2 (The Illusion), Boss bắt đầu dùng Laser và các đòn cắt góc
    if idx == 1 then
        -- Laser Lotus: Quét ngang màn hình
        BulletPatterns.spawnLaser(bManager, self, 0, 0, math.pi, {width = 40, telegraph = 1.0, duration = 2.5, sweepSpeed = 1.2, color = {1, 0.2, 0.5}})
    else
        -- Ví dụ thay thế cho Fractal Prism / Phantom Dagger
        BulletPatterns.circleBurst(bManager, self.x, self.y, 24, 200, {radius = 4, color = {0.5, 0, 1}})
    end
end

function DemonKing:executePhase3Attacks(bManager, player)
    -- Ở Phase 3 (Absolute Despair), tốc độ đánh là 0.8s, tạo ra ma trận đạn thật sự
    BulletPatterns.circleBurst(bManager, self.x, self.y, 36, 300, {radius = 3, color = {1, 0, 0}})
    BulletPatterns.cone(bManager, self.x, self.y, player.x, player.y, 5, math.pi/2, 400, {radius = 5, color = {0, 0, 0}})
    
    -- Cứ mỗi 3 nhịp đạn bay sẽ có một vệt Laser khổng lồ nhắm thẳng vào player
    if self.currentAttackIndex % 3 == 0 then
        -- Death Lock Ray
        BulletPatterns.spawnLaser(bManager, self, 0, 0, math.atan2(player.y - self.y, player.x - self.x), {width = 100, telegraph = 1.5, duration = 0.5, color = {1, 0, 0}})
    end
end

function DemonKing:draw()
    -- Vẽ ngoại hình Boss
    love.graphics.setColor(0.8, 0.1, 0.1)
    love.graphics.rectangle("fill", self.x - 30, self.y - 30, 60, 60)
    love.graphics.setColor(1, 1, 1)
end

return DemonKing
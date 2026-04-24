-- your-game/src/systems/combat/CombatManager.lua

local class = require 'libs.middleclass'

-- Import các hệ thống và Entity liên quan
local BulletManager = require 'src.systems.combat.BulletManager'
local DemonKing = require 'src.entities.bosses.types.DemonKing'
-- local Player = require 'src.entities.player.Player' -- (Sẽ bật lên khi bạn viết xong file Player.lua)

local CombatManager = class('CombatManager')

function CombatManager:initialize()
    -- 1. Khởi tạo Quản lý Đạn (Bullet Pool)
    self.bulletManager = BulletManager()

    -- 2. Khởi tạo Player tạm thời (Mockup) để test
    -- Trong thực tế, bạn sẽ khởi tạo object Player thật từ class Player
    self.player = {
        x = love.graphics.getWidth() / 2,
        y = love.graphics.getHeight() - 100,
        hitboxRadius = 3, -- Hitbox cực nhỏ (3 pixel) - Đặc trưng chuẩn của Danmaku/Touhou
        isDead = false,
        hp = 100,
        takeDamage = function(self_player, amount)
            self_player.hp = self_player.hp - amount
            if self_player.hp <= 0 then
                self_player.hp = 0
                self_player.isDead = true
                print("Player Died!")
            end
        end,
        update = function(self_player, dt)
            -- Tích hợp input di chuyển cơ bản để test khả năng micro-dodge
            local speed = 250
            -- Nhấn giữ Shift để đi chậm (Focus Mode) - Kỹ năng sinh tồn cơ bản trong Bullet Hell
            if love.keyboard.isDown("lshift") then speed = 100 end 

            if love.keyboard.isDown("left") then self_player.x = self_player.x - speed * dt end
            if love.keyboard.isDown("right") then self_player.x = self_player.x + speed * dt end
            if love.keyboard.isDown("up") then self_player.y = self_player.y - speed * dt end
            if love.keyboard.isDown("down") then self_player.y = self_player.y + speed * dt end
        end,
        draw = function(self_player)
            -- Vẽ nhân vật (hình vuông xanh nhạt)
            love.graphics.setColor(0, 0.5, 1)
            love.graphics.rectangle("fill", self_player.x - 10, self_player.y - 10, 20, 20)
            
            -- Vẽ Hitbox thật sự (chấm đỏ ở giữa) - Chỉ trúng đạn khi viên đạn chạm vào chấm này
            love.graphics.setColor(1, 0, 0)
            love.graphics.circle("fill", self_player.x, self_player.y, self_player.hitboxRadius)
            love.graphics.setColor(1, 1, 1)
        end
    }

    -- 3. Khởi tạo Boss ở giữa nửa trên màn hình
    -- Truyền `self` (tức là CombatManager hiện tại) vào để Boss có thể gọi player và bulletManager
    local startX = love.graphics.getWidth() / 2
    local startY = 150
    self.boss = DemonKing(startX, startY, self)
end

function CombatManager:update(dt)
    -- Cập nhật Player
    if not self.player.isDead then
        self.player:update(dt)
    end

    -- Cập nhật Boss
    if self.boss and not self.boss.isDead then
        self.boss:update(dt)
        
        -- Phím tắt Debug: Nhấn Space để trừ 100 máu Boss (Test chuyển Phase)
        if love.keyboard.isDown("space") then
            self.boss:takeDamage(100 * dt)
        end
    end

    -- Cập nhật toàn bộ Đạn, truyền player vào để xét va chạm Collision
    self.bulletManager:update(dt, self.player)
end

function CombatManager:draw()
    -- Lớp vẽ 1: Vẽ Boss (nằm dưới cùng)
    if self.boss and not self.boss.isDead then
        self.boss:draw()
    end

    -- Lớp vẽ 2: Vẽ Đạn (Vẽ trên Boss nhưng nằm dưới Player để Player dễ nhìn hitbox của mình)
    self.bulletManager:draw()

    -- Lớp vẽ 3: Vẽ Player (Luôn đè lên trên cùng để không bị đạn che lấp hitbox)
    if not self.player.isDead then
        self.player:draw()
    end
    
    -- Lớp vẽ 4: UI Debug tạm thời (Hiển thị góc trên cùng bên trái)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Boss HP: " .. math.floor(self.boss.hp) .. " / " .. self.boss.maxHp, 10, 10)
    love.graphics.print("Boss Phase: " .. self.boss:getCurrentPhase(), 10, 30)
    love.graphics.print("Player HP: " .. math.floor(self.player.hp), 10, 50)
    love.graphics.print("Bullets Count: " .. self.bulletManager:getCount(), 10, 70)
    love.graphics.print("[Hold SPACE] to drain Boss HP", 10, 90)
    love.graphics.print("[Hold SHIFT] for Focus Mode", 10, 110)
end

return CombatManager
-- =============================================================================
-- BULLET MANAGER CLASS (BỘ NÃO QUẢN LÝ ĐẠN)
-- =============================================================================
-- Mô tả: Điều phối toàn bộ vòng đời của đạn: Sinh ra, Di chuyển, Va chạm và Biến mất.
-- Chức năng chính: Xử lý va chạm giữa đạn và Player.
-- =============================================================================

local class = require 'libs.middleclass'
local BulletManager = class('BulletManager')

function BulletManager:initialize()
    -- Bảng (Array) chứa tất cả các vật thể bay hiện có trên sân đấu
    -- Bao gồm cả Bullet, HomingBullet và LaserBeam.
    self.projectiles = {} 
end

--- Thêm đạn vào danh sách quản lý
-- Hàm này thường được gọi từ các Pattern (BulletPatterns)
function BulletManager:add(projectile)
    table.insert(self.projectiles, projectile)
end

--- Cập nhật logic của tất cả đạn mỗi khung hình
-- @param dt: Delta time
-- @param player: Đối tượng người chơi để kiểm tra va chạm
function BulletManager:update(dt, player)
    -- [MẸO LẬP TRÌNH]: Duyệt mảng NGƯỢC (từ cuối lên đầu)
    -- Khi xóa một phần tử ở giữa mảng trong Lua, các phần tử phía sau sẽ bị dồn lên.
    -- Nếu duyệt xuôi (1 -> n), ta sẽ bị nhảy cóc phần tử, gây sót đạn hoặc lỗi index.
    for i = #self.projectiles, 1, -1 do
        local p = self.projectiles[i]
        
        -- 1. Cập nhật vị trí/logic của viên đạn
        p:update(dt)
        
        -- 2. Kiểm tra va chạm (Collision)
        -- Chỉ kiểm tra nếu đạn chưa chết, player tồn tại và player chưa chết.
        if not p.isDead and player and not player.isDead then
            self:checkCollision(p, player)
        end
        
        -- 3. Dọn rác (Memory Cleanup)
        -- Nếu đạn đã bay ra ngoài (isDead = true), xóa nó khỏi mảng để giải phóng RAM.
        if p.isDead then
            table.remove(self.projectiles, i)
        end
    end
end

--- Hệ thống xử lý va chạm trung tâm
function BulletManager:checkCollision(projectile, player)
    
    -- TRƯỜNG HỢP A: Đối tượng là Laser (Kiểm tra va chạm dạng thanh dài)
    if projectile.class.name == "LaserBeam" then
        if projectile:isLethal() then -- Chỉ gây dame khi Laser đang ở trạng thái 'firing'
            
            -- Dùng toán học Vector để tính khoảng cách từ tâm Player đến tia Laser
            local dx = player.x - projectile.x
            local dy = player.y - projectile.y
            local lineDx = math.cos(projectile.angle)
            local lineDy = math.sin(projectile.angle)
            
            -- Tính 'Dot Product' để tìm vị trí hình chiếu của Player trên đường thẳng Laser
            local dotProduct = dx * lineDx + dy * lineDy
            
            -- Kiểm tra xem Player có nằm trong phạm vi chiều dài của tia Laser không
            if dotProduct > 0 and dotProduct < projectile.length then
                -- Tính khoảng cách vuông góc từ Player đến lõi Laser (dùng công thức Cross Product)
                local dist = math.abs(lineDx * dy - lineDy * dx)
                
                -- Nếu khoảng cách nhỏ hơn (Độ dày Laser / 2 + Hitbox Player) thì coi như trúng đạn
                if dist < (projectile.width / 2 + player.hitboxRadius) then
                    player:takeDamage(1) -- Laser gây sát thương đa điểm theo thời gian
                end
            end
        end
        
    -- TRƯỜNG HỢP B: Đạn tròn thông thường (Bullet, HomingBullet)
    else
        -- Tối ưu hóa hiệu năng: Circle-Circle Collision
        local dx = projectile.x - player.x
        local dy = projectile.y - player.y
        
        -- [MẸO TỐI ƯU]: Dùng bình phương khoảng cách (Distance Squared)
        -- Thay vì dùng math.sqrt(dx*dx + dy*dy), ta so sánh trực tiếp với bình phương bán kính.
        -- Việc này giúp CPU không phải tính căn bậc hai (một phép tính rất nặng).
        local distanceSq = dx * dx + dy * dy 
        local radiusSum = projectile.radius + player.hitboxRadius
        
        if distanceSq < (radiusSum * radiusSum) then
            -- Xử lý khi Player trúng đạn
            player:takeDamage(projectile.damage)
            -- Đạn tròn thường sẽ biến mất ngay khi chạm vào người chơi
            projectile:destroy() 
        end
    end
end

--- Vẽ toàn bộ các thực thể bay
function BulletManager:draw()
    -- Duyệt xuôi để vẽ đạn theo thứ tự được tạo ra
    for i = 1, #self.projectiles do
        self.projectiles[i]:draw()
    end
end

--- Xóa sạch mọi viên đạn trên màn hình
-- Thường dùng khi chuyển cảnh, Player chết, hoặc Boss đổi Phase (Phase Clear)
function BulletManager:clear()
    self.projectiles = {}
end

--- Lấy số lượng đạn hiện tại (Dùng để hiển thị Debug trên màn hình)
function BulletManager:getCount()
    return #self.projectiles
end

return BulletManager
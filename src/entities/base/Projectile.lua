-- =============================================================================
-- PROJECTILE BASE CLASS
-- =============================================================================
-- Mô tả: Lớp cơ sở cho tất cả các vật thể bay (đạn, laser, tên lửa...).
-- Chức năng: Quản lý vị trí, vận tốc, và vòng đời cơ bản của một thực thể bay.
-- Lưu ý: Đây là lớp cha, thường không được tạo trực tiếp mà thông qua các lớp con.
-- =============================================================================

local class = require 'libs.middleclass'

-- Khởi tạo class Projectile bằng thư viện middleclass
local Projectile = class('Projectile')

--- Hàm khởi tạo (Constructor): Thiết lập các thông số ban đầu khi vật thể được tạo ra.
-- @param x (number): Tọa độ X ban đầu.
-- @param y (number): Tọa độ Y ban đầu.
-- @param angle (number): Góc bắn (tính bằng Radian).
-- @param speed (number): Tốc độ di chuyển (pixel trên giây).
function Projectile:initialize(x, y, angle, speed)
    -- 1. Quản lý vị trí (Position)
    self.x = x or 0
    self.y = y or 0
    
    -- 2. Quản lý Vector di chuyển (Movement)
    -- Góc (angle) kết hợp với tốc độ (speed) sẽ tạo ra vận tốc có hướng.
    self.angle = angle or 0
    self.speed = speed or 0
    
    -- 3. Quản lý Trạng thái (State)
    self.isDead = false -- Nếu là true, hệ thống quản lý đạn sẽ xóa đối tượng này để giải phóng bộ nhớ.
    self.timer = 0      -- Đếm thời gian (giây) kể từ khi đạn xuất hiện.
    
    -- 4. Thuộc tính vật lý cơ bản (Collision)
    -- Bán kính va chạm (Hitbox). Các lớp con có thể thay đổi giá trị này.
    self.radius = 4 
end

--- Hàm cập nhật (Update): Xử lý logic di chuyển và kiểm tra điều kiện tồn tại mỗi khung hình.
-- @param dt (number): Delta time - thời gian trôi qua giữa 2 khung hình (giúp game chạy ổn định ở mọi FPS).
function Projectile:update(dt)
    -- Tăng thời gian sống của vật thể
    self.timer = self.timer + dt
    
    -- TOÁN HỌC: Chuyển đổi từ tọa độ cực (Góc & Tốc độ) sang tọa độ Cartesian (X & Y)
    -- vx = cos(góc) * tốc độ
    -- vy = sin(góc) * tốc độ
    local vx = math.cos(self.angle) * self.speed
    local vy = math.sin(self.angle) * self.speed
    
    -- Cập nhật tọa độ mới dựa trên vận tốc và thời gian trôi qua
    self.x = self.x + vx * dt
    self.y = self.y + vy * dt
    
    -- Kiểm tra nếu vật thể đã bay khuất màn hình quá xa thì đánh dấu xóa bỏ
    self:checkOutOfBounds()
end

--- Hàm vẽ (Draw): Hiển thị hình ảnh vật thể.
-- LƯU Ý: Lớp cha Projectile để trống hàm này. 
-- Các lớp con (như Bullet, Laser) PHẢI ghi đè (override) hàm này để vẽ hình ảnh riêng của chúng.
function Projectile:draw()
    -- Ví dụ ở lớp con: love.graphics.circle("fill", self.x, self.y, self.radius)
end

--- Kiểm tra ranh giới: Tự động hủy vật thể khi bay ra ngoài màn hình.
-- Điều này cực kỳ quan trọng để tránh "rò rỉ bộ nhớ" (Memory Leak) khi có hàng ngàn viên đạn bay mất.
function Projectile:checkOutOfBounds()
    -- Khoảng lề (margin) giúp đạn biến mất mượt mà hơn khi đã thực sự khuất hẳn.
    local margin = 100 
    local screenW = love.graphics.getWidth()
    local screenH = love.graphics.getHeight()
    
    -- Kiểm tra 4 cạnh màn hình (Trái, Phải, Trên, Dưới)
    if self.x < -margin or self.x > screenW + margin or
       self.y < -margin or self.y > screenH + margin then
        self:destroy() -- Gọi hàm hủy nếu vượt quá giới hạn
    end
end

--- Hàm hủy (Destroy): Đánh dấu vật thể đã kết thúc vòng đời.
-- Có thể gọi hàm này khi đạn trúng mục tiêu hoặc bị nổ.
function Projectile:destroy()
    self.isDead = true
end

return Projectile
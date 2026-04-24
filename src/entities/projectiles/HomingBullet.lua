-- =============================================================================
-- HOMING BULLET CLASS (LỚP ĐẠN ĐUỔI MỤC TIÊU)
-- =============================================================================
-- Mô tả: Kế thừa từ Bullet. Có khả năng tự động bẻ lái hướng về phía mục tiêu.
-- Cơ chế: Sử dụng toán học lượng giác để tính toán góc quay ngắn nhất.
-- Ứng dụng: Tạo các loại đạn ma mị, tên lửa tầm nhiệt.
-- =============================================================================

local class = require 'libs.middleclass.middleclass' -- Đảm bảo bạn đã cài đặt thư viện middleclass

-- Import lớp Bullet (Vì HomingBullet cần các thuộc tính hình dáng, màu sắc của Bullet)
local Bullet = require 'src.entities.projectiles.Bullet'

-- Khởi tạo class HomingBullet kế thừa từ Bullet
local HomingBullet = class('HomingBullet', Bullet)

--- Hàm khởi tạo đạn đuổi
-- @param properties.target: Đối tượng đạn sẽ đuổi theo (ví dụ: nhân vật Player).
-- @param properties.homingPower: Độ nhạy khi bẻ lái (số càng cao xoay càng gắt).
-- @param properties.homingDuration: Thời gian đạn còn khả năng đuổi (sau đó sẽ bay thẳng).
function HomingBullet:initialize(x, y, angle, speed, properties)
    -- [BƯỚC 1] Gọi lại constructor của lớp cha (Bullet) 
    -- Để tận dụng các thiết lập về màu sắc, damage, delay...
    Bullet.initialize(self, x, y, angle, speed, properties)
    
    properties = properties or {}
    
    -- [BƯỚC 2] Thiết lập các thuộc tính chuyên biệt cho việc đuổi mục tiêu
    self.target = properties.target                  -- Đối tượng mục tiêu (thường là Player)
    self.homingPower = properties.homingPower or 3.0 -- Tốc độ bẻ lái (Radian trên giây)
    
    -- Giới hạn thời gian đuổi mục tiêu
    -- Ví dụ: Đạn chỉ đuổi trong 2 giây đầu để tạo cơ hội cho người chơi né tránh.
    self.homingDuration = properties.homingDuration or 2.0 
end

--- Hàm cập nhật logic di chuyển thông minh
function HomingBullet:update(dt)
    -- [BƯỚC 1] Kiểm tra điều kiện để thực hiện bẻ lái:
    -- 1. Thời gian sống (timer) vẫn trong tầm cho phép (homingDuration).
    -- 2. Mục tiêu tồn tại và vẫn còn sống (không bị nil hoặc isDead).
    if self.timer < self.homingDuration and self.target and not self.target.isDead then
        
        -- A. TÍNH GÓC LÝ TƯỞNG:
        -- Dùng math.atan2 để tìm góc từ vị trí hiện tại của đạn đến vị trí của mục tiêu.
        local targetAngle = math.atan2(self.target.y - self.y, self.target.x - self.x)
        
        -- B. TÍNH KHOẢNG CÁCH GÓC (Angle Difference):
        -- Hiệu số giữa góc đạn nên bay và góc đạn đang bay.
        local angleDiff = targetAngle - self.angle
        
        -- C. CHUẨN HÓA GÓC (Góc quay ngắn nhất):
        -- Đảm bảo đạn luôn chọn hướng xoay gần nhất thay vì xoay cả vòng lớn.
        -- Chúng ta ép hiệu số góc về khoảng từ $-\pi$ đến $\pi$.
        while angleDiff > math.pi do angleDiff = angleDiff - 2 * math.pi end
        while angleDiff < -math.pi do angleDiff = angleDiff + 2 * math.pi end
        
        -- D. THỰC HIỆN BẺ LÁI:
        -- Thay vì quay ngoắt lập tức, đạn sẽ xoay từ từ dựa trên homingPower.
        -- Điều này tạo cảm giác đạn bay lượn mềm mại và tự nhiên hơn.
        self.angle = self.angle + angleDiff * self.homingPower * dt
    end
    
    -- [BƯỚC 2] Gọi hàm update của lớp cha (Bullet)
    -- Sau khi đã có góc bay mới (angle), ta để lớp cha tính toán x, y và di chuyển.
    Bullet.update(self, dt)
end

--- Hàm vẽ đạn với hiệu ứng "Ma trôi" (Wisp)
-- Ghi đè hàm draw để tạo ngoại hình huyền ảo hơn đạn thường.
function HomingBullet:draw()
    -- 1. Vẽ vầng hào quang (Aura)
    -- Vẽ một vòng tròn lớn hơn với độ trong suốt (Alpha) thấp (0.3).
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.3)
    love.graphics.circle("fill", self.x, self.y, self.radius * 1.8)
    
    -- 2. Vẽ phần lõi sáng bên trong
    -- Vẽ vòng tròn đúng kích thước với độ đậm đặc 100%.
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 1)
    love.graphics.circle("fill", self.x, self.y, self.radius)
    
    -- 3. Reset màu về mặc định
    love.graphics.setColor(1, 1, 1, 1)
end

return HomingBullet
-- =============================================================================
-- LASER BEAM CLASS (LỚP TIA LASER TỬ THẦN)
-- =============================================================================
-- Mô tả: Kế thừa từ Projectile nhưng có logic hoàn toàn khác biệt.
-- Đặc điểm: Không bay đi mà bám theo nguồn phát, có trạng thái nhắm và bắn.
-- =============================================================================

local class = require 'libs.middleclass.middleclass' -- Đảm bảo bạn đã cài đặt thư viện middleclass
local Projectile = require 'src.entities.base.Projectile'

-- Khởi tạo class LaserBeam kế thừa từ lớp cha Projectile
local LaserBeam = class('LaserBeam', Projectile)

--- Hàm khởi tạo Laser
-- @param source (Entity): Đối tượng phát ra laser (ví dụ: Boss).
-- @param offsetX, offsetY: Khoảng cách lệch so với tâm của Boss.
-- @param angle: Hướng bắn ban đầu.
-- @param properties: Bảng tùy chỉnh (chiều dài, độ dày, thời gian chờ...).
function LaserBeam:initialize(source, offsetX, offsetY, angle, properties)
    -- [BƯỚC 1] Khởi tạo lớp cha Projectile. 
    -- Vì Laser không tự bay bằng vận tốc vật lý, ta truyền speed = 0.
    Projectile.initialize(self, 0, 0, angle, 0)
    
    self.source = source -- Lưu lại đối tượng chủ (Nguồn phát)
    self.offsetX = offsetX or 0 -- Độ lệch X so với Boss
    self.offsetY = offsetY or 0 -- Độ lệch Y so với Boss
    
    properties = properties or {}
    
    -- [BƯỚC 2] Cấu trúc hình học của Laser
    self.length = properties.length or 1500 -- Chiều dài (thường để rất dài để tràn màn hình)
    self.width = properties.width or 20     -- Độ dày của tia Laser (cũng là vùng gây sát thương)
    self.color = properties.color or {1, 0, 0} -- Màu sắc đặc trưng của Laser
    
    -- [BƯỚC 3] Quản lý Trạng thái và Thời gian (State Machine)
    -- telegraphDuration: Thời gian hiện tia nhắm mờ (Cảnh báo người chơi)
    self.telegraphDuration = properties.telegraph or 1.0 
    -- activeDuration: Thời gian Laser duy trì trạng thái bắn thật sự
    self.activeDuration = properties.duration or 2.0     
    
    -- Trạng thái ban đầu: "telegraphing" (nhắm) hoặc "firing" (bắn ngay)
    self.state = self.telegraphDuration > 0 and "telegraphing" or "firing"
    
    -- [BƯỚC 4] Cơ chế quét (Sweep) - Giúp Laser xoay tròn
    self.sweepSpeed = properties.sweepSpeed or 0 -- Tốc độ xoay (Radian/giây)
end

--- Hàm cập nhật logic Laser mỗi khung hình
function LaserBeam:update(dt)
    -- 1. CẬP NHẬT VỊ TRÍ THEO NGUỒN PHÁT (BOSS)
    -- Laser luôn "dính" vào Boss trừ khi Boss bị tiêu diệt
    if self.source and not self.source.isDead then
        self.x = self.source.x + self.offsetX
        self.y = self.source.y + self.offsetY
    end
    
    -- 2. XỬ LÝ QUÉT GÓC (SWEEP)
    -- Nếu có sweepSpeed, Laser sẽ xoay như một cái quạt khi đang bắn
    if self.sweepSpeed ~= 0 and self.state == "firing" then
        self.angle = self.angle + self.sweepSpeed * dt
    end

    -- 3. MÁY TRẠNG THÁI (STATE MACHINE)
    if self.state == "telegraphing" then
        -- Đếm ngược thời gian nhắm
        self.telegraphDuration = self.telegraphDuration - dt
        if self.telegraphDuration <= 0 then
            self.state = "firing" -- Chuyển sang trạng thái bắn thật
            -- Mẹo: Bạn có thể thêm lệnh phát âm thanh "BÙM" tại đây
        end
    elseif self.state == "firing" then
        -- Đếm ngược thời gian bắn
        self.activeDuration = self.activeDuration - dt
        if self.activeDuration <= 0 then
            self.isDead = true -- Laser biến mất khi hết thời gian
        end
    end
    
    -- GHI CHÚ: Ta không gọi Projectile.update(self, dt) vì 
    -- Laser không di chuyển bằng công thức x = x + vx*dt thông thường.
end

--- Hàm vẽ Laser với hiệu ứng đồ họa 2 lớp
function LaserBeam:draw()
    love.graphics.push() -- Lưu trạng thái hệ trục tọa độ
    
    -- Dời tâm vẽ về gốc phát laser và xoay theo góc bắn hiện tại
    -- Mọi hình chữ nhật vẽ sau đó sẽ tự động xoay theo góc này
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle)
    
    if self.state == "telegraphing" then
        -- VẼ TIA NHẮM CẢNH BÁO
        -- Tạo hiệu ứng nhấp nháy cực nhanh để cảnh báo nguy hiểm
        local blink = (math.sin(love.timer.getTime() * 30) + 1) / 2
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.3 + blink * 0.2)
        
        -- Vẽ một đường kẻ mảnh (chỉ dày 2 pixel) vươn dài ra
        love.graphics.rectangle("fill", 0, -1, self.length, 2)
        
    elseif self.state == "firing" then
        -- VẼ LASER THỰC SỰ
        -- Lớp 1: Vẽ phần viền hào quang (Aura) bên ngoài, màu sắc mờ ảo
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.5)
        love.graphics.rectangle("fill", 0, -self.width/2, self.length, self.width)
        
        -- Lớp 2: Vẽ phần lõi Laser (Core) rực sáng ở chính giữa
        love.graphics.setColor(1, 1, 1, 1) -- Màu trắng tinh khôi cho lõi
        love.graphics.rectangle("fill", 0, -self.width/4, self.length, self.width/2)
    end
    
    love.graphics.pop() -- Trả lại hệ trục tọa độ ban đầu
    love.graphics.setColor(1, 1, 1, 1) -- Reset màu cọ vẽ
end

--- Tiện ích: Kiểm tra xem Laser có đang ở trạng thái gây sát thương không
-- Các lớp quản lý va chạm sẽ gọi hàm này để biết khi nào thì nên "trừ máu" người chơi
-- @return (boolean)
function LaserBeam:isLethal()
    return self.state == "firing"
end

return LaserBeam
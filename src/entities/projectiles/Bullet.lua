-- =============================================================================
-- BULLET CLASS (LỚP VIÊN ĐẠN)
-- =============================================================================
-- Mô tả: Thừa kế từ Projectile. Dùng để tạo ra các loại đạn cụ thể trong game.
-- Tính năng nổi bật: Hỗ trợ thời gian trễ (delay), tăng tốc (acceleration),
-- và hiệu ứng nhấp nháy cảnh báo (telegraph).
-- =============================================================================

local class = require 'libs.middleclass'

-- Import (nạp) lớp cha Projectile vào để sử dụng
local Projectile = require 'src.entities.base.Projectile'

-- Khởi tạo class Bullet KẾ THỪA từ Projectile
-- Giúp Bullet tự động có sẵn các biến x, y, angle, speed và hàm checkOutOfBounds.
local Bullet = class('Bullet', Projectile)

--- Hàm khởi tạo của viên đạn
-- @param x, y, angle, speed: Các thông số cơ bản truyền cho lớp cha.
-- @param properties: Một bảng (table) chứa các tùy chỉnh đặc biệt cho viên đạn.
function Bullet:initialize(x, y, angle, speed, properties)
    -- [BƯỚC 1] Gọi constructor của lớp cha (Projectile) để thiết lập vị trí và vận tốc cơ bản
    Projectile.initialize(self, x, y, angle, speed)
    
    -- Nếu người dùng không truyền bảng properties vào, ta tự tạo một bảng rỗng {}
    properties = properties or {}
    
    -- [BƯỚC 2] Khởi tạo các thuộc tính chiến đấu
    self.damage = properties.damage or 10 -- Sát thương gây ra cho người chơi
    
    -- [BƯỚC 3] Khởi tạo thuộc tính hiển thị (Visuals)
    self.radius = properties.radius or 5           -- Kích thước viên đạn
    self.color = properties.color or {1, 1, 1}     -- Màu sắc mặc định là màu trắng
    self.shape = properties.shape or "circle"      -- Hình dáng: "circle" (tròn) hoặc "needle" (kim)
    
    -- [BƯỚC 4] Logic Danmaku tiêu chuẩn (Cơ chế di chuyển đặc biệt)
    self.delayTimer = properties.delay or 0        -- Thời gian chờ (đứng im nhấp nháy) trước khi bắn đi
    self.acceleration = properties.acceleration or 0 -- Gia tốc (đạn bay nhanh dần hoặc chậm dần)
    self.maxSpeed = properties.maxSpeed or 1000    -- Giới hạn tốc độ tối đa (để đạn không bay quá nhanh)
end

--- Hàm cập nhật logic viên đạn mỗi khung hình
function Bullet:update(dt)
    -- [BƯỚC 1] Xử lý thời gian chờ (Delay)
    -- Nếu đạn đang trong trạng thái chờ, nó chỉ lơ lửng tại chỗ và nhấp nháy
    if self.delayTimer > 0 then
        self.delayTimer = self.delayTimer - dt
        -- Vẫn phải tăng đồng hồ thời gian sống của viên đạn
        self.timer = self.timer + dt 
        return -- Kết thúc hàm sớm ở đây để đạn KHÔNG chạy đoạn code di chuyển phía dưới
    end
    
    -- [BƯỚC 2] Cập nhật vận tốc nếu đạn có gia tốc
    if self.acceleration ~= 0 then
        self.speed = self.speed + self.acceleration * dt
        
        -- Chặn trên: Đảm bảo tốc độ không vượt quá giới hạn tối đa cho phép
        if self.speed > self.maxSpeed then
            self.speed = self.maxSpeed
        end
    end
    
    -- [BƯỚC 3] Gọi hàm update của lớp cha (Projectile)
    -- Thừa kế lại toàn bộ phép tính lượng giác (Cos, Sin) để di chuyển và tự hủy khi ra ngoài màn hình
    Projectile.update(self, dt)
end

--- Hàm vẽ viên đạn lên màn hình
function Bullet:draw()
    -- [BƯỚC 1] Xử lý màu sắc và hiệu ứng chớp sáng cảnh báo (Telegraph)
    if self.delayTimer > 0 then
        -- Công thức toán học dùng hàm Sin để tạo giá trị uốn lượn từ 0 đến 1
        -- Giúp viên đạn chớp nháy mờ-rõ liên tục cực kỳ mượt mà
        local alpha = (math.sin(love.timer.getTime() * 20) + 1) / 2
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], alpha)
    else
        -- Khi hết thời gian delay, đạn hiện rõ 100% màu sắc
        love.graphics.setColor(self.color)
    end
    
    -- [BƯỚC 2] Vẽ hình dáng viên đạn
    if self.shape == "needle" then
        -- Vẽ tia nhọn (Needle Dart)
        love.graphics.push() -- Lưu gốc tọa độ
        love.graphics.translate(self.x, self.y) -- Dời tâm vẽ về vị trí viên đạn
        love.graphics.rotate(self.angle) -- Xoay mũi nhọn theo đúng hướng bay
        
        -- Vẽ một hình đa giác nhọn (hình thoi dẹt)
        love.graphics.polygon("fill", -self.radius*2, 0, 0, -self.radius/2, self.radius*2, 0, 0, self.radius/2)
        love.graphics.pop() -- Trả lại gốc tọa độ
    else
        -- Mặc định là viên đạn tròn (Petal Orb)
        love.graphics.circle("fill", self.x, self.y, self.radius)
    end
    
    -- [BƯỚC 3] Reset màu về mặc định (Trắng hoàn toàn) để không làm lem màu các vật thể vẽ sau nó
    love.graphics.setColor(1, 1, 1, 1)
end

-- Trả về bảng class để các file khác có thể require()
return Bullet
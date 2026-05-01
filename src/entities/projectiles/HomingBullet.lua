-- =============================================================================
-- HOMING BULLET CLASS (LỚP ĐẠN ĐUỔI MỤC TIÊU)
-- =============================================================================
-- Mô tả  : Kế thừa từ Bullet. Có khả năng tự động bẻ lái hướng về phía mục tiêu.
-- Cơ chế : Sử dụng toán học lượng giác để tính góc quay ngắn nhất mỗi frame.
-- Ứng dụng: Đạn ma mị, tên lửa tầm nhiệt, bóng lửa đuổi người chơi.
--
-- SƠ ĐỒ HOẠT ĐỘNG TỔNG QUÁT:
--
--   Mỗi frame (update):
--   ┌─────────────────────────────────────────────────────────────┐
--   │  1. Tính góc LÝ TƯỞNG từ đạn → mục tiêu (math.atan2)      │
--   │  2. Tính HIỆU SỐ GÓC so với góc đang bay                   │
--   │  3. CHUẨN HÓA hiệu số về [-π, π] (chọn đường ngắn nhất)   │
--   │  4. BẺ LÁI: xoay một chút về hướng đó (không xoay ngoắt)  │
--   │  5. Gọi Bullet:update() để di chuyển theo góc mới          │
--   └─────────────────────────────────────────────────────────────┘
--
-- =============================================================================

-- Nạp thư viện middleclass – thư viện giúp Lua có hỗ trợ OOP (Class, Kế thừa)
-- Lua không có sẵn class như Java/Python, middleclass bổ sung tính năng này
local class = require 'libs.middleclass.middleclass'

-- Nạp lớp cha Bullet để kế thừa
-- HomingBullet KHÔNG viết lại từ đầu – nó tái sử dụng toàn bộ logic của Bullet:
--   màu sắc, kích thước, damage, va chạm, v.v.
--   và chỉ GHI ĐÈ (override) phần hành vi di chuyển.
local Bullet = require 'src.entities.projectiles.Bullet'

-- Khai báo class HomingBullet, kế thừa từ Bullet
-- Cú pháp: class('TênClass', LớpCha)
-- → HomingBullet có tất cả method/property của Bullet,
--   trừ những method mà nó tự định nghĩa lại bên dưới.
local HomingBullet = class('HomingBullet', Bullet)


-- =============================================================================
-- HÀM KHỞI TẠO: HomingBullet:initialize()
-- =============================================================================
-- Được gọi khi tạo viên đạn mới: HomingBullet(x, y, angle, speed, properties)
--
-- THAM SỐ:
--   x, y       : Tọa độ xuất phát (thường là vị trí Boss)
--   angle      : Góc bay ban đầu (radian) – có thể không nhắm trúng player ngay
--                vì HomingBullet sẽ tự điều chỉnh sau
--   speed      : Tốc độ bay (pixels/giây)
--   properties : Bảng Lua chứa cấu hình, bao gồm:
--     .target         → Object mục tiêu (thường là Player), phải có .x, .y, .isDead
--     .homingPower    → Độ nhạy bẻ lái (radian/giây). Giá trị gợi ý:
--                         1.0 = bẻ lái chậm, dễ né
--                         3.0 = bẻ lái trung bình (mặc định)
--                         8.0 = bẻ lái gắt, gần như không thể tránh
--     .homingDuration → Số giây đạn còn đuổi mục tiêu (sau đó bay thẳng)
--                       Giúp tạo "cửa sổ né tránh" cho người chơi
-- =============================================================================
function HomingBullet:initialize(x, y, angle, speed, properties)

    -- [BƯỚC 1] GỌI CONSTRUCTOR CỦA LỚP CHA (Bullet)
    -- ─────────────────────────────────────────────
    -- Trong OOP, khi override hàm initialize, ta phải GỌI LẠI initialize của cha
    -- để đảm bảo tất cả thuộc tính cơ bản (color, damage, radius...) được set đúng.
    --
    -- Nếu KHÔNG gọi dòng này → self.color, self.damage, v.v. sẽ là nil → game crash!
    --
    -- Lua dùng cú pháp: LớpCha.method(self, ...) thay vì super.method(...)
    Bullet.initialize(self, x, y, angle, speed, properties)

    -- Đảm bảo properties không bị nil (phòng trường hợp gọi thiếu tham số)
    properties = properties or {}

    -- [BƯỚC 2] THIẾT LẬP CÁC THUỘC TÍNH RIÊNG CỦA HOMING BULLET
    -- ─────────────────────────────────────────────────────────────

    -- Lưu reference đến object mục tiêu
    -- QUAN TRỌNG: Đây là reference (tham chiếu), không phải copy!
    -- → Mỗi frame, self.target.x và self.target.y phản ánh vị trí MỚI NHẤT của player
    -- → Nếu player di chuyển, đạn tự biết vị trí mới và điều chỉnh theo
    self.target = properties.target

    -- Tốc độ bẻ lái đo bằng RADIAN/GIÂY
    -- Ý nghĩa: Trong 1 giây, đạn có thể xoay tối đa bao nhiêu radian?
    -- Ví dụ homingPower = 3.0:
    --   Trong 1 giây → xoay được tối đa 3 radian ≈ 172°
    --   Trong 1 frame (dt ≈ 0.016s) → xoay được 3 × 0.016 ≈ 0.048 radian ≈ 2.75°
    --   → Tạo cảm giác đạn "lượn" từ từ thay vì snap ngay lập tức
    self.homingPower = properties.homingPower or 3.0

    -- Thời gian (giây) đạn còn khả năng đuổi mục tiêu
    -- Sau thời gian này, đạn bay thẳng như Bullet thường → Người chơi có cơ hội né!
    -- Ví dụ: homingDuration = 2.0
    --   0 → 2 giây : Đạn đuổi theo player
    --   2 giây → hết màn hình: Đạn bay thẳng theo góc hiện tại
    self.homingDuration = properties.homingDuration or 2.0

    -- GHI CHÚ: self.timer được Bullet:initialize() khởi tạo sẵn = 0
    -- Mỗi frame, Bullet:update(dt) tự cộng dt vào self.timer
    -- → Ta dùng self.timer để đo thời gian đạn đã sống
end


-- =============================================================================
-- HÀM CẬP NHẬT: HomingBullet:update(dt)
-- =============================================================================
-- Được LÖVE gọi mỗi frame (khoảng 60 lần/giây ở 60 FPS)
--
-- THAM SỐ:
--   dt : Delta Time – Thời gian (giây) từ frame trước đến frame này
--        Ví dụ ở 60 FPS: dt ≈ 0.0167 giây
--        Ví dụ ở 30 FPS: dt ≈ 0.0333 giây
--        Mọi phép tính liên quan đến thời gian đều nhân với dt
--        để đảm bảo game chạy NHẤT QUÁN dù FPS thay đổi
--
-- LUỒNG XỬ LÝ:
--   [Kiểm tra điều kiện] → [Tính góc lý tưởng] → [Tính hiệu số góc]
--   → [Chuẩn hóa góc] → [Bẻ lái] → [Gọi Bullet:update()]
-- =============================================================================
function HomingBullet:update(dt)

    -- =========================================================================
    -- [BƯỚC 1] KIỂM TRA ĐIỀU KIỆN BẺ LÁI
    -- =========================================================================
    -- Chỉ thực hiện logic homing khi TẤT CẢ các điều kiện sau đều đúng:
    --
    -- Điều kiện A: self.timer < self.homingDuration
    --   → Đạn vẫn trong "giai đoạn đuổi" (chưa hết thời gian homing)
    --   → self.timer được Bullet:update() tự tăng mỗi frame
    --
    -- Điều kiện B: self.target
    --   → Mục tiêu phải tồn tại (không bị nil)
    --   → Nếu Player chưa được gán hoặc đã bị xóa khỏi memory → bỏ qua
    --
    -- Điều kiện C: not self.target.isDead
    --   → Mục tiêu vẫn còn sống
    --   → Tránh trường hợp đạn đuổi theo xác chết
    if self.timer < self.homingDuration and self.target and not self.target.isDead then

        -- =====================================================================
        -- BƯỚC A: TÍNH GÓC LÝ TƯỞNG (Góc từ đạn đến mục tiêu)
        -- =====================================================================
        -- math.atan2(dy, dx) là hàm lượng giác đặc biệt:
        --
        -- Bài toán: Cho 2 điểm A(x1,y1) và B(x2,y2).
        --           Tính góc của vector AB so với trục X dương.
        --
        -- Công thức:
        --   dy = B.y - A.y  (hiệu tọa độ Y: dương = B ở dưới A, trong game)
        --   dx = B.x - A.x  (hiệu tọa độ X: dương = B ở bên phải A)
        --   angle = math.atan2(dy, dx)
        --
        -- Kết quả: Góc radian trong khoảng [-π, π]
        --   +π/2 (90°)  → mục tiêu ở bên DƯỚI (vì Y tăng xuống trong game)
        --   -π/2 (-90°) → mục tiêu ở bên TRÊN
        --   0           → mục tiêu ở bên PHẢI
        --   ±π          → mục tiêu ở bên TRÁI
        --
        -- Lưu ý: Dùng math.atan2 thay vì math.atan vì atan2 phân biệt được
        --        4 góc phần tư (quadrant) dựa vào dấu của dx và dy riêng lẻ
        local targetAngle = math.atan2(self.target.y - self.y, self.target.x - self.x)

        -- =====================================================================
        -- BƯỚC B: TÍNH HIỆU SỐ GÓC (Angle Difference)
        -- =====================================================================
        -- angleDiff = Góc cần xoay thêm để đạn bay về phía mục tiêu
        --
        -- Ví dụ minh họa:
        --   self.angle  = 0.5 radian  (đang bay hơi lên trên phải)
        --   targetAngle = 1.8 radian  (mục tiêu ở phía dưới phải)
        --   angleDiff   = 1.8 - 0.5 = 1.3 radian (cần xoay thêm 1.3 rad)
        --
        -- Giá trị angleDiff có thể dương hoặc âm:
        --   angleDiff > 0 → cần xoay THEO CHIỀU KIM ĐỒNG HỒ (trong hệ tọa độ game)
        --   angleDiff < 0 → cần xoay NGƯỢC CHIỀU KIM ĐỒNG HỒ
        local angleDiff = targetAngle - self.angle

        -- =====================================================================
        -- BƯỚC C: CHUẨN HÓA GÓC – ÉP VỀ KHOẢNG [-π, π]
        -- =====================================================================
        -- VẤN ĐỀ: Góc trong radian có thể "vượt vòng"
        --
        -- Ví dụ vấn đề:
        --   self.angle  = 0.1 radian  (gần hướng phải, hơi lên trên)
        --   targetAngle = 6.1 radian  (gần hướng phải, hơi xuống dưới)
        --   angleDiff   = 6.1 - 0.1 = 6.0 radian
        --
        --   6.0 radian ≈ 344° → Đạn sẽ xoay gần 1 vòng đầy (sai!)
        --   Thực ra chỉ cần xoay 6.0 - 2π ≈ -0.28 radian (≈ -16°) là đến nơi!
        --
        -- GIẢI PHÁP AN TOÀN: Dùng if thay vì while để tránh treo game nếu góc là Infinity
        if angleDiff ~= angleDiff or math.abs(angleDiff) == math.huge then
            angleDiff = 0 -- Reset nếu bị NaN hoặc Infinity
        end

        if angleDiff >  math.pi then angleDiff = angleDiff - 2 * math.pi end
        if angleDiff < -math.pi then angleDiff = angleDiff + 2 * math.pi end

        -- =====================================================================
        -- BƯỚC D: THỰC HIỆN BẺ LÁI (Steering / Interpolation)
        -- =====================================================================
        -- Thay vì snap ngay lập tức về targetAngle, ta xoay MỘT PHẦN nhỏ mỗi frame.
        --
        -- CÔNG THỨC:
        --   self.angle = self.angle + angleDiff × homingPower × dt
        --
        -- Phân tích từng nhân tố:
        --   angleDiff    → Phương và độ lớn cần xoay (dương/âm)
        --   homingPower  → "Hệ số nhạy" – nhân số lớn → xoay nhiều hơn mỗi frame
        --   dt           → Thời gian frame – nhân dt để đảm bảo tốc độ không phụ thuộc FPS
        --
        -- Ví dụ tính toán (homingPower=3.0, dt=0.016, angleDiff=1.0 rad):
        --   Lượng xoay 1 frame = 1.0 × 3.0 × 0.016 ≈ 0.048 radian ≈ 2.75°
        --   Đạn xoay từ từ 2.75° mỗi frame → Tạo cảm giác mượt mà, tự nhiên
        --
        -- SO SÁNH với snap ngay (self.angle = targetAngle):
        --   Snap → Đạn tức thì chỉ thẳng vào player → Trông không thực tế
        --   Lerp → Đạn lượn dần về phía player → Đẹp và có thể né được!
        --
        -- NOTE: Đây là dạng đơn giản hóa của Proportional Control (điều khiển tỉ lệ P)
        --       từ lý thuyết điều khiển tự động (control theory)
        self.angle = self.angle + angleDiff * self.homingPower * dt
    end

    -- =========================================================================
    -- [BƯỚC 2] GỌI UPDATE CỦA LỚP CHA
    -- =========================================================================
    -- Sau khi đã tính xong góc mới (self.angle), ta để Bullet:update() làm tiếp:
    --   1. Di chuyển đạn theo góc mới: x += cos(angle) × speed × dt
    --                                  y += sin(angle) × speed × dt
    --   2. Tăng self.timer lên dt (dùng để đo thời gian sống của đạn)
    --   3. Kiểm tra đạn có ra ngoài màn hình không
    --   4. Bất kỳ logic chung nào khác của Bullet
    --
    -- Bằng cách GỌI LẠI thay vì viết lại, ta đảm bảo:
    --   - Không duplicate code
    --   - Nếu Bullet:update() được cải thiện sau này, HomingBullet tự hưởng lợi
    Bullet.update(self, dt)
end


-- =============================================================================
-- HÀM VẼ: HomingBullet:draw()
-- =============================================================================
-- Ghi đè (override) hàm draw của Bullet để tạo ngoại hình "Ma Trôi" (Wisp):
--   Lớp 1 (ngoài): Vầng hào quang mờ, bán kính lớn → tạo cảm giác phát sáng
--   Lớp 2 (trong): Lõi sáng đặc, bán kính chuẩn    → là "thân" thật của đạn
--
-- MÀU SẮC VÀ ALPHA (Độ trong suốt) trong LÖVE2D:
--   love.graphics.setColor(R, G, B, A)
--   R, G, B : Giá trị màu từ 0.0 đến 1.0
--             (0,0,0) = Đen hoàn toàn | (1,1,1) = Trắng hoàn toàn
--   A       : Alpha – Độ đục (opacity)
--             0.0 = Hoàn toàn trong suốt | 1.0 = Hoàn toàn đục
--
-- Ví dụ self.color = {0, 0.5, 1} (màu xanh dương nhạt):
--   Hào quang: (0, 0.5, 1, 0.3) → Xanh dương nhạt, rất mờ
--   Lõi      : (0, 0.5, 1, 1.0) → Xanh dương nhạt, đục hoàn toàn
-- =============================================================================
function HomingBullet:draw()

    -- -------------------------------------------------------------------------
    -- LỚP 1: VẼ VẦNG HÀO QUANG (Aura / Glow Effect)
    -- -------------------------------------------------------------------------
    -- Đặt màu giống self.color nhưng Alpha = 0.3 (70% trong suốt)
    -- self.color[1] = R, self.color[2] = G, self.color[3] = B
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.3)

    -- Vẽ hình tròn đặc (fill) với bán kính gấp 1.8 lần so với đạn thật
    -- self.radius   = Bán kính thật của đạn (dùng cho va chạm)
    -- self.radius × 1.8 = Bán kính của hào quang (chỉ là hiệu ứng hình ảnh)
    --
    -- "fill" → vẽ hình tròn đặc (ngược lại là "line" → chỉ vẽ viền)
    love.graphics.circle("fill", self.x, self.y, self.radius * 1.8)

    -- -------------------------------------------------------------------------
    -- LỚP 2: VẼ LÕI SÁNG (Core)
    -- -------------------------------------------------------------------------
    -- Đặt lại màu với Alpha = 1.0 (hoàn toàn đục, không trong suốt)
    love.graphics.setColor(self.color[1], self.color[2], self.color[3], 1)

    -- Vẽ hình tròn đúng kích thước (self.radius) tại tâm đạn (self.x, self.y)
    -- Đây là phần "thân thật" của đạn, trùng với hitbox va chạm
    love.graphics.circle("fill", self.x, self.y, self.radius)

    -- -------------------------------------------------------------------------
    -- RESET MÀU VỀ TRẮNG (QUAN TRỌNG!)
    -- -------------------------------------------------------------------------
    -- setColor() trong LÖVE là GLOBAL STATE – nó ảnh hưởng đến MỌI THỨ vẽ sau đó
    -- Nếu không reset, các vật thể vẽ sau (player, UI, v.v.) sẽ bị nhuốm màu đạn!
    --
    -- (1, 1, 1, 1) = Trắng hoàn toàn + Không trong suốt = Màu "bình thường"
    -- → LÖVE dùng màu này như bộ lọc nhân (multiply) lên texture,
    --   nên (1,1,1,1) có nghĩa là "không thay đổi màu gốc"
    love.graphics.setColor(1, 1, 1, 1)
end


-- Export module để các file khác có thể require và dùng
-- Ví dụ: local HomingBullet = require 'src.entities.projectiles.HomingBullet'
--        local hb = HomingBullet(x, y, angle, speed, { target = player, homingPower = 4 })
return HomingBullet
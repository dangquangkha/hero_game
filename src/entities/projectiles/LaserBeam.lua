-- =============================================================================
-- LASER BEAM CLASS (LỚP TIA LASER TỬ THẦN)
-- =============================================================================
-- Mô tả  : Kế thừa từ Projectile nhưng có logic hoàn toàn khác biệt.
-- Đặc điểm: KHÔNG bay đi như đạn thường – thay vào đó nó BÁM THEO nguồn phát,
--           và hoạt động theo 2 giai đoạn: NHẮM (cảnh báo) → BẮN (gây sát thương)
-- Ứng dụng: Boss Laser Lotus (Phase 2), đòn tấn công diện rộng.
--
-- SO SÁNH LASER vs BULLET:
-- ┌─────────────────┬──────────────────────────┬───────────────────────────┐
-- │ Tiêu chí        │ Bullet                   │ LaserBeam                 │
-- ├─────────────────┼──────────────────────────┼───────────────────────────┤
-- │ Di chuyển       │ Bay từ A → B             │ Đứng yên, gắn với Boss    │
-- │ Tốc độ (speed)  │ Có (vd: 300 px/s)        │ = 0 (không dùng)         │
-- │ Gây sát thương  │ Khi va chạm (1 lần)      │ Liên tục khi "firing"     │
-- │ Vòng đời        │ Bay ra ngoài → isDead    │ Đếm ngược timer → isDead  │
-- │ Hình dạng       │ Hình tròn                │ Hình chữ nhật dài         │
-- └─────────────────┴──────────────────────────┴───────────────────────────┘
--
-- MÁY TRẠNG THÁI (STATE MACHINE) của LaserBeam:
--
--   [Tạo ra]
--       │
--       ▼
--   ┌───────────────┐   telegraphDuration hết   ┌─────────────┐   activeDuration hết
--   │ "telegraphing"│ ─────────────────────────→ │  "firing"   │ ──────────────────→ isDead = true
--   │  (Cảnh báo)   │                            │  (Bắn thật)│
--   │ Tia mờ nháy   │                            │ Laser sáng  │
--   └───────────────┘                            └─────────────┘
--
-- =============================================================================

local class      = require 'libs.middleclass.middleclass'
local Projectile = require 'src.entities.base.Projectile'

-- Khai báo class LaserBeam kế thừa từ Projectile
-- (Projectile là lớp gốc chung, cấp thấp hơn Bullet)
local LaserBeam = class('LaserBeam', Projectile)


-- =============================================================================
-- HÀM KHỞI TẠO: LaserBeam:initialize()
-- =============================================================================
-- THAM SỐ:
--   source          : Object Boss – Laser sẽ bám theo vị trí của Boss mỗi frame
--                     Phải có thuộc tính .x, .y, .isDead
--   offsetX, offsetY: Vị trí lệch tia laser so với TÂM Boss (pixels)
--                     Ví dụ: offsetX = -30, offsetY = 0
--                     → Laser phát ra từ cạnh TRÁI Boss (trái tâm 30px)
--                     Ví dụ: offsetX = 0, offsetY = -20
--                     → Laser phát ra từ trên đầu Boss
--   angle           : Hướng laser ban đầu (radian)
--   properties      : Bảng cấu hình (xem chi tiết bên dưới)
-- =============================================================================
function LaserBeam:initialize(source, offsetX, offsetY, angle, properties)

    -- =========================================================================
    -- [BƯỚC 1] GỌI CONSTRUCTOR CỦA LỚP CHA (Projectile)
    -- =========================================================================
    -- Laser KHÔNG di chuyển bằng vật lý thông thường (không có vận tốc)
    -- nên ta truyền:
    --   x = 0, y = 0  → Tọa độ tạm thời, sẽ được cập nhật mỗi frame theo Boss
    --   speed = 0     → Không có vận tốc tự bay
    --
    -- Lý do vẫn gọi Projectile.initialize: Để kế thừa các thuộc tính cơ bản như
    -- self.isDead, self.angle, self.timer mà Projectile đã thiết lập sẵn
    Projectile.initialize(self, 0, 0, angle, 0)

    -- =========================================================================
    -- [BƯỚC 2] LƯU THÔNG TIN NGUỒN PHÁT VÀ VỊ TRÍ LỆCH
    -- =========================================================================

    -- Lưu REFERENCE (tham chiếu) đến Boss, không phải copy tọa độ
    -- → Mỗi frame update, self.source.x/y phản ánh vị trí TỨC THỜI của Boss
    -- → Laser tự động "đi theo" Boss khi Boss di chuyển
    self.source = source

    -- Độ lệch so với tâm Boss
    -- Dùng `or 0` để đặt giá trị mặc định nếu tham số bị bỏ qua (nil)
    self.offsetX = offsetX or 0
    self.offsetY = offsetY or 0

    -- Phòng trường hợp properties không được truyền vào
    properties = properties or {}

    -- =========================================================================
    -- [BƯỚC 3] CẤU TRÚC HÌNH HỌC CỦA LASER
    -- =========================================================================
    --
    -- Laser được biểu diễn là một HÌNH CHỮ NHẬT:
    --
    --   (self.x, self.y) ← Điểm gốc (nguồn phát)
    --        │
    --        ├───────────────────────────────────────────────→ self.angle
    --        │  ← self.width (độ dày) →
    --        │◄──────── self.length (chiều dài) ────────────►│
    --
    -- self.length: Để rất dài (1500px) để tia "tràn" khỏi màn hình
    --             → Người chơi không thể thấy điểm cuối → Tạo cảm giác vô tận
    self.length = properties.length or 1500

    -- self.width: Vừa là độ dày HÌNH ẢNH vừa là độ rộng VÙNG SÁT THƯƠNG (hitbox)
    --            → Laser dày hơn = Khó né hơn
    self.width  = properties.width  or 20
    
    -- Sát thương gây ra mỗi frame (hoặc mỗi nhịp tùy DamageSystem)
    self.damage = properties.damage or 1

    -- Màu sắc laser (RGB), mặc định đỏ tươi {1, 0, 0}
    -- Không có Alpha ở đây – Alpha được kiểm soát từng lớp trong hàm draw()
    self.color  = properties.color  or {1, 0, 0}

    -- =========================================================================
    -- [BƯỚC 4] THIẾT LẬP MÁY TRẠNG THÁI (STATE MACHINE) VÀ THỜI GIAN
    -- =========================================================================

    -- telegraphDuration: Thời gian (giây) giai đoạn CẢNH BÁO trước khi bắn
    --   Trong thời gian này: Tia mờ nhấp nháy, CHƯA gây sát thương
    --   Mục đích thiết kế game: Cho người chơi cơ hội NÉ trước khi bị giết
    --   Giá trị gợi ý: 0.5s (gắt), 1.0s (cân bằng), 2.0s (tử tế)
    self.telegraphDuration = properties.telegraph or 1.0

    -- activeDuration: Thời gian (giây) giai đoạn BẮN THẬT
    --   Trong thời gian này: Laser sáng rực, gây sát thương liên tục mỗi frame
    self.activeDuration    = properties.duration  or 2.0

    -- Xác định trạng thái ban đầu dựa vào telegraphDuration:
    --   Nếu có thời gian cảnh báo (> 0) → Bắt đầu ở "telegraphing"
    --   Nếu telegraphDuration = 0 → Bắn ngay lập tức "firing"
    --
    -- Cú pháp Lua: (điều_kiện) and (giá_trị_nếu_đúng) or (giá_trị_nếu_sai)
    -- Tương đương với toán tử ternary trong C/Java: condition ? a : b
    self.state = self.telegraphDuration > 0 and "telegraphing" or "firing"

    -- =========================================================================
    -- [BƯỚC 5] CƠ CHẾ QUÉT GÓC (LASER SWEEP)
    -- =========================================================================
    -- Laser có thể vừa bắn vừa TỰ XOAY như một cái quạt hoặc radar
    --
    -- sweepSpeed: Tốc độ xoay đo bằng RADIAN/GIÂY
    --   0      → Laser đứng yên, không xoay (mặc định)
    --   > 0    → Xoay theo chiều kim đồng hồ (trong hệ tọa độ game)
    --   < 0    → Xoay ngược chiều kim đồng hồ
    --
    -- Ví dụ: sweepSpeed = math.pi (= π ≈ 3.14 rad/s)
    --   → Laser xoay nửa vòng (180°) trong 1 giây
    --   → Xoay 1 vòng đầy (360°) trong 2 giây
    self.sweepSpeed = properties.sweepSpeed or 0
end


-- =============================================================================
-- HÀM CẬP NHẬT: LaserBeam:update(dt)
-- =============================================================================
-- Được LÖVE gọi mỗi frame. Xử lý 3 việc theo thứ tự:
--   1. Cập nhật vị trí laser theo Boss
--   2. Xoay laser nếu đang bắn và có sweepSpeed
--   3. Chạy máy trạng thái (đếm ngược timer, chuyển state)
-- =============================================================================
function LaserBeam:update(dt)

    -- =========================================================================
    -- [1] BÁM THEO NGUỒN PHÁT (SOURCE TRACKING)
    -- =========================================================================
    -- Laser không tự di chuyển – nó COPY tọa độ của Boss mỗi frame
    -- (cộng thêm offset để lệch khỏi tâm Boss)
    --
    -- Điều kiện kiểm tra trước khi đọc source.x/y:
    --   self.source           → Boss object phải tồn tại (không nil)
    --   not self.source.isDead → Boss chưa chết
    --   Nếu Boss chết → Laser giữ nguyên vị trí cuối cùng (không crash)
    if self.source and not self.source.isDead then
        -- Tọa độ laser = Tọa độ Boss + Offset lệch
        -- Ví dụ: Boss ở (400, 300), offsetX=-30, offsetY=0
        --   → Laser phát từ (370, 300) – phía trái Boss
        self.x = self.source.x + self.offsetX
        self.y = self.source.y + self.offsetY
    end

    -- =========================================================================
    -- [2] XỬ LÝ QUÉT GÓC (SWEEP ROTATION)
    -- =========================================================================
    -- Laser chỉ xoay khi:
    --   A. sweepSpeed ~= 0 → Có tốc độ quét khác 0 (~= là "khác bằng" trong Lua)
    --   B. state == "firing" → Chỉ xoay khi đang bắn thật (không xoay khi cảnh báo)
    --
    -- CÔNG THỨC TÍCH PHÂN GÓC:
    --   angle_mới = angle_cũ + (tốc_độ_góc × thời_gian)
    --   Đây là tích phân đơn giản nhất: θ(t) = θ₀ + ω × t
    --   Trong đó: ω (omega) = sweepSpeed (radian/giây), t = dt (giây/frame)
    --
    -- Nhân dt đảm bảo tốc độ quét NHẤT QUÁN dù FPS thay đổi:
    --   60 FPS: dt ≈ 0.0167s → xoay 0.0167 × sweepSpeed mỗi frame
    --   30 FPS: dt ≈ 0.0333s → xoay 0.0333 × sweepSpeed mỗi frame
    --   → Tổng góc xoay sau 1 giây = sweepSpeed (bất kể FPS)
    if self.sweepSpeed ~= 0 and self.state == "firing" then
        self.angle = self.angle + self.sweepSpeed * dt
    end

    -- =========================================================================
    -- [3] MÁY TRẠNG THÁI (STATE MACHINE)
    -- =========================================================================
    -- Luồng: "telegraphing" → (telegraphDuration hết) → "firing" → (activeDuration hết) → isDead

    if self.state == "telegraphing" then
        -- -------------------------------------------------------------------
        -- TRẠNG THÁI: TELEGRAPHING (Cảnh báo / Nhắm mục tiêu)
        -- -------------------------------------------------------------------
        -- Đếm ngược telegraphDuration bằng cách trừ dần thời gian mỗi frame
        -- (Đây là pattern đếm ngược phổ biến trong game: timer -= dt)
        self.telegraphDuration = self.telegraphDuration - dt

        -- Khi hết thời gian cảnh báo → Chuyển sang bắn thật
        if self.telegraphDuration <= 0 then
            self.state = "firing"
            -- TIP: Đây là vị trí lý tưởng để:
            --   • Phát âm thanh bắn: soundManager:play("laser_fire")
            --   • Rung màn hình: camera:shake(0.3, 5)
            --   • Flash màn hình: screenEffect:flash(0.1)
        end

    elseif self.state == "firing" then
        -- -------------------------------------------------------------------
        -- TRẠNG THÁI: FIRING (Đang bắn thật sự)
        -- -------------------------------------------------------------------
        -- Tương tự: đếm ngược activeDuration
        self.activeDuration = self.activeDuration - dt

        -- Khi hết thời gian bắn → Đánh dấu laser để xóa khỏi game
        -- isDead = true là signal cho BulletManager biết cần remove object này
        if self.activeDuration <= 0 then
            self.isDead = true
        end
    end

    -- =========================================================================
    -- LÝ DO KHÔNG GỌI Projectile.update(self, dt)
    -- =========================================================================
    -- Projectile:update() thường tính: x = x + cos(angle) × speed × dt
    --                                  y = y + sin(angle) × speed × dt
    -- Vì speed = 0, tính toán trên sẽ không di chuyển gì (× 0 = 0)
    -- Nhưng Projectile:update() có thể có logic timer, boundary check...
    -- → Tùy thiết kế của Projectile base class mà quyết định có gọi hay không
    -- → Ở đây ta tự quản lý toàn bộ → KHÔNG gọi để tránh xung đột logic
end


-- =============================================================================
-- HÀM VẼ: LaserBeam:draw()
-- =============================================================================
-- Vẽ laser với 2 trạng thái hình ảnh hoàn toàn khác nhau:
--   "telegraphing" → Đường kẻ mỏng nhấp nháy (cảnh báo)
--   "firing"       → Hình chữ nhật sáng rực 2 lớp (hào quang + lõi)
--
-- KỸ THUẬT ĐỒ HỌA SỬ DỤNG:
--   • love.graphics.push/pop      : Lưu & khôi phục ma trận biến đổi
--   • love.graphics.translate     : Dịch chuyển gốc tọa độ
--   • love.graphics.rotate        : Xoay toàn bộ hệ tọa độ
--   • math.sin(time × tần_số)     : Tạo hiệu ứng nhấp nháy (oscillation)
--   • love.graphics.rectangle     : Vẽ hình chữ nhật
-- =============================================================================
function LaserBeam:draw()

    -- =========================================================================
    -- THIẾT LẬP HỆ TRỤC TỌA ĐỘ CỤC BỘ (LOCAL COORDINATE SYSTEM)
    -- =========================================================================
    -- Vấn đề: Làm thế nào để vẽ laser TỪ điểm (self.x, self.y) THEO HƯỚNG self.angle?
    --
    -- Giải pháp: Thay vì tính toán thủ công tọa độ 4 góc hình chữ nhật xoay,
    -- ta dùng kỹ thuật BIẾN ĐỔI HỆ TRỤC (Coordinate Transform):
    --
    --   Bước 1: push()      → Lưu hệ trục tọa độ hiện tại (gốc ở góc trên trái màn hình)
    --   Bước 2: translate() → Di chuyển gốc tọa độ đến điểm phát laser
    --   Bước 3: rotate()    → Xoay toàn bộ hệ trục theo góc laser
    --   Bước 4: Vẽ rectangle thẳng (không cần tính toán góc thủ công!)
    --   Bước 5: pop()       → Khôi phục hệ trục tọa độ ban đầu
    --
    -- Hình minh họa:
    --   Trước transform:          Sau translate + rotate:
    --   (0,0)──X                  (self.x, self.y)
    --     │                              ╲ self.angle
    --     Y                              ╲──────────→ (Hướng laser)
    --                                    ↓
    --
    -- → Sau transform, ta chỉ cần vẽ rectangle từ (0,0) về phía phải (+X)
    --   là laser sẽ tự nhiên xuất hiện đúng vị trí và hướng!

    -- Lưu trạng thái ma trận biến đổi hiện tại vào stack
    -- (LÖVE dùng stack để lồng nhiều transform, push/pop phải đi đôi nhau)
    love.graphics.push()

    -- Di chuyển gốc tọa độ đến điểm phát laser
    love.graphics.translate(self.x, self.y)

    -- Xoay hệ tọa độ theo góc bắn của laser
    -- Sau lệnh này: trục X+ chỉ theo hướng laser bắn
    love.graphics.rotate(self.angle)

    -- =========================================================================
    -- VẼ THEO TRẠNG THÁI
    -- =========================================================================

    if self.state == "telegraphing" then
        -- ---------------------------------------------------------------------
        -- VẼ TIA CẢNH BÁO (TELEGRAPH LINE)
        -- ---------------------------------------------------------------------
        -- Mục tiêu: Tạo đường kẻ mỏng nhấp nháy để cảnh báo người chơi
        --
        -- HIỆU ỨNG NHẤP NHÁY (Blinking):
        -- Dùng hàm sin để tạo giá trị dao động lên xuống theo thời gian
        --
        -- Công thức: blink = (sin(t × frequency) + 1) / 2
        --
        -- Phân tích:
        --   love.timer.getTime()  → Thời gian (giây) kể từ khi game khởi động
        --   × 30                  → Tần số nhấp nháy: 30 chu kỳ/giây (nhanh = nguy hiểm!)
        --   math.sin(...)         → Dao động trong khoảng [-1, 1]
        --   + 1                   → Dịch lên thành [0, 2]
        --   / 2                   → Chuẩn hóa về [0, 1]
        --
        -- Kết quả: blink ∈ [0, 1], thay đổi liên tục theo dạng sóng sin
        --
        -- Đồ thị blink theo thời gian:
        --   1 │  ╭──╮     ╭──╮     ╭──╮
        --     │ ╯    ╰   ╯    ╰   ╯    ╰
        --   0 │          ↑              ← Nhấp nháy qua lại
        --     └──────────────────────→ t
        local blink = (math.sin(love.timer.getTime() * 30) + 1) / 2

        -- Đặt màu: Giống laser thật nhưng Alpha thấp (0.3 → 0.5)
        -- 0.3 + blink × 0.2 → Alpha dao động trong [0.3, 0.5] theo sóng sin
        -- → Laser nhấp nháy giữa mờ (0.3) và hơi sáng hơn (0.5)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.3 + blink * 0.2)

        -- Vẽ đường kẻ mỏng (chỉ 2 pixel cao)
        -- love.graphics.rectangle(mode, x, y, width, height)
        --   Sau transform: x=0, y=0 là gốc phát laser
        --   x = 0       → Bắt đầu ngay tại điểm phát
        --   y = -1      → Lệch lên 1px so với đường trục (để căn giữa)
        --   width  = self.length → Dài tới tận cuối màn hình
        --   height = 2  → Chỉ 2 pixel, rất mỏng (tia nhắm thôi, không bắn thật)
        love.graphics.rectangle("fill", 0, -1, self.length, 2)

    elseif self.state == "firing" then
        -- ---------------------------------------------------------------------
        -- VẼ LASER THẬT SỰ (2 LỚP: AURA + CORE)
        -- ---------------------------------------------------------------------
        -- Kỹ thuật vẽ 2 lớp tạo cảm giác laser PHÁT SÁNG RỰC RỠ:
        --
        --   ┌────────────────────────────────────────────┐ ← Viền ngoài aura
        --   │         (Aura - mờ, màu laser)             │
        --   │  ┌──────────────────────────────────────┐  │
        --   │  │       (Core - sáng, màu trắng)       │  │
        --   │  └──────────────────────────────────────┘  │
        --   │                                            │
        --   └────────────────────────────────────────────┘
        --   ←────────────── self.length ────────────────→
        --   ←──── self.width (aura) ────────────────────→
        --        ←── self.width/2 (core) ───────────────→
        --
        -- LỚP 1: HÀO QUANG BÊN NGOÀI (Aura / Glow)
        -- Màu laser với Alpha = 0.5 (nửa trong suốt)
        -- Chiều cao = self.width (toàn bộ độ dày laser)
        -- y = -self.width/2 → Căn giữa tia laser theo trục Y
        love.graphics.setColor(self.color[1], self.color[2], self.color[3], 0.5)
        love.graphics.rectangle("fill", 0, -self.width / 2, self.length, self.width)

        -- LỚP 2: LÕI RỰC SÁNG BÊN TRONG (Core)
        -- Màu TRẮNG TINH (1,1,1) với Alpha = 1.0 → Lõi sáng chói nhất
        -- Chiều cao = self.width/2 → Chỉ bằng nửa aura, nằm ở chính giữa
        -- y = -self.width/4 → Căn giữa theo trục Y (nửa của nửa)
        --
        -- Tại sao màu trắng cho lõi?
        -- Trong thực tế: Lõi plasma/laser nóng nhất → trắng sáng
        -- Vùng ngoài nguội hơn → có màu (đỏ, xanh, v.v.)
        -- → Mô phỏng vật lý ánh sáng thực tế tạo cảm giác chân thực
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, -self.width / 4, self.length, self.width / 2)
    end

    -- =========================================================================
    -- KHÔI PHỤC HỆ TRỤC TỌA ĐỘ
    -- =========================================================================
    -- pop() hoàn tác tất cả translate() và rotate() đã thực hiện sau push()
    -- → Các vật thể khác vẽ sau (player, UI...) không bị ảnh hưởng
    --
    -- QUY TẮC VÀNG: push() và pop() phải luôn đi theo cặp!
    -- Thiếu pop() → Hệ trục bị lệch tích lũy qua nhiều frame → Game bị vỡ
    love.graphics.pop()

    -- Reset màu về mặc định (trắng đục) sau khi vẽ xong
    -- Lý do: setColor() ảnh hưởng toàn cục đến mọi lệnh vẽ tiếp theo
    love.graphics.setColor(1, 1, 1, 1)
end


-- =============================================================================
-- HÀM TIỆN ÍCH: LaserBeam:isLethal()
-- =============================================================================
-- Trả về true khi laser ĐANG THỰC SỰ BẮN và có thể gây sát thương
-- Trả về false khi đang ở giai đoạn cảnh báo (chưa bắn)
--
-- CÁCH SỬ DỤNG TRONG HỆ THỐNG VA CHẠM (Collision System):
--
--   -- Trong CollisionManager hoặc Player:update():
--   for _, projectile in ipairs(activeProjectiles) do
--       if projectile.isLethal and projectile:isLethal() then
--           -- Kiểm tra va chạm giữa player và laser
--           if checkRectCircleCollision(projectile, player) then
--               player:takeDamage(projectile.damage)
--           end
--       end
--   end
--
-- Tại sao cần hàm này thay vì kiểm tra trực tiếp state?
--   → Đóng gói (Encapsulation): Code bên ngoài không cần biết
--     LaserBeam dùng string "firing" để đại diện trạng thái
--   → Dễ thay đổi: Nếu sau này thêm state "superFiring",
--     chỉ cần sửa hàm isLethal() thay vì tìm kiếm khắp code
-- =============================================================================
function LaserBeam:isLethal()
    -- So sánh trạng thái hiện tại với "firing"
    -- Trả về boolean: true nếu đang bắn, false nếu không
    return self.state == "firing"
end


-- Export module
-- Dùng: local LaserBeam = require 'src.entities.projectiles.LaserBeam'
--       local laser = LaserBeam(boss, -30, 0, math.pi/4, { width=30, duration=3 })
return LaserBeam
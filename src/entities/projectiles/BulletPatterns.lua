-- ============================================================
-- FILE: your-game/src/entities/projectiles/BulletPatterns.lua
-- MỤC ĐÍCH: Thư viện các kiểu bắn đạn (patterns) cho Boss
-- TÁC GIẢ: [Tên bạn]
-- ============================================================
--
-- KIẾN THỨC NỀN TẢNG CẦN BIẾT TRƯỚC KHI ĐỌC FILE NÀY:
-- ┌─────────────────────────────────────────────────────┐
-- │  HỆ TỌA ĐỘ TRONG GAME (khác với toán học thông thường!)
-- │                                                     │
-- │  (0,0) ──────────── X tăng dần ──────────→         │
-- │    │                                                │
-- │    │  Y tăng dần (đi XUỐNG, không phải lên!)        │
-- │    ↓                                                │
-- │                                                     │
-- │  → Góc 0 rad   = bắn sang PHẢI                     │
-- │  → Góc π/2 rad = bắn xuống DƯỚI  (≈ 1.57)          │
-- │  → Góc π rad   = bắn sang TRÁI   (≈ 3.14)          │
-- │  → Góc 3π/2    = bắn lên TRÊN    (≈ 4.71)          │
-- └─────────────────────────────────────────────────────┘
--
-- GÓC TRONG LUA: Dùng RADIAN (không phải độ)
--   1 vòng tròn đầy = 360° = 2π radian ≈ 6.28 radian
--   Công thức đổi: radian = độ × (π / 180)
--
-- ============================================================

local BulletPatterns = {}

-- ============================================================
-- IMPORT (NẠP) CÁC MODULE ĐẠN ĐÃ ĐƯỢC ĐỊNH NGHĨA SẴN
-- ============================================================
-- require() trong Lua hoạt động giống import trong Python / Java
-- Nó tìm file .lua theo đường dẫn và trả về giá trị module đó export ra

local Bullet       = require 'src.entities.projectiles.Bullet'
-- Bullet: Đạn bình thường, bay thẳng theo một góc cố định

local HomingBullet = require 'src.entities.projectiles.HomingBullet'
-- HomingBullet: Đạn tự dẫn đường (homing), tự xoay về phía player

local LaserBeam    = require 'src.entities.projectiles.LaserBeam'
-- LaserBeam: Tia laser, KHÔNG phải đạn bay – nó là một beam tồn tại theo thời gian


-- ============================================================
-- GIẢI THÍCH THAM SỐ CHUNG (dùng xuyên suốt tất cả các hàm)
-- ============================================================
--[[
    manager  : Object BulletManager – chịu trách nhiệm quản lý pool đạn.
               Gọi manager:add(bullet) để đưa đạn vào màn hình.
               (Pool = bể chứa đạn, tái sử dụng object thay vì tạo mới liên tục)

    x, y     : Tọa độ xuất phát của đạn – thường là vị trí Boss hoặc họng súng Boss.

    properties : Bảng (table) Lua chứa các thông số tùy chỉnh của viên đạn, ví dụ:
                 {
                     color     = {1, 0, 0, 1},  -- Màu RGBA (Red=1, Green=0, Blue=0, Alpha=1)
                     damage    = 10,             -- Sát thương gây ra
                     size      = 5,             -- Bán kính / kích thước đạn
                     isHoming  = false,         -- Có phải đạn homing không?
                 }
]]


-- ============================================================
-- 1. CIRCLE BURST – Bắn tỏa tròn đều về mọi hướng
-- ============================================================
-- DÙNG CHO: Boss Petal Orb (Phase 1)
-- HÌNH DUNG: Như một vụ nổ pháo hoa – đạn bay ra đều nhau 360°
--
-- THAM SỐ:
--   count  : Số viên đạn (ví dụ: 8 → mỗi viên cách nhau 45°)
--   speed  : Tốc độ bay của mỗi viên đạn
--
-- TOÁN HỌC: Chia đều vòng tròn
--   Tổng góc 1 vòng = 2π radian
--   Góc giữa 2 viên liên tiếp = 2π / count
--
--   Viên thứ i sẽ bắn theo góc: angle_i = (i - 1) × angleStep
--   (i - 1) vì Lua đếm từ 1, nhưng viên đầu tiên bắn ở góc 0)
-- ============================================================
function BulletPatterns.circleBurst(manager, x, y, count, speed, properties)

    -- Tính bước góc: chia 360° (= 2π radian) thành `count` phần bằng nhau
    -- Ví dụ: count=8 → angleStep = 2π/8 = π/4 ≈ 0.785 radian ≈ 45°
    local angleStep = (2 * math.pi) / count

    -- Vòng lặp tạo từng viên đạn
    for i = 1, count do

        -- Tính góc của viên đạn thứ i
        -- i=1 → angle=0     (bắn sang phải)
        -- i=2 → angle=45°   (bắn chéo phải-xuống) v.v.
        local angle = (i - 1) * angleStep

        -- Tạo đạn tại vị trí (x, y), bắn theo góc `angle` với tốc độ `speed`
        local bullet = Bullet(x, y, angle, speed, properties)

        -- Đưa viên đạn vào hàng đợi của manager để được xử lý và vẽ lên màn hình
        manager:add(bullet)
    end
end


-- ============================================================
-- 2. CONE – Bắn hình nón (chùm đạn) nhắm về phía player
-- ============================================================
-- DÙNG CHO: Boss Needle Dart (Phase 1)
-- HÌNH DUNG: Như họng súng bắn ra một chùm đạn hình tam giác,
--            chùm đạn này nhắm thẳng vào vị trí hiện tại của player.
--
-- THAM SỐ:
--   targetX, targetY : Tọa độ của player (mục tiêu)
--   count            : Số viên đạn trong chùm
--   spreadAngle      : Góc mở rộng của chùm (radian)
--                      Ví dụ: π/4 (45°) → chùm khá hẹp
--                             π   (180°) → chùm rất rộng
--   speed            : Tốc độ đạn
--
-- TOÁN HỌC SỬ DỤNG:
--
--   [1] math.atan2(dy, dx) – Tìm góc nhắm vào mục tiêu
--       Cho biết góc (radian) từ điểm (x,y) đến điểm (targetX, targetY)
--       dy = targetY - y  (hiệu tọa độ Y)
--       dx = targetX - x  (hiệu tọa độ X)
--       → Trả về góc trong khoảng [-π, π]
--
--   [2] Phân bổ đạn đối xứng quanh tâm chùm:
--       startAngle = baseAngle - (spreadAngle / 2)
--       ┌──────────────────────────────────┐
--       │     [viên 1]...[giữa]...[viên n] │
--       │     ←── spreadAngle/2 ──→        │
--       │                  ↑               │
--       │              baseAngle           │
--       └──────────────────────────────────┘
-- ============================================================
function BulletPatterns.cone(manager, x, y, targetX, targetY, count, spreadAngle, speed, properties)

    -- [1] Tính góc trung tâm (baseAngle): góc từ Boss nhắm thẳng vào player
    --     math.atan2 trả về góc dựa trên tọa độ tương đối (dy, dx)
    local baseAngle = math.atan2(targetY - y, targetX - x)

    -- [2] Tính góc bắt đầu của viên đạn ngoài cùng bên TRÁI chùm
    --     Chúng ta đặt viên đầu ở nửa bên trái, rồi trải đều sang phải
    local startAngle = baseAngle - (spreadAngle / 2)

    -- [3] Tính bước góc giữa các viên đạn trong chùm
    --     Nếu count=1 → chỉ có 1 viên, tránh chia cho 0 bằng `(count - 1) or 1`
    local angleStep = spreadAngle / (count > 1 and (count - 1) or 1)

    -- [4] Tạo từng viên đạn trong chùm
    for i = 1, count do
        -- Viên thứ i nằm ở góc: startAngle + (i-1) × bướcGóc
        -- i=1 → startAngle (viên ngoài cùng trái)
        -- i=count → startAngle + spreadAngle = baseAngle + spreadAngle/2 (viên ngoài cùng phải)
        local angle = startAngle + (i - 1) * angleStep

        local bullet = Bullet(x, y, angle, speed, properties)
        manager:add(bullet)
    end
end


-- ============================================================
-- 3. SCATTER – Bắn rải rác ngẫu nhiên (hỗn loạn)
-- ============================================================
-- DÙNG CHO: Boss Bouncing Star (Phase 1)
-- HÌNH DUNG: Như bắn đạn ghém – mỗi viên bay theo hướng khác nhau
--            trong một vùng nửa dưới màn hình (hướng xuống dưới là chính)
--
-- THAM SỐ:
--   count            : Số viên đạn bắn ra
--   speedMin/speedMax: Khoảng tốc độ ngẫu nhiên (mỗi viên có tốc độ khác nhau)
--
-- TOÁN HỌC & HÀM NGẪU NHIÊN:
--
--   math.random() → trả về số thực trong [0.0, 1.0)
--   math.random(min, max) → trả về số nguyên trong [min, max]
--
--   Công thức tạo góc ngẫu nhiên hướng XUỐNG DƯỚI:
--   randomAngle = math.random() × π + (π/2) - 0.5
--
--   Giải thích:
--     math.random() × π      → góc ngẫu nhiên trong [0, π] (nửa dưới vòng tròn)
--     + π/2 - 0.5            → dịch chuyển vùng góc về xung quanh hướng thẳng xuống
--     Kết quả: đạn chủ yếu rơi xuống, hơi lệch trái phải ngẫu nhiên
-- ============================================================
function BulletPatterns.scatter(manager, x, y, count, speedMin, speedMax, properties)

    for i = 1, count do

        -- Tạo góc ngẫu nhiên trong vùng hướng xuống dưới
        -- math.random() ∈ [0, 1) → nhân π để ra góc trong [0, π]
        -- Cộng thêm offset (π/2 - 0.5) để lệch về phía dưới màn hình
        local randomAngle = math.random() * math.pi + (math.pi / 2) - 0.5

        -- Tạo tốc độ ngẫu nhiên trong khoảng [speedMin, speedMax]
        -- math.random(a, b) trả về số NGUYÊN ngẫu nhiên
        local randomSpeed = math.random(speedMin, speedMax)

        local bullet = Bullet(x, y, randomAngle, randomSpeed, properties)
        manager:add(bullet)
    end
end


-- ============================================================
-- 4. RAIN – Mưa đạn rơi từ trên xuống (trải đều theo chiều ngang)
-- ============================================================
-- DÙNG CHO: Boss Tracking Wisp (Phase 1), Shattered Soul (Phase 3)
-- HÌNH DUNG: Các viên đạn xuất hiện ở hàng ngang phía trên màn hình,
--            rồi đồng loạt rơi thẳng xuống như màn mưa.
--
-- THAM SỐ:
--   startX : Tọa độ X điểm bắt đầu phân bổ đạn (thường là cạnh trái màn hình)
--   startY : Tọa độ Y hàng xuất phát (thường là đỉnh màn hình, Y rất nhỏ)
--   width  : Chiều rộng vùng mưa (pixels)
--   count  : Số viên đạn (= số cột mưa)
--   speed  : Tốc độ rơi
--
-- TOÁN HỌC:
--   Khoảng cách giữa các viên đạn theo trục X = width / count
--   Tọa độ X của viên thứ i = startX + (i - 1) × stepX
--
--   Đạn rơi thẳng xuống → góc = π/2 radian = 90°
--   (Vì trong hệ tọa độ game, Y tăng là đi xuống, góc π/2 = xuống dưới)
--
-- ĐẶC BIỆT: Hỗ trợ 2 loại đạn dựa vào properties.isHoming:
--   - false (mặc định): Đạn thường, rơi thẳng
--   - true            : Đạn homing, vừa rơi vừa tự xoay về phía player
-- ============================================================
function BulletPatterns.rain(manager, startX, startY, width, count, speed, properties)

    -- Tính khoảng cách X giữa các điểm spawn đạn
    -- Ví dụ: width=800, count=10 → stepX=80 (cứ 80px có 1 viên)
    local stepX = width / count

    for i = 1, count do

        -- Tính tọa độ X của viên đạn thứ i
        -- i=1 → spawnX = startX + 0     (viên đầu tiên ở vị trí bắt đầu)
        -- i=2 → spawnX = startX + stepX (viên kế tiếp cách một bước)
        local spawnX = startX + (i - 1) * stepX

        -- Góc rơi thẳng xuống = π/2 radian (90°)
        -- Trong game: góc này tương ứng với vector (0, 1) – hướng xuống Y+
        local angle = math.pi / 2

        -- Quyết định tạo loại đạn nào dựa vào thuộc tính isHoming
        local bullet
        if properties.isHoming then
            -- HomingBullet: Tự dẫn hướng, cần biết target sau khi tạo
            bullet = HomingBullet(spawnX, startY, angle, speed, properties)
        else
            -- Bullet thường: Bay thẳng, không thay đổi hướng
            bullet = Bullet(spawnX, startY, angle, speed, properties)
        end

        manager:add(bullet)
    end
end


-- ============================================================
-- 5. SPIRAL PULSE – Bắn xoắn ốc (nhiều luồng quay liên tục)
-- ============================================================
-- DÙNG CHO: Boss Phantom Dagger (Phase 2), Vortex Ribbon (Phase 3)
-- HÌNH DUNG: Như bánh xe đang quay – mỗi "căm xe" là một luồng đạn,
--            vì Boss liên tục gọi hàm này với góc tăng dần, đạn tạo thành xoắn ốc
--
-- ⚠️ LƯU Ý QUAN TRỌNG VỀ CÁCH DÙNG:
--   Hàm này KHÔNG tự quay. Boss phải tự tăng currentAngle mỗi frame:
--
--   -- Trong Boss:update(dt):
--   self.spiralAngle = self.spiralAngle + rotationSpeed * dt
--   BulletPatterns.spiralPulse(manager, x, y, 3, self.spiralAngle, speed, props)
--
--   dt (delta time): Thời gian (giây) kể từ frame trước.
--   Nhân tốc độ với dt để animation mượt mà dù FPS thay đổi.
--
-- THAM SỐ:
--   arms         : Số luồng xoắn (số "cánh"). Ví dụ: 2=xoắn đôi, 3=xoắn ba
--   currentAngle : Góc hiện tại của luồng đầu tiên (tăng dần mỗi frame)
--
-- TOÁN HỌC:
--   Các luồng được phân bổ ĐỀU NHAU quanh vòng tròn:
--   Góc của luồng thứ i = currentAngle + (i - 1) × (2π / arms)
--
--   Ví dụ 3 luồng: cách nhau 120° = 2π/3 ≈ 2.094 radian
--   Luồng 1: currentAngle + 0°
--   Luồng 2: currentAngle + 120°
--   Luồng 3: currentAngle + 240°
-- ============================================================
function BulletPatterns.spiralPulse(manager, x, y, arms, currentAngle, speed, properties)

    -- Góc giữa 2 luồng liên tiếp để phân bổ đều 360°
    local angleStep = (2 * math.pi) / arms

    for i = 1, arms do

        -- Góc của luồng thứ i = góc hiện tại + offset đều nhau
        -- Vì currentAngle liên tục thay đổi bên ngoài → tạo hiệu ứng quay
        local angle = currentAngle + (i - 1) * angleStep

        local bullet = Bullet(x, y, angle, speed, properties)
        manager:add(bullet)
    end
end


-- ============================================================
-- 6. PINCER – Bắn gọng kìm (2 viên từ 2 bên trái-phải)
-- ============================================================
-- DÙNG CHO: Boss Boomerang Crescent (Phase 1)
-- HÌNH DUNG: Như cái kéo đang cắt – 2 viên bay từ hai phía khác nhau
--            hội tụ về phía player, khiến player khó tránh né.
--
-- THAM SỐ: (Không có count – luôn là 2 viên)
--   targetX, targetY : Vị trí player
--   speed            : Tốc độ đạn
--
-- TOÁN HỌC:
--   [1] Tính baseAngle: Góc thẳng từ Boss → Player (giống hàm cone)
--
--   [2] Lệch 2 bên bằng π/2.5 radian ≈ 72° mỗi bên
--       angleLeft  = baseAngle - π/2.5  → lệch 72° sang TRÁI
--       angleRight = baseAngle + π/2.5  → lệch 72° sang PHẢI
--
--   Tại sao 72°? Góc đủ lớn để 2 viên "mở rộng" tạo hình gọng kìm,
--   nhưng không quá 90° để vẫn có vẻ đang nhắm về phía player.
--
--   Hình minh họa (Boss ở dưới, Player ở trên):
--   [Đạn trái]  \     / [Đạn phải]
--                \   /
--                 \ /
--             [Đạn giữa - không bắn]
--                  ↑
--               [PLAYER]
-- ============================================================
function BulletPatterns.pincer(manager, x, y, targetX, targetY, speed, properties)

    -- Tính góc trung tâm nhắm vào player
    local baseAngle = math.atan2(targetY - y, targetX - x)

    -- Lệch góc sang trái (trừ đi) và sang phải (cộng thêm)
    -- π / 2.5 ≈ 1.257 radian ≈ 72°
    local angleLeft  = baseAngle - (math.pi / 2.5)
    local angleRight = baseAngle + (math.pi / 2.5)

    -- Tạo và thêm trực tiếp 2 viên đạn (không cần vòng lặp vì chỉ có 2 viên)
    manager:add(Bullet(x, y, angleLeft,  speed, properties))
    manager:add(Bullet(x, y, angleRight, speed, properties))
end


-- ============================================================
-- 7. SPAWN LASER – Triệu hồi tia laser
-- ============================================================
-- DÙNG CHO: Boss Laser Lotus (Phase 2)
-- HÌNH DUNG: Khác hoàn toàn với các hàm trên – không tạo ra viên đạn bay,
--            mà tạo ra một "tia sáng" tồn tại trong không gian theo thời gian.
--
-- SỰ KHÁC BIỆT LASER vs BULLET:
--   Bullet → Tạo ra → Bay đi → Va chạm → Biến mất
--   LaserBeam → Tạo ra → Ở yên (gắn với Boss) → Gây sát thương liên tục
--               → Tự biến mất sau một thời gian
--
-- THAM SỐ:
--   sourceBoss  : Object Boss – Laser gắn với Boss, di chuyển theo Boss
--   offsetX/Y   : Vị trí offset so với tâm Boss (điểm phát tia)
--                 Ví dụ: offsetX=-20 → tia xuất phát từ cạnh trái Boss
--   targetAngle : Góc bắn của tia laser (radian)
--
-- LƯU Ý THIẾT KẾ:
--   LaserBeam nhận `sourceBoss` (reference đến Boss object) thay vì tọa độ x,y cố định
--   → Cho phép laser "follow" Boss khi Boss di chuyển trong lúc đang bắn
-- ============================================================
function BulletPatterns.spawnLaser(manager, sourceBoss, offsetX, offsetY, targetAngle, properties)

    -- Tạo một object LaserBeam (không phải Bullet!)
    -- LaserBeam tự quản lý vòng đời, va chạm và hiệu ứng hình ảnh của nó
    local laser = LaserBeam(sourceBoss, offsetX, offsetY, targetAngle, properties)

    -- Thêm laser vào cùng manager với đạn thường
    -- Manager xử lý mọi projectile (đạn + laser) qua cùng interface :add()
    manager:add(laser)
end


-- ============================================================
-- EXPORT MODULE
-- ============================================================
-- Trả về bảng BulletPatterns để các file khác có thể dùng:
--
--   local BulletPatterns = require 'src.entities.projectiles.BulletPatterns'
--   BulletPatterns.circleBurst(manager, boss.x, boss.y, 12, 200, props)
-- ============================================================
return BulletPatterns
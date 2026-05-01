-- src/systems/combat/CollisionSystem.lua
-- ============================================================
--  CollisionSystem — Hệ thống phát hiện va chạm cấp cao
--
--  Vai trò trong kiến trúc:
--    Collision.lua (utils/math)  ← toán học thuần túy, zero-GC
--         ↑ wrap lên
--    CollisionSystem.lua         ← biết về "entities" (player, boss, bullets)
--         ↑ dùng bởi
--    BulletManager / CombatManager
--
--  Không xử lý damage — chỉ phát hiện và trả về danh sách va chạm.
--  DamageSystem.lua sẽ đọc kết quả và apply damage.
--
--  Hai loại kết quả:
--    collisions[] → va chạm thật → gây damage
--    grazes[]     → đạn lướt qua grazeRadius → tính điểm graze
-- ============================================================

local class     = require 'libs.middleclass.middleclass'
local Collision = require 'src.utils.math.Collision'

local CollisionSystem = class('CollisionSystem')

-- ────────────────────────────────────────────────────────────
--  CONSTRUCTOR
-- ────────────────────────────────────────────────────────────

function CollisionSystem:initialize()
    -- Bật/tắt graze detection (tốn thêm ~1 check/bullet/frame)
    self.grazeEnabled = true

    -- Bật/tắt toàn bộ system (dùng khi boss phase transition)
    self.enabled = true
end

-- ────────────────────────────────────────────────────────────
--  PUBLIC: checkAll
--  Hàm chính — gọi từ CombatManager mỗi frame
--
--  @param bullets  table[]   Danh sách projectiles từ BulletManager
--  @param player   Player    Đối tượng player
--  @return collisions, grazes
--    collisions = { {bullet, target, damage}, ... }
--    grazes     = { {bullet, player}, ... }
-- ────────────────────────────────────────────────────────────

function CollisionSystem:checkAll(bullets, player)
    if not self.enabled then
        return {}, {}
    end

    local collisions = {}
    local grazes     = {}

    for _, bullet in ipairs(bullets) do
        -- Chỉ kiểm tra đạn còn sống, player còn sống
        if not bullet.isDead and player and not player.isDead then

            local hit, graze = self:_checkBulletVsPlayer(bullet, player)

            if hit then
                -- Va chạm thật: thêm vào danh sách để DamageSystem xử lý
                collisions[#collisions + 1] = {
                    bullet = bullet,
                    target = player,
                    damage = bullet.damage or 1,
                }
            elseif graze and self.grazeEnabled then
                -- Graze: đạn lướt qua vùng graze nhưng không chạm hitbox
                grazes[#grazes + 1] = {
                    bullet = bullet,
                    player = player,
                }
            end
        end
    end

    return collisions, grazes
end

-- ────────────────────────────────────────────────────────────
--  PRIVATE: _checkBulletVsPlayer
--  Phân loại loại đạn và gọi hàm kiểm tra phù hợp.
--
--  @return hit (boolean), graze (boolean)
-- ────────────────────────────────────────────────────────────

function CollisionSystem:_checkBulletVsPlayer(bullet, player)
    -- Phân loại theo tên class (middleclass cung cấp .class.name)
    local bulletType = bullet.class and bullet.class.name or "Bullet"

    if bulletType == "LaserBeam" then
        return self:_checkLaserVsPlayer(bullet, player)
    else
        -- Bullet, HomingBullet → đều là hình tròn
        return self:_checkCircleVsPlayer(bullet, player)
    end
end

-- ────────────────────────────────────────────────────────────
--  _checkCircleVsPlayer
--  Đạn tròn: so sánh hitbox player vs radius đạn.
--  Dùng distanceSq để tránh sqrt (tối ưu hot loop).
--
--  Graze: đạn lướt qua grazeRadius nhưng không chạm hitboxRadius
-- ────────────────────────────────────────────────────────────

function CollisionSystem:_checkCircleVsPlayer(bullet, player)
    local hitRadius   = player.hitboxRadius or 3
    local grazeRadius = player.grazeRadius  or 28

    -- Dùng Collision.distSq từ utils/math/Collision.lua (tránh sqrt)
    local distSq = Collision.distSq(bullet.x, bullet.y, player.x, player.y)

    -- Kiểm tra HIT (hitbox thật)
    local hitSum = bullet.radius + hitRadius
    if distSq <= hitSum * hitSum then
        return true, false   -- hit=true, graze=false
    end

    -- Kiểm tra GRAZE (vùng ngoài hitbox nhưng trong grazeRadius)
    if self.grazeEnabled then
        local grazeSum = bullet.radius + grazeRadius
        if distSq <= grazeSum * grazeSum then
            return false, true   -- hit=false, graze=true
        end
    end

    return false, false
end

-- ────────────────────────────────────────────────────────────
--  _checkLaserVsPlayer
--  Laser dạng tia dài: dùng khoảng cách vuông góc (cross product).
--  Logic được giữ nguyên từ BulletManager gốc và tái sử dụng ở đây.
-- ────────────────────────────────────────────────────────────

function CollisionSystem:_checkLaserVsPlayer(laser, player)
    -- Laser chỉ gây damage khi đang ở trạng thái "firing"
    if not laser.isLethal or not laser:isLethal() then
        return false, false
    end

    local hitRadius = player.hitboxRadius or 3

    -- Vector từ gốc laser đến tâm player
    local dx     = player.x - laser.x
    local dy     = player.y - laser.y

    -- Vector hướng laser (unit vector)
    local lineDx = math.cos(laser.angle)
    local lineDy = math.sin(laser.angle)

    -- Dot product → hình chiếu player lên đường laser
    local dot = dx * lineDx + dy * lineDy

    -- Kiểm tra player có nằm trong phạm vi dài của laser không
    if dot < 0 or dot > (laser.length or 0) then
        return false, false
    end

    -- Khoảng cách vuông góc từ player đến lõi laser (cross product 2D)
    local perpDist = math.abs(lineDx * dy - lineDy * dx)
    local threshold = (laser.width or 0) * 0.5 + hitRadius

    if perpDist < threshold then
        return true, false
    end

    return false, false
end

-- ────────────────────────────────────────────────────────────
--  CONTROL
-- ────────────────────────────────────────────────────────────

---Tắt collision (dùng khi boss phase transition, cutscene, v.v.)
function CollisionSystem:disable()
    self.enabled = false
end

---Bật lại collision
function CollisionSystem:enable()
    self.enabled = true
end

---Bật/tắt graze detection
---@param flag boolean
function CollisionSystem:setGrazeEnabled(flag)
    self.grazeEnabled = flag
end

return CollisionSystem
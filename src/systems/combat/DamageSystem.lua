-- src/systems/combat/DamageSystem.lua
-- ============================================================
--  DamageSystem — Áp dụng sát thương lên entities
--
--  Vai trò trong kiến trúc:
--    CollisionSystem → phát hiện va chạm → trả về collisions[]
--         ↓ truyền vào
--    DamageSystem    → đọc collisions[] → gọi entity:takeDamage()
--                                       → gọi player:onGraze()
--
--  Nguyên tắc thiết kế:
--    - KHÔNG tự detect collision (CollisionSystem làm việc đó)
--    - KHÔNG tự tính damage formula (DamageCalculator làm việc đó)
--    - CHỈ làm 1 việc: apply kết quả lên đúng entity
--
--  Invincibility frames:
--    Actor.lua đã xử lý iFrames bên trong takeDamage().
--    DamageSystem KHÔNG cần duplicate logic đó — chỉ cần gọi
--    takeDamage() và Actor tự từ chối nếu đang i-frames.
--
--  Death handling:
--    Player:onDeath() và Boss:onDeath() tự xử lý.
--    DamageSystem chỉ fire callbacks nếu entity vừa chết
--    (isDead chuyển từ false → true sau takeDamage).
-- ============================================================

local class             = require 'libs.middleclass.middleclass'
local DamageCalculator  = require 'src.systems.combat.DamageCalculator'

local DamageSystem = class('DamageSystem')

-- ────────────────────────────────────────────────────────────
--  CONSTRUCTOR
-- ────────────────────────────────────────────────────────────

function DamageSystem:initialize()
    -- Callbacks — đăng ký từ BattleScreen để biết khi nào player/boss chết
    -- Dùng thay cho event system phức tạp khi chưa có EventBus
    self._onPlayerDeath = nil   -- function()
    self._onBossDeath   = nil   -- function(boss)
    self._onPlayerHit   = nil   -- function(damage)  -- dùng cho screen shake, SFX
    self._onGraze       = nil   -- function(bullet)

    -- Bật/tắt toàn bộ system
    self.enabled = true
end

-- ────────────────────────────────────────────────────────────
--  ĐĂNG KÝ CALLBACKS
-- ────────────────────────────────────────────────────────────

---Callback khi player chết
---@param fn function
function DamageSystem:onPlayerDeath(fn)
    self._onPlayerDeath = fn
end

---Callback khi boss chết
---@param fn function(boss)
function DamageSystem:onBossDeath(fn)
    self._onBossDeath = fn
end

---Callback mỗi khi player nhận damage (dùng cho screen shake, SFX)
---@param fn function(finalDamage)
function DamageSystem:onPlayerHit(fn)
    self._onPlayerHit = fn
end

---Callback khi player graze một viên đạn
---@param fn function(bullet)
function DamageSystem:onGraze(fn)
    self._onGraze = fn
end

-- ────────────────────────────────────────────────────────────
--  PUBLIC: applyCollisions
--  Nhận collisions[] từ CollisionSystem và apply damage.
--
--  @param collisions  table[]
--    Mỗi phần tử: { bullet=, target=, damage= }
-- ────────────────────────────────────────────────────────────

function DamageSystem:applyCollisions(collisions)
    if not self.enabled then return end

    for _, col in ipairs(collisions) do
        local bullet = col.bullet
        local target = col.target
        local raw    = col.damage

        -- Tính damage cuối qua DamageCalculator (crit, elemental, defense...)
        -- Hiện tại DamageCalculator trả về raw nếu chưa có stat system
        local final = DamageCalculator.calculate(raw, nil, target)

        -- Snapshot isDead trước khi apply để detect death event
        local wasAlive = not target.isDead

        -- Gọi takeDamage — Actor.lua tự xử lý i-frames bên trong
        target:takeDamage(final)

        -- Đạn tròn tự hủy sau khi chạm (Bullet/HomingBullet)
        -- LaserBeam KHÔNG hủy — nó gây damage liên tục
        local bulletType = bullet.class and bullet.class.name or ""
        if bulletType ~= "LaserBeam" and bullet.destroy then
            bullet:destroy()
        end

        -- Fire callback nếu target là player và vừa nhận damage
        -- (Actor i-frames có thể reject damage, hp không đổi → không fire)
        if wasAlive then
            -- Detect player bằng tag hoặc class name
            local isPlayer = target.class and target.class.name == "Player"
            local isBoss   = target.class and (
                target.class.name == "Boss"     or
                target.class.name == "DemonKing" or
                target.superclass ~= nil -- Mọi subclass của Boss
            )

            if isPlayer then
                self:_handlePlayerHit(target, final)
            elseif isBoss then
                self:_handleBossHit(target, final)
            end
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  PUBLIC: applyGrazes
--  Nhận grazes[] từ CollisionSystem và gọi player:onGraze()
--
--  @param grazes  table[]
--    Mỗi phần tử: { bullet=, player= }
-- ────────────────────────────────────────────────────────────

function DamageSystem:applyGrazes(grazes)
    if not self.enabled then return end

    for _, g in ipairs(grazes) do
        local player = g.player
        local bullet = g.bullet

        -- Player.lua đã xử lý per-bullet cooldown bên trong onGraze()
        if player.onGraze then
            player:onGraze(bullet)
        end

        -- Fire callback bên ngoài (SFX, particle spark...)
        if self._onGraze then
            self._onGraze(bullet)
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  PRIVATE: _handlePlayerHit
-- ────────────────────────────────────────────────────────────

function DamageSystem:_handlePlayerHit(player, damage)
    -- Fire onPlayerHit callback (screen shake, SFX)
    if self._onPlayerHit then
        self._onPlayerHit(damage)
    end

    -- Kiểm tra death event (isDead vừa chuyển true sau takeDamage)
    if player.isDead and self._onPlayerDeath then
        self._onPlayerDeath()
    end
end

-- ────────────────────────────────────────────────────────────
--  PRIVATE: _handleBossHit
-- ────────────────────────────────────────────────────────────

function DamageSystem:_handleBossHit(boss, damage)
    -- Kiểm tra death event
    if boss.isDead and self._onBossDeath then
        self._onBossDeath(boss)
    end
end

-- ────────────────────────────────────────────────────────────
--  CONTROL
-- ────────────────────────────────────────────────────────────

---Tắt damage (dùng trong phase transition, cutscene, bomb i-frames toàn cục)
function DamageSystem:disable()
    self.enabled = false
end

---Bật lại
function DamageSystem:enable()
    self.enabled = true
end

return DamageSystem
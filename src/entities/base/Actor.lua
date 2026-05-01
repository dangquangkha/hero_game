-- your-game/src/entities/base/Actor.lua
-- ============================================================
--  Actor — Subclass của Entity dành cho mọi object có HP/stats
--  Kế thừa: Entity → Actor → (Boss, Player, Enemy...)
--  Cung cấp: HP, damage, invincibility frames, death/hurt state
-- ============================================================

local class  = require 'libs.middleclass.middleclass'
local Entity = require 'src.entities.base.Entity'

local Actor = class('Actor', Entity)

-- ────────────────────────────────────────────────────────────
--  CONSTRUCTOR
-- ────────────────────────────────────────────────────────────

---@param x       number   Tọa độ X ban đầu
---@param y       number   Tọa độ Y ban đầu
---@param maxHp   number   HP tối đa
---@param config  table?   Bảng config tuỳ chọn (xem bên dưới)
---
--- config fields:
---   width         number   Chiều rộng bounding box   (mặc định 32)
---   height        number   Chiều cao  bounding box   (mặc định 32)
---   radius        number   Bán kính hitbox           (mặc định 12)
---   defense       number   Giảm sát thương phẳng     (mặc định 0)
---   iFramesDur    number   Giây bất tử sau khi nhận damage (mặc định 0.5)
---   deathDelay    number   Giây tồn tại sau khi HP = 0 trước khi destroy() (mặc định 0)
function Actor:initialize(x, y, maxHp, config)
    local cfg = config or {}

    -- Gọi Entity constructor
    Entity.initialize(self,
        x, y,
        cfg.width  or 32,
        cfg.height or 32,
        cfg.radius or 12
    )

    -- ── HP ───────────────────────────────────────────────────
    self.maxHp = maxHp or 100
    self.hp    = self.maxHp

    -- ── Stats cơ bản ─────────────────────────────────────────
    self.defense       = cfg.defense    or 0     -- Giảm damage phẳng trước khi tính
    self.isInvincible  = false                   -- Bật bởi iFrames hoặc event (cutscene...)

    -- ── Invincibility Frames (i-frames) ──────────────────────
    -- Sau khi nhận damage, Actor được bất tử trong iFramesDuration giây
    -- Đặt 0 để tắt hoàn toàn (thích hợp cho Boss nhận nhiều đạn/giây)
    self.iFramesDuration = cfg.iFramesDur or 0.5
    self._iFramesTimer   = 0

    -- ── Trạng thái ───────────────────────────────────────────
    -- "idle" | "moving" | "hurt" | "dying" | "dead"
    self.state      = "idle"
    self.isDead     = false      -- shorthand thay vì kiểm tra state == "dead"

    -- ── Death delay ──────────────────────────────────────────
    -- Cho phép animation chết phát xong trước khi destroy()
    self.deathDelay  = cfg.deathDelay or 0
    self._deathTimer = 0

    -- ── Blink effect (khi nhận damage) ───────────────────────
    self._blinkTimer    = 0
    self._blinkInterval = 0.08   -- giây mỗi lần nháy
    self._blinkVisible  = true
end

-- ────────────────────────────────────────────────────────────
--  UPDATE
-- ────────────────────────────────────────────────────────────

---@param dt number
function Actor:update(dt)
    if not self.isActive then return end

    -- Đếm ngược i-frames
    if self.isInvincible then
        if self._iFramesTimer > 0 then
            self._iFramesTimer = self._iFramesTimer - dt
            if self._iFramesTimer <= 0 then
                self._iFramesTimer = 0
                self.isInvincible  = false
            end
        else
            -- Trường hợp isInvincible được set true thủ công nhưng timer = 0
            -- Reset ngay để tránh bất tử vĩnh viễn
            self.isInvincible = false
        end

        -- Blink logic (nháy khi đang thực sự có i-frames)
        if self.isInvincible then
            self._blinkTimer = self._blinkTimer + dt
            if self._blinkTimer >= self._blinkInterval then
                self._blinkTimer   = self._blinkTimer - self._blinkInterval
                self._blinkVisible = not self._blinkVisible
            end
        else
            self._blinkVisible = true
        end
    else
        self._blinkVisible = true
        self._iFramesTimer = 0
    end

    -- Death delay countdown
    if self.state == "dying" then
        self._deathTimer = self._deathTimer + dt
        if self._deathTimer >= self.deathDelay then
            self:_completeDeath()
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  DAMAGE & HEALING
-- ────────────────────────────────────────────────────────────

--- Nhận sát thương.
--- Trả về lượng damage thực sự đã trừ (sau defense, i-frames).
---@param amount    number          Sát thương thô
---@param options   table?          { ignoreDefense=bool, ignoreIFrames=bool, silent=bool }
---@return number                   Damage thực tế đã áp dụng (0 nếu blocked)
function Actor:takeDamage(amount, options)
    -- Không nhận damage nếu đã chết
    if self.isDead then return 0 end

    local opts = options or {}

    -- Kiểm tra i-frames
    if self.isInvincible and not opts.ignoreIFrames then return 0 end

    -- Tính damage sau defense
    local finalDamage = amount
    if not opts.ignoreDefense then
        finalDamage = math.max(0, amount - self.defense)
    end
    if finalDamage <= 0 then return 0 end

    -- Trừ HP
    self.hp = math.max(0, self.hp - finalDamage)

    -- Hook: Subclass override để thêm visual/sound/feedback
    if not opts.silent then
        self:onDamaged(finalDamage)
    end

    -- Kích hoạt i-frames (nếu được cấu hình)
    if self.iFramesDuration > 0 then
        self:_startIFrames()
    end

    -- Kiểm tra chết
    if self.hp <= 0 then
        self:_triggerDeath()
    end

    return finalDamage
end

--- Hồi HP. Không vượt quá maxHp.
---@param amount  number
---@param options table?  { overheal=bool } — cho phép vượt maxHp
---@return number         Lượng HP thực sự đã hồi
function Actor:heal(amount, options)
    if self.isDead then return 0 end
    local opts    = options or {}
    local cap     = opts.overheal and (self.maxHp * 2) or self.maxHp
    local before  = self.hp
    self.hp       = math.min(cap, self.hp + amount)
    local healed  = self.hp - before
    if healed > 0 then self:onHealed(healed) end
    return healed
end

--- Đặt HP về một giá trị cụ thể (không qua damage pipeline).
---@param value number
function Actor:setHp(value)
    self.hp = math.clamp and math.clamp(value, 0, self.maxHp)
                          or math.max(0, math.min(self.maxHp, value))
    if self.hp <= 0 and not self.isDead then
        self:_triggerDeath()
    end
end

--- Tỉ lệ HP hiện tại (0.0 → 1.0).
---@return number
function Actor:getHpRatio()
    return self.maxHp > 0 and (self.hp / self.maxHp) or 0
end

-- ────────────────────────────────────────────────────────────
--  INVINCIBILITY FRAMES
-- ────────────────────────────────────────────────────────────

--- Bắt đầu i-frames với duration tuỳ chọn.
---@param duration number? Ghi đè iFramesDuration nếu truyền vào
function Actor:startInvincibility(duration)
    self.isInvincible  = true
    self._iFramesTimer = duration or self.iFramesDuration
    self._blinkTimer   = 0
    self._blinkVisible = true
end

-- (private) Gọi nội bộ sau khi nhận damage
function Actor:_startIFrames()
    self:startInvincibility(self.iFramesDuration)
end

-- ────────────────────────────────────────────────────────────
--  DEATH PIPELINE
-- ────────────────────────────────────────────────────────────

-- (private) Bước 1: HP chạm 0 → vào state "dying"
function Actor:_triggerDeath()
    if self.isDead then return end   -- guard: chỉ chạy 1 lần
    self.hp           = 0
    self.isDead       = true
    self:startInvincibility(1000)    -- Bất tử "vô hạn" (1000s) khi đang chết
    self.state        = "dying"
    self._deathTimer  = 0

    self:onDeath()   -- Hook: phát animation, âm thanh, drop item, v.v.

    -- Nếu deathDelay = 0, chết ngay lập tức
    if self.deathDelay <= 0 then
        self:_completeDeath()
    end
end

-- (private) Bước 2: Sau deathDelay → thực sự destroy Entity
function Actor:_completeDeath()
    self.state = "dead"
    self:destroy()   -- gọi Entity.destroy() → isAlive = false
end

-- ────────────────────────────────────────────────────────────
--  HOOKS (Subclass Override)
-- ────────────────────────────────────────────────────────────

--- Gọi khi nhận damage thực sự (sau defense, i-frames).
---@param amount number Damage đã áp dụng
function Actor:onDamaged(amount)
    -- VD: Shake camera, flash đỏ, âm thanh hurt
    -- Boss/Player override hàm này
    self.state = "hurt"
end

--- Gọi khi HP = 0, trước khi destroy().
function Actor:onDeath()
    -- VD: Phát animation chết, spawn drop, trigger event
end

--- Gọi khi được heal.
---@param amount number HP đã hồi
function Actor:onHealed(amount)
    -- VD: Hiệu ứng hào quang xanh, sound
end

-- ────────────────────────────────────────────────────────────
--  BLINK VISIBILITY (dùng trong draw của subclass)
-- ────────────────────────────────────────────────────────────

--- Trả về true nếu Actor nên được vẽ frame này.
--- Dùng trong hàm draw() của subclass để thực hiện blink effect:
---   if not self:shouldDraw() then return end
---@return boolean
function Actor:shouldDraw()
    if not self.isVisible then return false end
    -- Khi đang i-frames: nháy ẩn/hiện
    if self.isInvincible and not self._blinkVisible then return false end
    return true
end

-- ────────────────────────────────────────────────────────────
--  HP BAR HELPER (Utility vẽ thanh HP, dùng bởi subclass/DebugUI)
-- ────────────────────────────────────────────────────────────

---@param x      number  Góc trái thanh bar
---@param y      number  Góc trên thanh bar
---@param w      number  Chiều rộng
---@param h      number? Chiều cao (mặc định 8)
---@param config table?  { bgColor, fgColor, borderColor }
function Actor:drawHpBar(x, y, w, h, config)
    h   = h   or 8
    local cfg        = config or {}
    local bgColor    = cfg.bgColor     or {0.2, 0.2, 0.2, 0.8}
    local fgColor    = cfg.fgColor     or {0.1, 0.9, 0.2, 1.0}
    local borderColor= cfg.borderColor or {1,   1,   1,   0.4}
    local ratio      = self:getHpRatio()

    -- Nền
    love.graphics.setColor(bgColor)
    love.graphics.rectangle("fill", x, y, w, h)

    -- Thanh HP
    if ratio > 0.5 then
        love.graphics.setColor(fgColor)
    elseif ratio > 0.25 then
        love.graphics.setColor(1, 0.75, 0, 1)  -- vàng cam khi nguy hiểm
    else
        love.graphics.setColor(1, 0.1, 0.1, 1) -- đỏ khi sắp chết
    end
    love.graphics.rectangle("fill", x, y, w * ratio, h)

    -- Viền
    love.graphics.setColor(borderColor)
    love.graphics.rectangle("line", x, y, w, h)

    love.graphics.setColor(1, 1, 1)
end

-- ────────────────────────────────────────────────────────────
--  DEBUG
-- ────────────────────────────────────────────────────────────

--- Gọi Entity:drawDebug() và vẽ thêm thông tin HP.
function Actor:drawDebug(showRadius)
    Entity.drawDebug(self, showRadius)

    -- HP text phía trên entity
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.print(
        string.format("HP: %d/%d  DEF:%d", self.hp, self.maxHp, self.defense),
        self.x - 30, self.y - 28
    )

    -- Mini HP bar phía trên
    self:drawHpBar(self.x - 25, self.y - 38, 50, 5)
end

---@return string
function Actor:__tostring()
    return string.format("[%s#%d] x=%.1f y=%.1f hp=%d/%d state=%s",
        self.class.name, self.id,
        self.x, self.y,
        self.hp, self.maxHp,
        self.state)
end

return Actor
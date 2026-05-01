-- src/entities/player/Player.lua
-- ============================================================
--  Player — Nhân vật người chơi (Mouse-driven, Touhou-style)
--  Kế thừa: Entity → Actor → Player
--
--  THAY ĐỔI SO VỚI BẢN CŨ:
--    ✕ Xoá processMovementInput() keyboard hoàn toàn
--    ✕ Xoá Player:shoot() (đã chuyển sang tryAttack)
--    ✓ _processMouseMovement(): Vector2.expLerp factor=15
--    ✓ mousepressed() / mousereleased() đầy đủ
--    ✓ velocity tính từ mouse-delta để trail + state hoạt động đúng
--    ✓ focusSpeedMult đọc từ skillData (0.55)
--    ✓ Graze system tích hợp Collision.lua
--    ✓ drawFocus() vẽ hitbox dot pulse + graze ring xoay
--    ✓ Debug: Tab hiện melee arc, F1 toggle full debug
--
--  Tích hợp đầy đủ:
--    Vector2.lua   → expLerp mouse-follow
--    Collision.lua → clampToScreen, graze check, hitbox draw
--    Easing.lua    → hitbox dot pulse, graze ring fade
--    PlayerStates  → idle/moving/focusing/attacking/hurt/dying/dead
--    PlayerAbilities → melee/ranged/bomb/trail/power
-- ============================================================

local class           = require 'libs.middleclass.middleclass'
local Actor           = require 'src.entities.base.Actor'
local PlayerStates    = require 'src.entities.player.PlayerStates'
local PlayerAbilities = require 'src.entities.player.PlayerAbilities'
local Vector2         = require 'src.utils.math.Vector2'
local Collision       = require 'src.utils.math.Collision'
local Easing          = require 'src.utils.math.Easing'

local Player = class('Player', Actor)

-- ────────────────────────────────────────────────────────────
--  CONSTANTS
-- ────────────────────────────────────────────────────────────

local DEFAULTS = {
    -- Hitbox (Danmaku-chuẩn: chỉ 3px tâm mới "chết")
    HITBOX_RADIUS    = 3,
    GRAZE_RADIUS     = 28,    -- Sync với player_skills.json graze.radius
    SPRITE_W         = 32,
    SPRITE_H         = 32,

    -- Mouse-follow
    -- factor=15 → player "dính" vào con trỏ gần như tức thì
    -- Đổi sang ~6 nếu muốn mượt rõ rệt hơn
    LERP_FACTOR      = 15,

    -- Cap velocity để trail không bị quá dài ở FPS thấp
    SPEED_CAP        = 600,   -- px/giây

    -- Focus speed multiplier (fallback nếu không load được skillData)
    FOCUS_SPEED_MULT = 0.55,

    -- Screen margin
    MARGIN           = 8,

    -- HP / Lives
    MAX_HP           = 5,
    IFRAMES_DUR      = 1.8,

    -- Bombs
    MAX_BOMBS        = 3,
    BOMB_COOLDOWN    = 0.5,

    -- Graze
    GRAZE_SCORE      = 10,
    GRAZE_CD         = 0.25,  -- Giây mỗi viên đạn chỉ được tính 1 graze

    -- Debug
    DEBUG_KEY        = "f1",
}

-- ────────────────────────────────────────────────────────────
--  CONSTRUCTOR
-- ────────────────────────────────────────────────────────────

---@param x             number
---@param y             number
---@param combatManager table
---@param config        table?
function Player:initialize(x, y, combatManager, config)
    local cfg = config or {}

    Actor.initialize(self, x, y, cfg.maxHp or DEFAULTS.MAX_HP, {
        width      = cfg.spriteW      or DEFAULTS.SPRITE_W,
        height     = cfg.spriteH      or DEFAULTS.SPRITE_H,
        radius     = cfg.hitboxRadius or DEFAULTS.HITBOX_RADIUS,
        defense    = 0,
        iFramesDur = cfg.iFramesDur   or DEFAULTS.IFRAMES_DUR,
        deathDelay = 0,
    })

    -- ── Refs ──────────────────────────────────────────────────
    self.combatManager   = combatManager

    -- ── Vị trí & Vector ───────────────────────────────────────
    self.x               = x or 400
    self.y               = y or 500
    self._posV           = Vector2.new(self.x, self.y)
    self._prevPos        = Vector2.new(self.x, self.y)
    self.velocity        = Vector2.new(0, 0)

    -- ── Hitbox & Mechanics ────────────────────────────────────
    self.hitboxRadius    = self.radius
    self.grazeRadius     = cfg.grazeRadius or DEFAULTS.GRAZE_RADIUS
    self._lerpFactor     = cfg.lerpFactor or DEFAULTS.LERP_FACTOR

    -- ── Focus ─────────────────────────────────────────────────
    self.isFocused       = false
    self.focusSpeedMult  = cfg.focusSpeedMult or DEFAULTS.FOCUS_SPEED_MULT

    -- ── Screen bounds ─────────────────────────────────────────
    self.margin          = cfg.margin or DEFAULTS.MARGIN

    -- ── Lives ─────────────────────────────────────────────────
    self.lives           = self.maxHp
    self.hp              = self.maxHp

    -- ── Bombs ─────────────────────────────────────────────────
    self.maxBombs        = cfg.maxBombs    or DEFAULTS.MAX_BOMBS
    self.bombs           = self.maxBombs
    self.bombCooldown    = cfg.bombCooldown or DEFAULTS.BOMB_COOLDOWN
    self._bombCDTimer    = 0

    -- ── Score ─────────────────────────────────────────────────
    self.score           = 0
    self.grazeCount      = 0
    self.grazeScore      = cfg.grazeScore or DEFAULTS.GRAZE_SCORE
    self._grazeCooldowns = {}

    -- ── State flags ───────────────────────────────────────────
    self._pendingAttack  = false
    self._pendingHurt    = false

    -- ── State machine ─────────────────────────────────────────
    self.stateMachine    = PlayerStates.new(self)
    self._stateMachine   = self.stateMachine   -- backref cho States.attacking

    -- ── Abilities ─────────────────────────────────────────────
    self.abilities       = PlayerAbilities.new(self)

    -- ── Visual ────────────────────────────────────────────────
    self._spriteColor    = { 0, 0.5, 1 }
    self._hitboxColor    = { 1, 0,   0 }
    self._grazeRings     = {}

    -- ── Debug ─────────────────────────────────────────────────
    self._debugMode      = false
    self.camera          = nil   -- gán từ ngoài: player.camera = cam

    -- ── Tags ──────────────────────────────────────────────────
    self:addTag("player")
    self.zOrder = 10

    print(string.format("[Player] Initialized at (%.0f, %.0f)", x, y))
end

-- ────────────────────────────────────────────────────────────
--  UPDATE
-- ────────────────────────────────────────────────────────────

---@param dt number
function Player:update(dt)
    if not self.isActive then return end

    Actor.update(self, dt)

    -- Focus state
    self.isFocused = love.keyboard.isDown("lshift")
                  or love.keyboard.isDown("rshift")

    -- Di chuyển theo chuột
    if self:_canMove() then
        self:_processMouseMovement(dt)
    else
        self.velocity = Vector2.expLerp(self.velocity, Vector2.zero(), 10, dt)
    end

    self.stateMachine:update(dt)
    self.abilities:update(dt)
    self:_updateGrazeRings(dt)

    -- Sync lives
    self.lives = self.hp
end

-- ────────────────────────────────────────────────────────────
--  MOUSE MOVEMENT
-- ────────────────────────────────────────────────────────────

---Di chuyển player theo chuột bằng exponential lerp.
---Frame-rate independent — không bị lệch khi FPS thay đổi.
---
---  Với factor=15 và dt=1/60:
---    t = 1 - e^(-15/60) ≈ 0.22  → hội tụ ~22% khoảng cách mỗi frame
---    Sau 10 frame (~0.17s) player đã ở >90% vị trí chuột
---
---  Focus mode: factor *= focusSpeedMult (0.55) → chậm hơn ~45%
---@param dt number
function Player:_processMouseMovement(dt)
    local mx, my   = love.mouse.getPosition()
    local target   = Vector2.new(mx, my)

    local factor = self._lerpFactor or 15
    if self.isFocused then
        factor = factor * (self.focusSpeedMult or 0.55)
    end

    if self._debugMode then
        print(string.format("[Player] Movement Debug - Factor: %.2f, dt: %.4f", factor, dt))
    end

    self._prevPos:set(self._posV)
    self._posV = Vector2.expLerp(self._posV, target, factor, dt)

    local W  = love.graphics.getWidth()
    local H  = love.graphics.getHeight()
    local m  = self.margin
    local hw = self.width  * 0.5
    local hh = self.height * 0.5

    self._posV.x = math.max(m + hw, math.min(W - m - hw, self._posV.x))
    self._posV.y = math.max(m + hh, math.min(H - m - hh, self._posV.y))

    self.x = self._posV.x
    self.y = self._posV.y

    -- Tính velocity an toàn (chống Infinity/NaN khi dt quá nhỏ)
    if dt > 0.00001 then
        -- Inline math để tránh treo máy khi gọi hàm Vector2.sub
        local dx = self._posV.x - self._prevPos.x
        local dy = self._posV.y - self._prevPos.y
        
        local rawVelX = dx / dt
        local rawVelY = dy / dt
        local rawVel = Vector2.new(rawVelX, rawVelY)
        
        self.velocity = rawVel:clampLength(DEFAULTS.SPEED_CAP)
    else
        self.velocity:setXY(0, 0)
    end
end

---@return boolean
function Player:_canMove()
    local s = self.stateMachine:getState()
    return s ~= "hurt"
       and s ~= "dying"
       and s ~= "dead"
end

-- ────────────────────────────────────────────────────────────
--  INPUT: MOUSE
-- ────────────────────────────────────────────────────────────

---@param x      number
---@param y      number
---@param button number  1=trái, 2=phải, 3=giữa
function Player:mousepressed(x, y, button)
    if self.isDead then return end

    if button == 1 then
        -- Ưu tiên charged beam nếu đủ điều kiện
        if self.abilities:_canUseChargedBeam() then
            self.abilities:startCharge()
        else
            -- Melee hoặc ranged slash wave
            local attacked = self.abilities:tryAttack()
            if attacked then
                self._pendingAttack = true
            end
        end
    end

    self.stateMachine:mousepressed(button)
end

---@param x      number
---@param y      number
---@param button number
function Player:mousereleased(x, y, button)
    if button == 1 then
        -- Nhả chuột → bắn beam nếu đang charge
        local fired = self.abilities:releaseCharge()
        if fired then
            self._pendingAttack = true
        end
    end

    self.stateMachine:mousereleased(button)
end

-- ────────────────────────────────────────────────────────────
--  INPUT: KEYBOARD
-- ────────────────────────────────────────────────────────────

---@param key string
function Player:keypressed(key)
    if key == "x"               then self:useBomb() end
    if key == DEFAULTS.DEBUG_KEY then
        self._debugMode = not self._debugMode
        print("[Player] Debug: " .. tostring(self._debugMode))
    end

    self.stateMachine:keypressed(key)
    self.abilities:keypressed(key)
end

---@param key string
function Player:keyreleased(key)
    self.stateMachine:keyreleased(key)
    self.abilities:keyreleased(key)
end

-- ────────────────────────────────────────────────────────────
--  DAMAGE / LIVES
-- ────────────────────────────────────────────────────────────

---@param amount number
function Player:onDamaged(amount)
    self._pendingHurt = true
    print(string.format("[Player] Hit! Lives: %d → %d", self.hp + amount, self.hp))
end

function Player:onDeath()
    self.stateMachine:setState("dying")
    print("[Player] All lives lost → GAME OVER")
end

---@param amount number?
function Player:gainLife(amount)
    local gained = self:heal(amount or 1)
    if gained > 0 then
        self.lives = self.hp
        print(string.format("[Player] 1-UP! Lives: %d", self.lives))
    end
end

-- ────────────────────────────────────────────────────────────
--  BOMB
-- ────────────────────────────────────────────────────────────

---@return boolean
function Player:useBomb()
    if self.isDead             then return false end
    if self._bombCDTimer > 0   then return false end
    if self.abilities.bombStock <= 0 then return false end

    self._bombCDTimer = self.bombCooldown
    self.abilities:activateBomb()

    print(string.format("[Player] Bomb! Stock: %d", self.abilities.bombStock))
    return true
end

---@param amount number?
function Player:gainBomb(amount)
    local maxStock = self.abilities._skillData.bomb.base.maxStock or DEFAULTS.MAX_BOMBS
    self.abilities.bombStock = math.min(maxStock,
        self.abilities.bombStock + (amount or 1))
end

---@return boolean
function Player:canUseBomb()
    return self.abilities.bombStock > 0
       and self._bombCDTimer <= 0
       and not self.isDead
end

-- ────────────────────────────────────────────────────────────
--  GRAZE
-- ────────────────────────────────────────────────────────────

---Gọi bởi BulletManager khi đạn lướt qua vùng graze.
---@param bullet table  { x, y, radius, id? }
function Player:onGraze(bullet)
    if self.isDead or self.isInvincible then return end

    local bulletId = bullet.id or tostring(bullet)
    if self._grazeCooldowns[bulletId] then return end
    self._grazeCooldowns[bulletId] = DEFAULTS.GRAZE_CD

    self.grazeCount = self.grazeCount + 1
    self.score      = self.score + self.grazeScore

    -- Spawn graze ring (Giới hạn tối đa 15 vòng để tránh lag)
    if #self._grazeRings < 15 then
        local vizCfg    = self.abilities._skillData
                       and self.abilities._skillData.graze
                       and self.abilities._skillData.graze.visual
        table.insert(self._grazeRings, {
            timer     = 0,
            duration  = vizCfg and vizCfg.expandDuration or 0.5,
            maxRadius = self.grazeRadius * (vizCfg and vizCfg.ringExpandMult or 1.6),
            alpha     = vizCfg and vizCfg.ringAlphaMax or 0.6,
            color     = vizCfg and vizCfg.ringColor or { 0.4, 0.8, 1.0 },
        })
    end
end

---Kiểm tra bullet có trong graze / hitbox không.
---Gọi từ BulletManager trong update loop.
---@param bx number
---@param by number
---@param br number
---@return boolean inGraze   (ngoài hitbox nhưng trong graze radius)
---@return boolean inHitbox
function Player:checkGraze(bx, by, br)
    local inHitbox = Collision.circleCircle(
        self.x, self.y, self.hitboxRadius, bx, by, br)
    local inGraze  = Collision.circleCircle(
        self.x, self.y, self.grazeRadius,  bx, by, br)
    return inGraze and not inHitbox, inHitbox
end

---@param dt number
function Player:_updateGrazeRings(dt)
    for i = #self._grazeRings, 1, -1 do
        local ring = self._grazeRings[i]
        ring.timer = ring.timer + dt
        if ring.timer >= ring.duration then
            table.remove(self._grazeRings, i)
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  POWER (delegate)
-- ────────────────────────────────────────────────────────────

function Player:gainPower(amount)   self.abilities:gainPower(amount)  end
function Player:losePower(amount)   self.abilities:losePower(amount)  end
function Player:getPowerLevel()     return self.abilities:getPowerLevel() end

-- ────────────────────────────────────────────────────────────
--  DRAW
-- ────────────────────────────────────────────────────────────

function Player:draw()
    if not self:shouldDraw() then return end

    love.graphics.push()

    -- Trail + swing arc + beam (vẽ trước sprite)
    self.abilities:draw()

    -- Graze rings
    self:_drawGrazeRings()

    -- Sprite (placeholder rectangle)
    local sc = self._spriteColor
    love.graphics.setColor(sc[1], sc[2], sc[3], 1)
    love.graphics.rectangle("fill",
        self.x - self.width  * 0.5,
        self.y - self.height * 0.5,
        self.width, self.height)

    -- Hitbox dot (luôn hiện)
    love.graphics.setColor(
        self._hitboxColor[1],
        self._hitboxColor[2],
        self._hitboxColor[3], 1)
    love.graphics.circle("fill", self.x, self.y, self.hitboxRadius)

    -- Focus visuals
    if self.isFocused then
        self:_drawFocusVisuals()
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

function Player:_drawGrazeRings()
    for _, ring in ipairs(self._grazeRings) do
        local t      = Easing.progress(ring.timer, ring.duration)
        local radius = Easing.map(t, self.grazeRadius, ring.maxRadius, Easing.quadOut)
        local alpha  = Easing.map(t, ring.alpha, 0, Easing.sineOut)
        local c      = ring.color

        love.graphics.setColor(c[1], c[2], c[3], alpha)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", self.x, self.y, radius)
        love.graphics.setLineWidth(1)
    end
end

function Player:_drawFocusVisuals()
    local sm     = self.stateMachine
    local pulse  = sm:getFocusPulse()
    local rotate = sm:getFocusRotate()

    -- Graze ring tĩnh mờ
    love.graphics.setColor(0.6, 0.8, 1, 0.18)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", self.x, self.y, self.grazeRadius)

    -- 8 chấm xoay quanh graze radius
    local dotCount = 8
    love.graphics.setColor(0.6, 0.85, 1, 0.45)
    for i = 1, dotCount do
        local a  = rotate + (i - 1) * (2 * math.pi / dotCount)
        love.graphics.circle("fill",
            self.x + math.cos(a) * self.grazeRadius,
            self.y + math.sin(a) * self.grazeRadius, 2.5)
    end

    -- Hitbox dot pulse
    local pulseT   = (math.sin(pulse) + 1) * 0.5   -- [0..1]
    local dotScale = 1 + pulseT * 0.6               -- [1..1.6]
    local dotAlpha = 0.7 + pulseT * 0.3             -- [0.7..1.0]

    -- Outer ring
    love.graphics.setColor(1, 1, 1, dotAlpha * 0.4)
    love.graphics.circle("line", self.x, self.y,
        self.hitboxRadius * dotScale * 2.5)

    -- Inner dot pulse
    love.graphics.setColor(1, 1, 1, dotAlpha)
    love.graphics.circle("fill", self.x, self.y,
        self.hitboxRadius * dotScale)

    -- Crosshair
    local crossLen = 8
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(self.x - crossLen, self.y, self.x + crossLen, self.y)
    love.graphics.line(self.x, self.y - crossLen, self.x, self.y + crossLen)
end

-- ────────────────────────────────────────────────────────────
--  HUD
-- ────────────────────────────────────────────────────────────

---@param x number?
---@param y number?
function Player:drawHUD(x, y)
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    x = x or 10
    y = y or H - 60

    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.rectangle("fill", x - 6, y - 4, 300, 52, 4)

    -- Lives
    love.graphics.setColor(0.2, 0.6, 1, 1)
    love.graphics.print("Lives:", x, y)
    for i = 1, self.maxHp do
        local alive = i <= self.lives
        love.graphics.setColor(
            alive and 0.2 or 0.25,
            alive and 0.6 or 0.25,
            alive and 1.0 or 0.25, 1)
        love.graphics.circle("fill", x + 52 + (i-1)*18, y + 8, 6)
    end

    -- Bombs
    local maxStock  = self.abilities._skillData.bomb.base.maxStock or DEFAULTS.MAX_BOMBS
    local bombStock = self.abilities.bombStock
    love.graphics.setColor(1, 0.8, 0.2, 1)
    love.graphics.print("Bombs:", x, y + 20)
    for i = 1, maxStock do
        local active = i <= bombStock
        love.graphics.setColor(
            active and 1   or 0.25,
            active and 0.8 or 0.25,
            active and 0.2 or 0.25, 1)
        love.graphics.rectangle("fill", x + 52 + (i-1)*18, y + 22, 10, 10, 2)
    end

    -- Power
    local pwr    = self.abilities:getPowerLevel()
    local maxPwr = PlayerAbilities.MAX_POWER
    love.graphics.setColor(0.4, 1, 0.6, 1)
    love.graphics.print(
        string.format("Power: %d/%d", pwr, maxPwr), x + 130, y)

    -- Score + Graze
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(
        string.format("Score: %d", self.score), W - 170, y)
    love.graphics.setColor(0.6, 0.8, 1, 1)
    love.graphics.print(
        string.format("Graze: %d", self.grazeCount), W - 170, y + 18)

    -- State
    love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
    love.graphics.print(
        string.format("[%s]%s",
            self.stateMachine:getState(),
            self.isFocused and " FOCUS" or ""),
        W - 170, y + 36)

    love.graphics.setColor(1, 1, 1)
end

-- ────────────────────────────────────────────────────────────
--  DEBUG
-- ────────────────────────────────────────────────────────────

---@param full boolean?
function Player:drawDebug(full)
    full = full or self._debugMode

    if full then
        -- Hitbox
        Collision.drawHitbox(self, { 1, 0.2, 0.2, 0.7 })

        -- Graze radius
        love.graphics.setColor(0.4, 0.6, 1, 0.25)
        love.graphics.circle("line", self.x, self.y, self.grazeRadius)

        -- Melee arc (Tab để toggle)
        if self.stateMachine:is("attacking")
        or love.keyboard.isDown("tab") then
            self.abilities:drawDebug()
        end

        -- Velocity arrow
        local vlen = self.velocity:length()
        if vlen > 2 then
            love.graphics.setColor(0, 1, 1, 0.8)
            love.graphics.setLineWidth(1.5)
            love.graphics.line(
                self.x, self.y,
                self.x + self.velocity.x * 0.08,
                self.y + self.velocity.y * 0.08)
            love.graphics.setLineWidth(1)
        end

        -- Mouse target line
        local mx, my = love.mouse.getPosition()
        love.graphics.setColor(1, 1, 0, 0.2)
        love.graphics.line(self.x, self.y, mx, my)
        love.graphics.setColor(1, 1, 0, 0.5)
        love.graphics.circle("line", mx, my, 4)
    end

    -- Info panel
    local px, py = 10, 10
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", px-4, py-4, 290, 178, 4)

    love.graphics.setColor(0.4, 1, 0.8)
    local lines = {
        "State:    " .. self.stateMachine:getState(),
        "History:  " .. self.stateMachine:getHistory(),
        string.format("Pos:      (%.0f, %.0f)", self.x, self.y),
        string.format("Velocity: (%.0f, %.0f) |%.0f|",
            self.velocity.x, self.velocity.y, self.velocity:length()),
        string.format("Focus: %s  LerpFactor: %.1f (x%.2f)",
            tostring(self.isFocused), self._lerpFactor,
            self.isFocused and self.focusSpeedMult or 1.0),
        string.format("Lives: %d  Bombs: %d  Power: %d",
            self.lives, self.abilities.bombStock,
            self.abilities:getPowerLevel()),
        string.format("Score: %d  Graze: %d",
            self.score, self.grazeCount),
        string.format("Combo: hit%d  Window: %.2fs",
            self.abilities._comboHit,
            self.abilities._comboWindowTimer),
        string.format("MeleeCD: %.2f  RangedCD: %.2f  ChargeRatio: %.0f%%",
            self.abilities._meleeCooldown,
            self.abilities._rangedCooldown,
            self.abilities._chargeRatio * 100),
        string.format("Pending: attack=%s hurt=%s",
            tostring(self._pendingAttack),
            tostring(self._pendingHurt)),
        "[F1] debug  [Tab] melee arc",
    }
    for i, line in ipairs(lines) do
        love.graphics.print(line, px, py + (i-1) * 16)
    end

    love.graphics.setColor(1, 1, 1)
end

-- ────────────────────────────────────────────────────────────
--  EXPORT
-- ────────────────────────────────────────────────────────────

--[[
  TÍCH HỢP VÀO GAME SCENE (BẮT BUỘC relay mouse events):

  local player = Player:new(W/2, H*0.75, combatManager)
  player.camera = camera   -- optional

  function love.update(dt)      player:update(dt)          end
  function love.draw()
      player:draw()
      player:drawHUD()
      if player._debugMode then player:drawDebug(true) end
  end

  -- BẮT BUỘC — không có 2 hàm này player không tấn công được:
  function love.mousepressed(x,y,btn)  player:mousepressed(x,y,btn)  end
  function love.mousereleased(x,y,btn) player:mousereleased(x,y,btn) end
  function love.keypressed(key)        player:keypressed(key)         end
  function love.keyreleased(key)       player:keyreleased(key)        end

  -- Graze check từ BulletManager (gọi mỗi frame với từng bullet):
  local inGraze, inHitbox = player:checkGraze(b.x, b.y, b.radius)
  if inHitbox and not player.isInvincible then
      player:takeDamage(1)
  elseif inGraze then
      player:onGraze(b)
  end
--]]

return Player
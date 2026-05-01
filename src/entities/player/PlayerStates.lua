-- src/entities/player/PlayerStates.lua
-- ============================================================
--  PlayerStates — State machine cho Player (Mouse-driven)
--
--  THAY ĐỔI SO VỚI BẢN CŨ:
--    ✕ Xoá hoàn toàn keyboard movement (WASD / arrow keys)
--    ✕ Xoá shoot system (Z / lctrl)
--    ✓ Di chuyển theo chuột (expLerp trong Player.lua)
--    ✓ Focus mode = giữ Shift (vẫn giữ)
--    ✓ Thêm state MỚI: "attacking"
--    ✓ Transitions cập nhật: idle ↔ moving dựa trên mouse delta
--
--  State graph:
--
--     ┌──────┐  chuột gần  ┌────────┐
--     │ idle │ ←─────────→ │ moving │
--     └──┬───┘             └───┬────┘
--        │  Shift               │  Shift
--        ▼                     ▼
--     ┌──────────────────────────┐
--     │        focusing          │
--     └──────────┬───────────────┘
--                │
--     click trái + target dalam range / kondisi ranged
--                ▼
--     ┌──────────────────────────┐
--     │        attacking         │  ← STATE MỚI
--     └──────────────────────────┘
--                │  hết swing duration
--                ▼
--     quay lại state trước (idle / moving / focusing)
--
--     Bất kỳ state nào + nhận damage → hurt → (tự về)
--     Bất kỳ state nào + isDead      → dying → dead
-- ============================================================

-- ────────────────────────────────────────────────────────────
--  THRESHOLD: khoảng cách chuột → player để coi là "đang di chuyển"
--  Player dùng expLerp factor=15 nên rất nhanh hội tụ.
--  Chỉ cần chuột cách > MOVE_THRESHOLD pixel là coi là moving.
-- ────────────────────────────────────────────────────────────
local MOVE_THRESHOLD = 4   -- pixel

-- ────────────────────────────────────────────────────────────
--  HELPER: kiểm tra chuột có đang "kéo" player không
-- ────────────────────────────────────────────────────────────
local function isMouseMoving(player)
    local mx, my = love.mouse.getPosition()
    local px = player.x or 0
    local py = player.y or 0
    local dx = mx - px
    local dy = my - py
    return (dx * dx + dy * dy) > (MOVE_THRESHOLD * MOVE_THRESHOLD)
end

local function isFocusHeld()
    return love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
end

-- ────────────────────────────────────────────────────────────
--  ĐỊNH NGHĨA TỪNG STATE
-- ────────────────────────────────────────────────────────────

local States = {}

-- ════════════════════════════════════════════════════════════
--  STATE: IDLE
--  Chuột đứng yên (hoặc rất gần player). Player không di chuyển.
--  Vẫn có thể bị trigger attacking khi click.
-- ════════════════════════════════════════════════════════════
States.idle = {
    name = "idle",

    enter = function(player)
        player._spriteColor = { 0, 0.5, 1 }
        -- Velocity để về 0 dần — Player.lua sẽ lerp velocity
        -- Ở đây ta chỉ đánh dấu state, không cần zero velocity thủ công
    end,

    update = function(player, dt)
        -- Không còn shoot / keyboard input ở đây
        -- Player.lua gọi _processMouseMovement() ở update chính
        -- State chỉ lo logic state-specific
    end,

    exit = function(player) end,

    keypressed  = function(player, key) end,
    keyreleased = function(player, key) end,

    transitions = function(player)
        if player.isDead                            then return "dying" end
        if player._pendingHurt                      then return "hurt"  end
        if player._pendingAttack                    then return "attacking" end

        -- Shift → focusing (dù chuột không di chuyển)
        if isFocusHeld() then return "focusing" end

        -- Chuột xa → moving
        if isMouseMoving(player) then return "moving" end

        return nil
    end,
}

-- ════════════════════════════════════════════════════════════
--  STATE: MOVING
--  Chuột đang kéo player. Di chuyển tốc độ bình thường.
--  expLerp factor = 15 được áp dụng trong Player:_processMouseMovement()
-- ════════════════════════════════════════════════════════════
States.moving = {
    name = "moving",

    enter = function(player)
        player._spriteColor = { 0.1, 0.6, 1 }
        player.isFocused    = false
    end,

    update = function(player, dt)
        -- Di chuyển được xử lý tập trung tại Player:_processMouseMovement(dt)
        -- State này không cần làm gì thêm
    end,

    exit = function(player) end,

    keypressed  = function(player, key) end,
    keyreleased = function(player, key) end,

    transitions = function(player)
        if player.isDead         then return "dying"     end
        if player._pendingHurt   then return "hurt"      end
        if player._pendingAttack then return "attacking" end

        -- Shift → focusing (giảm tốc ngay lập tức)
        if isFocusHeld() then return "focusing" end

        -- Chuột không còn kéo → về idle
        if not isMouseMoving(player) then return "idle" end

        return nil
    end,
}

-- ════════════════════════════════════════════════════════════
--  STATE: FOCUSING
--  Giữ Shift: tốc độ chậm (55% theo player_skills.json focus.speedMult),
--  hitbox dot hiển thị, melee damage tăng + range giảm.
--  Chuột vẫn kéo player — chỉ là chậm hơn.
-- ════════════════════════════════════════════════════════════
States.focusing = {
    name = "focusing",

    -- Timer cho dot pulse và vòng graze rotate
    _rotateAngle = 0,
    _pulseTimer  = 0,

    enter = function(player)
        player._spriteColor = { 0.6, 0.8, 1 }
        player.isFocused    = true
        States.focusing._rotateAngle = 0
        States.focusing._pulseTimer  = 0
    end,

    update = function(player, dt)
        -- Rotate vòng graze
        States.focusing._rotateAngle = States.focusing._rotateAngle + dt * 2.5

        -- Pulse timer cho hitbox dot (dùng Easing.sineInOut nếu muốn)
        States.focusing._pulseTimer = States.focusing._pulseTimer + dt * 3.0
        -- Player:draw() sẽ đọc States.focusing._pulseTimer để vẽ dot

        -- Tốc độ chậm được xử lý trong Player:_processMouseMovement()
        -- bằng cách nhân speed * player.focusSpeedMult khi isFocused = true
    end,

    exit = function(player)
        player.isFocused = false
        States.focusing._pulseTimer = 0
    end,

    keypressed  = function(player, key) end,
    keyreleased = function(player, key) end,

    transitions = function(player)
        if player.isDead         then return "dying"     end
        if player._pendingHurt   then return "hurt"      end
        if player._pendingAttack then return "attacking" end

        -- Nhả Shift → về idle hoặc moving
        if not isFocusHeld() then
            return isMouseMoving(player) and "moving" or "idle"
        end

        return nil
    end,
}

-- ════════════════════════════════════════════════════════════
--  STATE: ATTACKING  ← MỚI
--  Kích hoạt khi player click chuột trái.
--  PlayerAbilities:tryAttack() quyết định melee hay ranged.
--
--  Trong state này:
--    • Player VẪN di chuyển theo chuột (không lock movement)
--      → Giữ cảm giác responsive như Touhou
--    • _attackLock ngắn chặn việc trigger attacking liên tục
--    • Sau khi swing duration kết thúc → về state trước
--
--  Lý do không lock movement:
--    Touhou-style melee cần player tiếp cận target → lock movement
--    sẽ làm player bị kẹt và mất kiểm soát. Di chuyển + đánh
--    cùng lúc là cảm giác đúng.
-- ════════════════════════════════════════════════════════════
States.attacking = {
    name = "attacking",

    -- Timer nội bộ của state (khác với cooldown trong Abilities)
    -- Chỉ dùng để biết khi nào animation swing kết thúc để transition
    _swingTimer    = 0,
    _swingDuration = 0,     -- lấy từ player.abilities sau enter
    _prevState     = "idle", -- state trước để quay lại

    enter = function(player)
        player._spriteColor = { 1, 0.9, 0.2 }    -- vàng khi đang đánh

        -- Lưu state trước để quay lại đúng
        States.attacking._prevState = player._stateMachine
            and player._stateMachine._history[#player._stateMachine._history]
            or "idle"

        -- Reset timer
        States.attacking._swingTimer = 0

        -- Lấy swing duration từ abilities (melee hoặc ranged)
        -- PlayerAbilities sẽ đã gọi tryAttack() trước khi setState("attacking")
        -- _swingDuration = thời gian animation, sau đó state tự thoát
        local ab = player.abilities
        if ab and ab._currentSwingDuration then
            States.attacking._swingDuration = ab._currentSwingDuration
        else
            States.attacking._swingDuration = 0.18  -- fallback từ JSON
        end

        -- Xoá flag pending
        player._pendingAttack = false
    end,

    update = function(player, dt)
        -- Vẫn cho phép di chuyển trong khi đánh
        -- Player:_processMouseMovement(dt) vẫn chạy ở Player:update()

        -- Đếm thời gian swing
        States.attacking._swingTimer = States.attacking._swingTimer + dt
    end,

    exit = function(player)
        player._spriteColor = { 0, 0.5, 1 }  -- reset màu
    end,

    keypressed  = function(player, key) end,
    keyreleased = function(player, key) end,

    transitions = function(player)
        if player.isDead       then return "dying" end
        if player._pendingHurt then return "hurt"  end

        -- Hết animation swing → quay lại state trước
        if States.attacking._swingTimer >= States.attacking._swingDuration then
            -- Chọn state tiếp theo dựa trên context hiện tại
            -- (không revert mù quáng — cần check lại điều kiện)
            if isFocusHeld() then
                return "focusing"
            elseif isMouseMoving(player) then
                return "moving"
            else
                return "idle"
            end
        end

        return nil
    end,
}

-- ════════════════════════════════════════════════════════════
--  STATE: HURT
--  Nhận damage → freeze ngắn, flash đỏ, i-frames bật.
--  Di chuyển bị khoá trong _duration giây.
-- ════════════════════════════════════════════════════════════
States.hurt = {
    name = "hurt",

    _timer    = 0,
    _duration = 0.2,

    enter = function(player)
        player._spriteColor     = { 1, 0.2, 0.2 }
        player._hitboxColor     = { 1, 1,   0   }
        States.hurt._timer      = 0
        player._pendingHurt     = false

        -- Dừng velocity tức thì để có cảm giác "bị đánh bật"
        if player.velocity then
            player.velocity.x = 0
            player.velocity.y = 0
        end
    end,

    update = function(player, dt)
        States.hurt._timer = States.hurt._timer + dt
        -- Không di chuyển trong khi hurt (Player:_processMouseMovement không gọi)
    end,

    exit = function(player)
        player._spriteColor = { 0, 0.5, 1 }
        player._hitboxColor = { 1, 0,   0 }
    end,

    keypressed  = function(player, key) end,
    keyreleased = function(player, key) end,

    transitions = function(player)
        if player.isDead then return "dying" end

        if States.hurt._timer >= States.hurt._duration then
            -- Sau hurt → quyết định state dựa trên context
            if isFocusHeld()          then return "focusing" end
            if isMouseMoving(player)  then return "moving"   end
            return "idle"
        end

        return nil
    end,
}

-- ════════════════════════════════════════════════════════════
--  STATE: DYING
--  Hết mạng, đang play animation chết.
-- ════════════════════════════════════════════════════════════
States.dying = {
    name = "dying",

    _timer    = 0,
    _duration = 1.0,

    enter = function(player)
        player._spriteColor = { 1, 0.5, 0 }
        player:startInvincibility(States.dying._duration or 1.0)
        States.dying._timer = 0

        -- Dừng hẳn movement
        if player.velocity then
            player.velocity.x = 0
            player.velocity.y = 0
        end

        print("[PlayerStates] Dying animation started...")
        -- TODO: Spawn death particles
    end,

    update = function(player, dt)
        States.dying._timer = States.dying._timer + dt
        -- Không cho phép di chuyển hay tấn công
    end,

    exit = function(player) end,

    keypressed  = function(player, key) end,
    keyreleased = function(player, key) end,

    transitions = function(player)
        if States.dying._timer >= States.dying._duration then
            return "dead"
        end
        return nil
    end,
}

-- ════════════════════════════════════════════════════════════
--  STATE: DEAD
--  Game over. Không update nữa.
-- ════════════════════════════════════════════════════════════
States.dead = {
    name = "dead",

    enter = function(player)
        player.isActive  = false
        player.isVisible = false
        player.isDead    = true
        print("[PlayerStates] State: DEAD → Game Over")
        -- TODO: Trigger GameOver event / scene transition
    end,

    update      = function(player, dt) end,
    exit        = function(player) end,
    keypressed  = function(player, key) end,
    keyreleased = function(player, key) end,
    transitions = function(player) return nil end,
}

-- ────────────────────────────────────────────────────────────
--  STATE MACHINE OBJECT
--  Giữ nguyên interface của bản cũ + thêm:
--    • mousepressed(button) relay
--    • mousereleased(button) relay
--    • getRotateAngle() tiện ích cho focusing draw
-- ────────────────────────────────────────────────────────────

local StateMachine = {}
StateMachine.__index = StateMachine

---@param player table  Player instance
---@return table  StateMachine instance
function StateMachine.new(player)
    local sm = setmetatable({}, StateMachine)

    sm.player       = player
    sm.currentState = nil
    sm._stateName   = ""
    sm._history     = {}
    sm._callbacks   = {}

    -- Backref để States.attacking có thể đọc history
    player._stateMachine = sm

    sm:setState("idle")

    return sm
end

-- ── Chuyển state ─────────────────────────────────────────────

---@param name  string
---@param force boolean?
function StateMachine:setState(name, force)
    if not States[name] then
        print("[PlayerStates] WARNING: Unknown state '" .. tostring(name) .. "'")
        return
    end

    if self._stateName == name and not force then return end

    local player = self.player

    -- Exit state cũ
    if self.currentState and self.currentState.exit then
        self.currentState.exit(player)
        self:_fireCallback("onExit", self._stateName)
    end

    -- Lưu lịch sử (tối đa 8)
    if self._stateName ~= "" then
        table.insert(self._history, self._stateName)
        if #self._history > 8 then table.remove(self._history, 1) end
    end

    -- Enter state mới
    self._stateName   = name
    self.currentState = States[name]
    player.state      = name

    if self.currentState.enter then
        self.currentState.enter(player)
    end
    self:_fireCallback("onEnter", name)
end

function StateMachine:revertState()
    if #self._history == 0 then return end
    local prev = table.remove(self._history)
    self:setState(prev, true)
end

-- ── Update ───────────────────────────────────────────────────

---@param dt number
function StateMachine:update(dt)
    if not self.currentState then return end
    local player = self.player

    if self.currentState.update then
        self.currentState.update(player, dt)
    end

    if self.currentState.transitions then
        local next = self.currentState.transitions(player)
        if next then
            self:setState(next)
        end
    end
end

-- ── Input relay ──────────────────────────────────────────────

---@param key string
function StateMachine:keypressed(key)
    if self.currentState and self.currentState.keypressed then
        self.currentState.keypressed(self.player, key)
    end
end

---@param key string
function StateMachine:keyreleased(key)
    if self.currentState and self.currentState.keyreleased then
        self.currentState.keyreleased(self.player, key)
    end
end

---Relay mouse button press vào state hiện tại.
---Gọi từ Player:mousepressed(x, y, button)
---@param button number  1=trái, 2=phải, 3=giữa
function StateMachine:mousepressed(button)
    local player = self.player
    if self.currentState and self.currentState.mousepressed then
        self.currentState.mousepressed(player, button)
    end
end

---Relay mouse button release.
---@param button number
function StateMachine:mousereleased(button)
    local player = self.player
    if self.currentState and self.currentState.mousereleased then
        self.currentState.mousereleased(player, button)
    end
end

-- ── Callback hooks ────────────────────────────────────────────

---Đăng ký callback khi vào/ra state.
---  sm:on("onEnter", "attacking", function(p) camera:shake(2) end)
---  sm:on("onEnter", "hurt",      function(p) soundManager:play("hurt") end)
---@param event     string   "onEnter" | "onExit"
---@param stateName string
---@param fn        function function(player)
function StateMachine:on(event, stateName, fn)
    local key = event .. ":" .. stateName
    if not self._callbacks[key] then self._callbacks[key] = {} end
    table.insert(self._callbacks[key], fn)
end

function StateMachine:_fireCallback(event, stateName)
    local cbs = self._callbacks[event .. ":" .. stateName]
    if not cbs then return end
    for _, fn in ipairs(cbs) do fn(self.player) end
end

-- ── Helpers ──────────────────────────────────────────────────

---@param name string
---@return boolean
function StateMachine:is(name)
    return self._stateName == name
end

---@param ... string
---@return boolean
function StateMachine:isAny(...)
    local cur = self._stateName
    for _, name in ipairs({...}) do
        if cur == name then return true end
    end
    return false
end

---@return string
function StateMachine:getState()
    return self._stateName
end

---@return string
function StateMachine:getHistory()
    return table.concat(self._history, " → ") .. " → " .. self._stateName
end

---Tiện ích cho focusing draw: lấy góc rotate của graze ring.
---@return number radian
function StateMachine:getFocusRotate()
    return States.focusing._rotateAngle or 0
end

---Tiện ích cho focusing draw: lấy pulse timer của hitbox dot.
---@return number
function StateMachine:getFocusPulse()
    return States.focusing._pulseTimer or 0
end

---Tiện ích cho attacking draw: lấy progress swing [0..1].
---@return number
function StateMachine:getAttackProgress()
    local dur = States.attacking._swingDuration
    if dur <= 0 then return 1 end
    return math.min(States.attacking._swingTimer / dur, 1)
end

-- ────────────────────────────────────────────────────────────
--  EXPORT
-- ────────────────────────────────────────────────────────────

--[[
  VÍ DỤ TÍCH HỢP trong Player.lua:

  -- Trong love.mousepressed:
  function Player:mousepressed(x, y, button)
      if button == 1 then   -- click trái
          local attacked = self.abilities:tryAttack()
          if attacked then
              self._pendingAttack = true   -- state machine đọc flag này
          end
      end
  end

  -- Đăng ký callbacks (trong Player:init hoặc GameScene):
  self._stateMachine:on("onEnter", "attacking", function(p)
      -- soundManager:play("swing")
      -- camera:shake(1.5, 0.1)
  end)
  self._stateMachine:on("onEnter", "hurt", function(p)
      -- soundManager:play("hurt")
      -- camera:shake(3, 0.15)
  end)
  self._stateMachine:on("onEnter", "dead", function(p)
      -- sceneManager:push("GameOver")
  end)
--]]

return {
    States       = States,
    StateMachine = StateMachine,
    new          = function(player) return StateMachine.new(player) end,
}
-- src/utils/debug/DebugUI.lua
-- ============================================================
--  DebugUI — Debug overlay kỹ thuật cho combat
--
--  Đặt tại: src/utils/debug/ (cùng Console.lua, DebugDraw.lua, Profiler.lua)
--
--  Phân công rõ ràng, KHÔNG duplicate:
--    Player:drawDebug()  → hitbox circle, graze radius,
--                          velocity vector, melee arc, state label
--    CombatRenderer      → render layers game (boss, bullets, player, HUD)
--    DebugUI (file này)  → thống kê kỹ thuật: FPS, bullet count,
--                          boss HP/phase, player state, hints
--
--  Bật/tắt:
--    F1 → toggle toàn bộ overlay
--    F2 → toggle player:drawDebug() (hitbox, arc, velocity, v.v.)
--    F3 → cycle qua từng section riêng lẻ
--
--  Sử dụng trong BattleScreen:
--    local DebugUI = require 'src.utils.debug.DebugUI'
--    local debugUI = DebugUI()
--    -- update:  debugUI:update(dt)
--    -- draw:    debugUI:draw(cm)       -- sau CombatRenderer:draw()
--    -- input:   debugUI:keypressed(key)
-- ============================================================

local class = require 'libs.middleclass.middleclass'

local DebugUI = class('DebugUI')

-- ────────────────────────────────────────────────────────────
--  CONSTRUCTOR
-- ────────────────────────────────────────────────────────────

function DebugUI:initialize()
    -- Master toggle (F1)
    self.visible = true

    -- Toggle từng section
    self.sections = {
        stats    = true,   -- FPS, bullet count, state
        bossInfo = true,   -- Boss HP, phase, cooldown
        hints    = true,   -- Phím tắt debug
        player   = false,  -- gọi player:drawDebug() (F2)
    }

    -- Vị trí panel (góc trên trái)
    self.x = 10
    self.y = 10

    -- Màu sắc
    self._bg   = { 0,   0,   0,   0.55 }  -- nền panel mờ
    self._fg   = { 1,   1,   1,   1    }  -- text trắng
    self._hi   = { 0.4, 1,   0.6, 1    }  -- xanh highlight (tốt)
    self._warn = { 1,   0.4, 0.2, 1    }  -- cam/đỏ (cảnh báo)
    self._dim  = { 0.6, 0.6, 0.6, 0.8 }  -- xám nhạt (hint)

    -- Line height
    self._lh = 18

    -- FPS smoothing (update mỗi 0.3s)
    self._fps       = 0
    self._fpsTimer  = 0
    self._fpsSample = 0
end

-- ────────────────────────────────────────────────────────────
--  PUBLIC: update
--  BattleScreen:update(dt) gọi để cập nhật FPS counter.
-- ────────────────────────────────────────────────────────────

function DebugUI:update(dt)
    self._fpsSample = self._fpsSample + 1
    self._fpsTimer  = self._fpsTimer + dt
    if self._fpsTimer >= 0.3 then
        self._fps       = math.floor(self._fpsSample / self._fpsTimer)
        self._fpsSample = 0
        self._fpsTimer  = 0
    end
end

-- ────────────────────────────────────────────────────────────
--  PUBLIC: draw
--  Gọi SAU CombatRenderer:draw() trong BattleScreen:draw().
--
--  @param cm  CombatManager
-- ────────────────────────────────────────────────────────────

function DebugUI:draw(cm)
    if not self.visible then return end

    local player = cm:getPlayer()
    local boss   = cm:getBoss()
    local bm     = cm.bulletManager

    -- Layer: player hitbox debug (vẽ trên game world, dưới panel text)
    if self.sections.player and player and player.drawDebug then
        player:drawDebug()
    end

    -- Panel thống kê kỹ thuật
    local lines = self:_buildLines(cm, player, boss, bm)
    self:_drawPanel(lines)
end

-- ────────────────────────────────────────────────────────────
--  PUBLIC: keypressed
--  BattleScreen:keypressed(key) gọi: debugUI:keypressed(key)
-- ────────────────────────────────────────────────────────────

function DebugUI:keypressed(key)
    if key == "f1" then
        -- Bật/tắt toàn bộ overlay
        self.visible = not self.visible

    elseif key == "f2" then
        -- Bật/tắt hitbox debug của player
        self.sections.player = not self.sections.player

    elseif key == "f3" then
        -- Cycle qua từng section
        if self.sections.stats and self.sections.bossInfo and self.sections.hints then
            self.sections.hints    = false
        elseif self.sections.stats and self.sections.bossInfo then
            self.sections.bossInfo = false
        elseif self.sections.stats then
            self.sections.stats    = false
        else
            self.sections.stats    = true
            self.sections.bossInfo = true
            self.sections.hints    = true
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  PRIVATE: _buildLines
--  Thu thập data từ CombatManager → danh sách dòng text.
--  @return { {text, color}, ... }
-- ────────────────────────────────────────────────────────────

function DebugUI:_buildLines(cm, player, boss, bm)
    local lines = {}

    local function line(text, color)
        lines[#lines + 1] = { text = text, color = color or self._fg }
    end

    local function sep()
        line("─────────────────────────", self._dim)
    end

    -- ── Header ──────────────────────────────────────────────
    local fpsColor = self._fps >= 55 and self._hi
                  or self._fps >= 30 and self._fg
                  or self._warn
    line(string.format("[ DEBUG ]  FPS: %3d  |  %s",
        self._fps, cm:getState()), fpsColor)

    -- ── Section: Stats ───────────────────────────────────────
    if self.sections.stats then
        sep()

        -- Bullet count
        local bCount = bm and bm:getCount() or 0
        line(string.format("Bullets  : %d", bCount),
            bCount > 400 and self._warn or self._fg)

        -- Player stats
        if player then
            local st    = player.stateMachine
                      and player.stateMachine:getState() or "?"
            local lives = player.lives       or player.hp or 0
            local bombs = player.bombs       or 0
            local score = player.score       or 0
            local graze = player.grazeCount  or 0
            local focus = player.isFocused   and "ON" or "off"
            local power = player.abilities
                      and player.abilities.powerLevel or 0

            line(string.format("Lives    : %d   Bombs: %d   Power: %d",
                lives, bombs, power))
            line(string.format("Score    : %d   Graze: %d",
                score, graze))
            line(string.format("State    : %-12s Focus: %s", st, focus))
            line(string.format("Pos      : (%.0f, %.0f)",
                player.x, player.y))
        else
            line("Player   : nil", self._warn)
        end
    end

    -- ── Section: Boss Info ───────────────────────────────────
    if self.sections.bossInfo then
        sep()

        if boss and not boss.isDead then
            local phase    = boss.getCurrentPhase
                         and boss:getCurrentPhase() or 1
            local cooldown = boss.attackCooldown or 0
            local timer    = boss.attackTimer    or 0
            local remain   = math.max(0, cooldown - timer)
            local hpPct    = boss.maxHp > 0
                         and math.floor(boss.hp / boss.maxHp * 100) or 0

            local hpColor = hpPct > 66 and self._hi
                         or hpPct > 33 and self._fg
                         or self._warn
            line(string.format("Boss HP  : %d / %d  (%d%%)",
                math.floor(boss.hp), boss.maxHp, hpPct), hpColor)

            local phaseColor = phase == 1 and self._hi
                            or phase == 2 and self._fg
                            or self._warn
            line(string.format("Phase    : %d   AtkIdx: %d",
                phase, boss.currentAttackIndex or 0), phaseColor)

            line(string.format("Next atk : %.2fs / %.1fs  [%s]",
                remain, cooldown, boss.state or "?"), self._dim)

        elseif boss and boss.isDead then
            line("Boss     : DEAD ✓", self._hi)
        else
            line("Boss     : nil", self._dim)
        end
    end

    -- ── Section: Hints ───────────────────────────────────────
    if self.sections.hints then
        sep()
        line("[SPACE]  Drain boss HP (debug)", self._dim)
        line("[SHIFT]  Focus mode",            self._dim)
        line("[F1]     Toggle overlay",         self._dim)
        line("[F2]     Toggle hitbox debug",    self._dim)
        line("[F3]     Cycle sections",         self._dim)
    end

    return lines
end

-- ────────────────────────────────────────────────────────────
--  PRIVATE: _drawPanel
--  Vẽ nền mờ + text cho danh sách dòng.
-- ────────────────────────────────────────────────────────────

function DebugUI:_drawPanel(lines)
    if #lines == 0 then return end

    local lh      = self._lh
    local pad     = 8
    local panelW  = 290
    local panelH  = #lines * lh + pad * 2

    local px = self.x
    local py = self.y

    -- Nền mờ
    love.graphics.setColor(self._bg)
    love.graphics.rectangle("fill",
        px - pad, py - pad, panelW, panelH, 4)

    -- Viền mỏng
    love.graphics.setColor(0.5, 0.5, 0.5, 0.3)
    love.graphics.rectangle("line",
        px - pad, py - pad, panelW, panelH, 4)

    -- Text từng dòng
    for i, entry in ipairs(lines) do
        love.graphics.setColor(entry.color)
        love.graphics.print(entry.text, px, py + (i - 1) * lh)
    end

    -- Reset màu
    love.graphics.setColor(1, 1, 1, 1)
end

return DebugUI
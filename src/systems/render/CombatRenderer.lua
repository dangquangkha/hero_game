-- src/systems/render/CombatRenderer.lua
-- ============================================================
--  CombatRenderer — Render toàn bộ combat scene theo layers
--
--  Vai trò trong kiến trúc:
--    BattleScreen:draw()
--         ↓ gọi
--    CombatRenderer:draw(combatManager)
--         ├── Layer 1: Boss         → boss:draw()
--         ├── Layer 2: Enemies      → enemy:draw()
--         ├── Layer 3: Bullets      → bulletManager:draw()
--         ├── Layer 4: Player       → player:draw()
--         ├── Layer 5: HUD          → player:drawHUD()
--         └── Layer 6: Boss HP bar  → _drawBossBar()
--
--  Nguyên tắc thiết kế:
--    - KHÔNG có logic game — chỉ vẽ
--    - KHÔNG sở hữu entities — nhận qua CombatManager accessor
--    - Thứ tự layer quyết định ai vẽ đè lên ai
--      Boss (dưới) → Bullets (giữa) → Player (trên)
--      → Player luôn thấy hitbox của mình, không bị đạn che
--
--  Player đã tự có drawHUD() và drawDebug() —
--  CombatRenderer chỉ gọi chúng đúng chỗ.
--  DebugUI (file riêng) lo phần thông số kỹ thuật.
-- ============================================================

local class = require 'libs.middleclass.middleclass'

local CombatRenderer = class('CombatRenderer')

-- ────────────────────────────────────────────────────────────
--  CONSTRUCTOR
-- ────────────────────────────────────────────────────────────

function CombatRenderer:initialize()
    -- Bật/tắt từng layer (hữu ích khi debug)
    self.showBoss    = true
    self.showEnemies = true
    self.showBullets = true
    self.showPlayer  = true
    self.showHUD     = true
    self.showBossBar = true

    -- Vị trí HUD của player (góc dưới trái)
    -- Player:drawHUD(x, y) tự tính nếu nil, nhưng để rõ ràng
    self.hudX = 10
    self.hudY = nil   -- nil → Player:drawHUD tự dùng H - 60

    -- Boss HP bar config
    self._bossBar = {
        x      = nil,    -- nil → tự căn giữa màn hình
        y      = 20,
        w      = 400,
        h      = 12,
        padX   = 8,      -- padding text hai bên
    }
end

-- ────────────────────────────────────────────────────────────
--  PUBLIC: draw
--  Hàm chính — BattleScreen:draw() gọi mỗi frame.
--
--  @param cm  CombatManager  — nguồn duy nhất để lấy entities
-- ────────────────────────────────────────────────────────────

function CombatRenderer:draw(cm)
    -- Lấy entities qua accessor (không truy cập field trực tiếp)
    local player = cm:getPlayer()
    local boss   = cm:getBoss()
    local bm     = cm.bulletManager   -- field public, Boss cũng dùng vậy

    -- ── Layer 1: Boss ─────────────────────────────────────────
    -- Vẽ dưới cùng để đạn và player đè lên trên
    if self.showBoss and boss and not boss.isDead then
        boss:draw()
    end

    -- ── Layer 2: Enemies (wave system, dùng sau) ──────────────
    if self.showEnemies then
        local enemies = cm:getEnemies()
        for _, enemy in ipairs(enemies) do
            if not enemy.isDead and enemy.draw then
                enemy:draw()
            end
        end
    end

    -- ── Layer 3: Bullets ──────────────────────────────────────
    -- Vẽ trên boss nhưng dưới player
    -- → Player dễ nhìn hitbox của mình, không bị đạn che lấp
    if self.showBullets and bm then
        bm:draw()
    end

    -- ── Layer 4: Player ───────────────────────────────────────
    -- Luôn vẽ trên cùng để hitbox không bị đạn che
    if self.showPlayer and player and not player.isDead then
        player:draw()
    end

    -- ── Layer 5: HUD (Player's own HUD) ───────────────────────
    -- Lives, Bombs, Power, Score, Graze, Focus, Charge bar
    -- Player:drawHUD() đã được viết sẵn và đầy đủ
    if self.showHUD and player then
        player:drawHUD(self.hudX, self.hudY)
    end

    -- ── Layer 6: Boss HP bar ───────────────────────────────────
    -- Thanh máu boss ở góc trên cùng màn hình
    if self.showBossBar and boss and not boss.isDead then
        self:_drawBossBar(boss)
    end

    -- Reset màu về trắng sau mỗi frame để không leak màu sang frame sau
    love.graphics.setColor(1, 1, 1, 1)
end

-- ────────────────────────────────────────────────────────────
--  PRIVATE: _drawBossBar
--  Thanh máu boss phía trên màn hình.
--  Đổi màu theo phase: xanh (P1) → vàng (P2) → đỏ (P3)
-- ────────────────────────────────────────────────────────────

function CombatRenderer:_drawBossBar(boss)
    local cfg = self._bossBar
    local W   = love.graphics.getWidth()

    -- Căn giữa màn hình nếu x = nil
    local barX = cfg.x or (W * 0.5 - cfg.w * 0.5)
    local barY = cfg.y

    local ratio = math.max(0, boss.hp / boss.maxHp)

    -- Màu bar theo phase
    local phase = boss.getCurrentPhase and boss:getCurrentPhase() or 1
    local barColor
    if phase == 1 then
        barColor = { 0.2, 0.8, 0.3 }   -- xanh lá
    elseif phase == 2 then
        barColor = { 1.0, 0.8, 0.1 }   -- vàng
    else
        barColor = { 1.0, 0.2, 0.2 }   -- đỏ
    end

    -- Nền thanh (xám tối)
    love.graphics.setColor(0.15, 0.15, 0.15, 0.85)
    love.graphics.rectangle("fill", barX, barY, cfg.w, cfg.h, 3)

    -- Phần máu còn lại
    love.graphics.setColor(barColor[1], barColor[2], barColor[3], 0.9)
    love.graphics.rectangle("fill", barX, barY, cfg.w * ratio, cfg.h, 3)

    -- Viền
    love.graphics.setColor(0.8, 0.8, 0.8, 0.5)
    love.graphics.rectangle("line", barX, barY, cfg.w, cfg.h, 3)

    -- Text: "BOSS  1234 / 3000  [Phase 2]"
    love.graphics.setColor(1, 1, 1, 0.9)
    local bossName = boss.class and boss.class.name or "BOSS"
    local hpText   = string.format(
        "%s   %d / %d   [Phase %d]",
        bossName,
        math.floor(boss.hp),
        boss.maxHp,
        phase
    )
    love.graphics.print(hpText, barX, barY + cfg.h + 4)
end

-- ────────────────────────────────────────────────────────────
--  CONTROL — bật/tắt layers khi debug
-- ────────────────────────────────────────────────────────────

---Toggle toàn bộ HUD (khi chụp screenshot gameplay)
function CombatRenderer:toggleHUD()
    self.showHUD     = not self.showHUD
    self.showBossBar = not self.showBossBar
end

---Toggle hitbox debug của player
function CombatRenderer:togglePlayerDebug(player)
    if player and player.drawDebug then
        -- Player:drawDebug() đã có sẵn — gọi thêm sau draw()
        self._showPlayerDebug = not (self._showPlayerDebug or false)
    end
end

return CombatRenderer
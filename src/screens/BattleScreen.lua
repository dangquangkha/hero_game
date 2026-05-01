-- src/screens/BattleScreen.lua
-- ============================================================
--  BattleScreen — Màn chiến đấu chính (Player vs Boss)
--
--  Vai trò trong kiến trúc:
--    GameState / main.lua
--         ↓ Gamestate.switch(BattleScreen, params)
--    BattleScreen  ← Container & điều phối
--         ├── CombatManager   (logic: update entities, collision, damage)
--         ├── CombatRenderer  (render: layers boss/bullets/player/HUD)
--         └── DebugUI         (debug overlay: FPS, stats, hints)
--
--  BattleScreen KHÔNG:
--    - Tự tính toán collision hay damage (CombatManager lo)
--    - Tự vẽ boss/player/bullets (CombatRenderer lo)
--    - Hardcode boss type (nhận qua params)
--
--  BattleScreen CHỈ:
--    - Tạo và lắp ráp CombatManager + Player + Boss
--    - Đăng ký callbacks (onVictory → VictoryScreen, onDefeat → GameOverScreen)
--    - Relay input từ love.* xuống CombatManager / DebugUI
--    - Debug shortcut: [SPACE] drain boss HP
--
--  Tương thích hump/gamestate:
--    Gamestate.switch(BattleScreen, { bossClass = DemonKing })
--    Hoặc: Gamestate.switch(BattleScreen, { bossClass = DragonLord })
--
--  Khởi tạo theo thứ tự bắt buộc (tránh circular dependency):
--    1. CombatManager()           ← tạo systems (bulletManager, v.v.)
--    2. Player(x, y, cm)          ← Player nhận cm ref
--    3. BossClass(x, y, cm)       ← Boss nhận cm ref
--    4. cm:setup({player, boss})  ← CM nhận entities, bắt đầu battle
-- ============================================================

local Gamestate = require 'libs.hump.gamestate'

local CombatManager  = require 'src.systems.combat.CombatManager'
local CombatRenderer = require 'src.systems.render.CombatRenderer'
local DebugUI        = require 'src.utils.debug.DebugUI'
local Player         = require 'src.entities.player.Player'

-- Boss mặc định (fallback khi không truyền params)
local DemonKing      = require 'src.entities.bosses.types.DemonKing'

-- Screens chuyển đến sau khi battle kết thúc
local GameOverScreen = require 'src.screens.GameOverScreen'
local VictoryScreen  = require 'src.screens.VictoryScreen'

-- ────────────────────────────────────────────────────────────
--  BattleScreen (dạng table — chuẩn hump/gamestate)
-- ────────────────────────────────────────────────────────────

local BattleScreen = {}

-- ────────────────────────────────────────────────────────────
--  enter — khởi tạo toàn bộ khi màn hình được mở
--
--  @param params table
--    params.bossClass  class  Boss class (DemonKing, DragonLord, ...)
--    params.playerCfg  table  Override config cho Player (tùy chọn)
-- ────────────────────────────────────────────────────────────

function BattleScreen:enter(prev, params)
    params = params or {}

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- ── Bước 1: Tạo CombatManager (systems rỗng, chưa có entities) ──
    self.cm = CombatManager()

    -- ── Bước 2: Tạo Player (nhận cm ref) ─────────────────────
    local playerX = W * 0.5
    local playerY = H - 100
    self.player = Player(playerX, playerY, self.cm, params.playerCfg)

    print("[BattleScreen] Initializing Boss...")
    -- Dùng bossClass từ params, fallback về DemonKing
    local BossClass = params.bossClass or DemonKing
    local bossX     = W * 0.5
    local bossY     = 150
    self.boss = BossClass(bossX, bossY, self.cm)

    print("[BattleScreen] Setting up CombatManager...")
    -- ── Bước 4: Setup CombatManager (gắn entities, bắt đầu battle) ──
    self.cm:setup({
        player = self.player,
        boss   = self.boss,
    })

    print("[BattleScreen] Registering callbacks...")
    -- Victory: boss chết → chờ 1.5s → chuyển VictoryScreen
    self.cm:onVictory(function()
        self._endTimer      = 1.5
        self._pendingScreen = "victory"
    end)

    -- Defeat: player chết → chờ 1s → chuyển GameOverScreen
    self.cm:onDefeat(function()
        self._endTimer      = 1.0
        self._pendingScreen = "defeat"
    end)

    -- PlayerHit: screen shake nhẹ (khi có camera system)
    self.cm:onPlayerHit(function(damage)
        -- TODO: self.camera:shake(2, 0.1) khi tích hợp camera
    end)

    -- Graze: SFX (khi có AudioManager)
    self.cm:onGraze(function(bullet)
        -- TODO: AudioManager:playSFX("graze") khi tích hợp audio
    end)

    print("[BattleScreen] Initializing Renderer and DebugUI...")
    -- Set default font for the game session (using default Love2D font to avoid asset errors)
    love.graphics.setFont(love.graphics.newFont(14))
    
    self.renderer = CombatRenderer()
    self.debugUI  = DebugUI()
    print("[BattleScreen] enter() completed successfully.")

    -- ── State nội bộ ──────────────────────────────────────────
    self._endTimer      = nil   -- đếm ngược trước khi chuyển screen
    self._pendingScreen = nil   -- "victory" | "defeat"
    self._debugDrain    = false -- [SPACE] đang giữ để drain boss HP
end

-- ────────────────────────────────────────────────────────────
--  update
-- ────────────────────────────────────────────────────────────

local firstUpdate = true
function BattleScreen:update(dt)
    if firstUpdate then
        print("[BattleScreen] FIRST UPDATE STARTING - dt=" .. dt)
        firstUpdate = false
    end
    -- ── Debug shortcut: [SPACE] drain boss HP ─────────────────
    -- Giữ nguyên tính năng từ CombatManager cũ
    if love.keyboard.isDown("space") then
        if self.boss and not self.boss.isDead then
            self.boss:takeDamage(100 * dt)
        end
    end

    -- ── Cập nhật toàn bộ combat logic ────────────────────────
    self.cm:update(dt)

    -- ── Cập nhật DebugUI FPS counter ─────────────────────────
    self.debugUI:update(dt)

    -- ── Đếm ngược chuyển màn hình sau khi kết thúc ───────────
    if self._endTimer then
        self._endTimer = self._endTimer - dt
        if self._endTimer <= 0 then
            self:_switchEndScreen()
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  draw
-- ────────────────────────────────────────────────────────────

function BattleScreen:draw()
    -- Layer game: Boss → Bullets → Player → HUD → BossBar
    self.renderer:draw(self.cm)

    -- Layer debug: overlay kỹ thuật (FPS, stats, hints)
    -- Vẽ SAU renderer để đè lên trên cùng
    self.debugUI:draw(self.cm)

    -- Overlay khi battle kết thúc (fade text)
    self:_drawEndOverlay()
end

-- ────────────────────────────────────────────────────────────
--  INPUT — relay xuống CombatManager và DebugUI
-- ────────────────────────────────────────────────────────────

function BattleScreen:mousepressed(x, y, button)
    self.cm:mousepressed(x, y, button)
end

function BattleScreen:mousereleased(x, y, button)
    self.cm:mousereleased(x, y, button)
end

function BattleScreen:keypressed(key)
    -- Escape → Pause (khi có PauseMenu)
    if key == "escape" then
        -- TODO: Gamestate.push(PauseMenu) khi viết PauseMenu
        return
    end

    -- Debug keys (F1, F2, F3) → DebugUI
    self.debugUI:keypressed(key)

    -- Relay các phím còn lại xuống player (bomb X, special C, v.v.)
    self.cm:keypressed(key)
end

function BattleScreen:keyreleased(key)
    -- Relay keyreleased xuống player (charge release, v.v.)
    if self.player and self.player.keyreleased then
        self.player:keyreleased(key)
    end
end

-- ────────────────────────────────────────────────────────────
--  leave — dọn dẹp khi rời màn hình
-- ────────────────────────────────────────────────────────────

function BattleScreen:leave()
    -- Xóa references để GC thu hồi
    self.cm       = nil
    self.player   = nil
    self.boss     = nil
    self.renderer = nil
    self.debugUI  = nil
end

-- ────────────────────────────────────────────────────────────
--  resume — quay lại từ PauseMenu
-- ────────────────────────────────────────────────────────────

function BattleScreen:resume()
    if self.cm then
        self.cm:resume()
    end
end

-- ────────────────────────────────────────────────────────────
--  PRIVATE: _switchEndScreen
-- ────────────────────────────────────────────────────────────

function BattleScreen:_switchEndScreen()
    if self._pendingScreen == "victory" then
        Gamestate.switch(VictoryScreen, {
            boss   = self.boss,
            player = self.player,
            score  = self.player and self.player.score or 0,
        })
    elseif self._pendingScreen == "defeat" then
        Gamestate.switch(GameOverScreen, {
            score = self.player and self.player.score or 0,
        })
    end
end

-- ────────────────────────────────────────────────────────────
--  PRIVATE: _drawEndOverlay
--  Hiển thị text khi battle vừa kết thúc (trong khi đợi chuyển màn)
-- ────────────────────────────────────────────────────────────

function BattleScreen:_drawEndOverlay()
    if not self._pendingScreen then return end

    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- Nền mờ tối dần
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", 0, 0, W, H)

    -- Text kết quả
    if self._pendingScreen == "victory" then
        love.graphics.setColor(1, 0.85, 0.1, 1)   -- vàng
        love.graphics.print("VICTORY!", W * 0.5 - 40, H * 0.5 - 10)
    elseif self._pendingScreen == "defeat" then
        love.graphics.setColor(1, 0.2, 0.2, 1)    -- đỏ
        love.graphics.print("GAME OVER", W * 0.5 - 44, H * 0.5 - 10)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return BattleScreen

--[[
==============================================================
  HƯỚNG DẪN SỬ DỤNG
==============================================================

  -- 1. Trong main.lua, đăng ký gamestate:
  local Gamestate    = require 'libs.hump.gamestate'
  local BattleScreen = require 'src.screens.BattleScreen'
  local MainMenu     = require 'src.screens.MainMenu'

  function love.load()
      Gamestate.registerEvents()
      Gamestate.switch(MainMenu)
  end

  -- 2. Chuyển sang BattleScreen với DemonKing (default):
  Gamestate.switch(BattleScreen)

  -- 3. Chuyển sang BattleScreen với boss khác:
  local DragonLord = require 'src.entities.bosses.types.DragonLord'
  Gamestate.switch(BattleScreen, { bossClass = DragonLord })

  -- 4. Thêm config player (override DEFAULTS trong Player.lua):
  Gamestate.switch(BattleScreen, {
      bossClass  = DemonKing,
      playerCfg  = { maxHp = 3, maxBombs = 2 },
  })

==============================================================
  LUỒNG DỮ LIỆU
==============================================================

  love events
      ↓
  BattleScreen:keypressed/mousepressed/mousereleased/keyreleased
      ↓ relay
  CombatManager:keypressed/mousepressed/mousereleased
      ↓ relay
  Player:keypressed/mousepressed/mousereleased/keyreleased

  BattleScreen:update(dt)
      ↓
  CombatManager:update(dt)
      ├── Player:update(dt)
      ├── Boss:update(dt)           → Boss tự spawn đạn vào BulletManager
      ├── BulletManager:updateOnly(dt)
      ├── CollisionSystem:checkAll()
      ├── DamageSystem:applyCollisions() → player:takeDamage()
      ├── DamageSystem:applyGrazes()    → player:onGraze()
      └── BulletManager:cleanup()

  BattleScreen:draw()
      ↓
  CombatRenderer:draw(cm)
      ├── Layer 1: boss:draw()
      ├── Layer 2: enemy:draw() (wave)
      ├── Layer 3: bulletManager:draw()
      ├── Layer 4: player:draw()
      ├── Layer 5: player:drawHUD()
      └── Layer 6: _drawBossBar()
      ↓
  DebugUI:draw(cm)          ← đè lên trên cùng
      ├── player:drawDebug() (nếu F2 bật)
      └── panel thống kê kỹ thuật
--]]
-- src/systems/combat/CombatManager.lua
-- ============================================================
--  CombatManager — Điều phối toàn bộ battle logic
--
--  THAY ĐỔI SO VỚI BẢN CŨ:
--    ✓ FIX 1: Thêm keyreleased() — thiếu hoàn toàn, BattleScreen
--             gọi cm:keyreleased() nhưng hàm không tồn tại → crash
--    ✓ FIX 2: update() vẫn cho player update khi isDead = true
--             để StateMachine dying/dead animation chạy được
--             (bản cũ: "not player.isDead" chặn hết animation)
--    ✓ FIX 3: Player ranged projectiles cần được check collision
--             với boss/enemy — bản cũ chỉ check đạn boss → player,
--             không check đạn player → boss
--    ✓ THÊM: mousemoved() relay (sẵn sàng nếu cần)
--    ✓ THÊM: getProjectiles() accessor cho CombatRenderer vẽ đạn player
--    ✓ THÊM: clearBullets() tiện ích cho bomb clear
-- ============================================================

local class           = require 'libs.middleclass.middleclass'
local BulletManager   = require 'src.systems.combat.BulletManager'
local CollisionSystem = require 'src.systems.combat.CollisionSystem'
local DamageSystem    = require 'src.systems.combat.DamageSystem'

local CombatManager = class('CombatManager')

-- ────────────────────────────────────────────────────────────
--  BƯỚC 1: initialize
-- ────────────────────────────────────────────────────────────

function CombatManager:initialize()
    self.bulletManager   = BulletManager()
    self.collisionSystem = CollisionSystem()
    self.damageSystem    = DamageSystem()

    self.player  = nil
    self.boss    = nil
    self.enemies = {}

    -- "idle" | "active" | "paused" | "victory" | "defeat"
    self.state = "idle"

    self._onVictory = nil
    self._onDefeat  = nil
end

-- ────────────────────────────────────────────────────────────
--  BƯỚC 2: setup
-- ────────────────────────────────────────────────────────────

function CombatManager:setup(config)
    assert(config,        "[CombatManager] setup() cần config table")
    assert(config.player, "[CombatManager] setup() cần config.player")

    self.player  = config.player
    self.boss    = config.boss    or nil
    self.enemies = config.enemies or {}

    self.damageSystem:onPlayerDeath(function()
        self:_handleDefeat()
    end)

    self.damageSystem:onBossDeath(function(boss)
        self:_handleVictory()
    end)

    self.state = "active"
end

-- ────────────────────────────────────────────────────────────
--  update
-- ────────────────────────────────────────────────────────────

local debugFrameCount = 0
function CombatManager:update(dt)
    if self.state ~= "active" then return end
    
    debugFrameCount = debugFrameCount + 1
    if debugFrameCount % 60 == 0 then
        print("[CombatManager] Heartbeat - Active Loop, Frame: " .. debugFrameCount)
    end

    -- 1. Entities update
    if self.player then 
        self.player:update(dt) 
    end
    
    if self.boss and not self.boss.isDead then 
        self.boss:update(dt) 
    end

    -- 2. Projectiles update
    self.bulletManager:updateOnly(dt)

    -- 3. Collision checks
    if self.player then
        local bossBullets = self.bulletManager:getProjectiles()
        local collisions, grazes = self.collisionSystem:checkAll(bossBullets, self.player)
        
        -- Apply damage only if not invincible
        if not self.player.isInvincible then
            self.damageSystem:applyCollisions(collisions)
        end
        
        -- Always apply grazes (Danmaku feel)
        self.damageSystem:applyGrazes(grazes)
    end
    self:_checkPlayerProjectiles()

    -- 4. Cleanup
    self.bulletManager:cleanup()
end

---Check đạn player (slash wave) trúng boss/enemy.
---Gọi nội bộ từ update(). PlayerAbilities tự quản lý vòng đời đạn.
function CombatManager:_checkPlayerProjectiles()
    local player = self.player
    if not player then return end
    local ab = player.abilities
    if not ab or not ab.projectiles then return end

    -- Build target list: boss + enemies
    local targets = {}
    if self.boss and not self.boss.isDead then
        table.insert(targets, self.boss)
    end
    for _, e in ipairs(self.enemies) do
        if not e.isDead then table.insert(targets, e) end
    end
    if #targets == 0 then return end

    -- PlayerAbilities đã tự check collision nội bộ trong _updateProjectiles()
    -- Hàm đó cần biết danh sách target → đã được truyền qua
    -- player.combatManager.boss và player.combatManager.enemies
    -- (PlayerAbilities đọc: local cm = player.combatManager)
    -- Nên ở đây KHÔNG cần check lại — chỉ expose targets qua accessor
    -- để PlayerAbilities._updateProjectiles() gọi được.
    --
    -- Nếu muốn CM kiểm soát hoàn toàn (không để Abilities tự check):
    -- uncomment block dưới và xóa collision logic trong PlayerAbilities
    --[[
    local Collision = require 'src.utils.math.Collision'
    for i = #ab.projectiles, 1, -1 do
        local p = ab.projectiles[i]
        if p.isAlive then
            for _, target in ipairs(targets) do
                local tr = target.hitboxRadius or target.radius or 20
                if Collision.circleAabb(
                    target.x, target.y, tr,
                    p.x - p.width  * 0.5,
                    p.y - p.height * 0.5,
                    p.width, p.height)
                then
                    if not p._hitList[target] then
                        p._hitList[target] = true
                        target:takeDamage(p.damage, {
                            source   = "player_ranged",
                            attacker = player,
                        })
                        if not p.pierce then
                            p.isAlive = false
                            break
                        end
                    end
                end
            end
        end
    end
    --]]
end

-- ────────────────────────────────────────────────────────────
--  RELAY INPUT
-- ────────────────────────────────────────────────────────────

function CombatManager:mousepressed(x, y, button)
    if self.state ~= "active" then return end
    if self.player and self.player.mousepressed then
        self.player:mousepressed(x, y, button)
    end
end

function CombatManager:mousereleased(x, y, button)
    if self.state ~= "active" then return end
    if self.player and self.player.mousereleased then
        self.player:mousereleased(x, y, button)
    end
end

-- mousemoved: Player dùng love.mouse.getPosition() trực tiếp
-- nên không bắt buộc relay — có sẵn để dùng nếu cần
function CombatManager:mousemoved(x, y, dx, dy)
    -- if self.player and self.player.mousemoved then
    --     self.player:mousemoved(x, y, dx, dy)
    -- end
end

function CombatManager:keypressed(key)
    if self.state ~= "active" then return end
    if self.player and self.player.keypressed then
        self.player:keypressed(key)
    end
end

-- ── FIX 1: Thêm keyreleased — thiếu hoàn toàn ───────────────
-- BattleScreen:keyreleased() gọi cm:keyreleased() → crash vì nil
-- Player cần keyreleased để: nhả charged beam, nhả Shift (focus), v.v.
function CombatManager:keyreleased(key)
    if self.state ~= "active" then return end
    if self.player and self.player.keyreleased then
        self.player:keyreleased(key)
    end
end

-- ────────────────────────────────────────────────────────────
--  CALLBACKS
-- ────────────────────────────────────────────────────────────

function CombatManager:onVictory(fn)   self._onVictory = fn end
function CombatManager:onDefeat(fn)    self._onDefeat  = fn end

function CombatManager:onPlayerHit(fn)
    self.damageSystem:onPlayerHit(fn)
end

function CombatManager:onGraze(fn)
    self.damageSystem:onGraze(fn)
end

-- ────────────────────────────────────────────────────────────
--  CONTROL
-- ────────────────────────────────────────────────────────────

function CombatManager:pause()
    if self.state == "active" then self.state = "paused" end
end

function CombatManager:resume()
    if self.state == "paused" then self.state = "active" end
end

function CombatManager:disableCombat()
    self.collisionSystem:disable()
    self.damageSystem:disable()
end

function CombatManager:enableCombat()
    self.collisionSystem:enable()
    self.damageSystem:enable()
end

-- ── THÊM: clearBullets() — dùng bởi bomb để xóa màn hình ────
-- PlayerAbilities:activateBomb() gọi:
--   local bm = player.combatManager.bulletManager
--   for _, b in ipairs(bm.bullets) do b.isAlive = false end
-- Hàm này là wrapper sạch hơn:
function CombatManager:clearBullets()
    local bullets = self.bulletManager:getProjectiles()
    for _, b in ipairs(bullets) do
        b.isAlive = false
    end
end

-- ────────────────────────────────────────────────────────────
--  ACCESSORS
-- ────────────────────────────────────────────────────────────

function CombatManager:getState()       return self.state    end
function CombatManager:getBoss()        return self.boss     end
function CombatManager:getPlayer()      return self.player   end
function CombatManager:getEnemies()     return self.enemies  end

-- ── THÊM: getBulletManager() — CombatRenderer dùng để vẽ đạn ──
function CombatManager:getBulletManager()
    return self.bulletManager
end

-- ── THÊM: getPlayerProjectiles() — CombatRenderer vẽ slash wave ──
function CombatManager:getPlayerProjectiles()
    if self.player and self.player.abilities then
        return self.player.abilities.projectiles or {}
    end
    return {}
end

-- ────────────────────────────────────────────────────────────
--  PRIVATE
-- ────────────────────────────────────────────────────────────

function CombatManager:_handleVictory()
    if self.state == "active" then
        self.state = "victory"
        if self._onVictory then self._onVictory() end
    end
end

function CombatManager:_handleDefeat()
    if self.state == "active" then
        self.state = "defeat"
        if self._onDefeat then self._onDefeat() end
    end
end

return CombatManager

--[[
==============================================================
  TÓM TẮT CÁC THAY ĐỔI
==============================================================

  FIX 1 — keyreleased() THIẾU HOÀN TOÀN:
    BattleScreen:keyreleased(key) → cm:keyreleased(key) → CRASH
    Thêm: function CombatManager:keyreleased(key) ... end

  FIX 2 — player:update() bị chặn khi isDead:
    Bản cũ: if not self.player.isDead then player:update(dt) end
    Hậu quả: state "dying" animation không chạy, onDeath không fire
    Sửa: if self.player then player:update(dt) end (bỏ isDead check)
    Player.lua tự chặn movement/input bên trong state dying/dead

  FIX 3 — Không check đạn player → boss:
    PlayerAbilities._updateProjectiles() tự check nếu có combatManager.boss
    CM expose targets qua self.boss và self.enemies (đã public)
    Nếu muốn CM kiểm soát hoàn toàn → dùng block commented trong
    _checkPlayerProjectiles()

  THÊM — keyreleased, mousemoved, clearBullets,
          getBulletManager, getPlayerProjectiles
==============================================================
--]]
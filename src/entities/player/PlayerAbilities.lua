-- src/entities/player/PlayerAbilities.lua
-- ============================================================
--  PlayerAbilities — Hệ thống kỹ năng Player (Mouse-driven)
--
--  THAY ĐỔI SO VỚI BẢN CŨ:
--    ✕ Xoá hoàn toàn shoot system (newBullet, _updateBullets,
--      POWER_LEVELS pattern bắn đạn, fireTimer, bullets array)
--    ✓ Thêm MeleeAttack: click trái → swing arc → hit targets
--    ✓ Thêm RangedAttack: điều kiện (power ≥ 3, không có melee target)
--    ✓ Thêm ChargedBeam: điều kiện (power = 4 + Focus + hold)
--    ✓ Combo system: power level 3+ mở 2-hit, power 4 mở 3-hit
--    ✓ Skill data load từ player_skills.json
--    ✓ Collision.meleeTargets() cho arc hit check
--    ✓ Easing.lua cho swing animation + trail fade
--    ✓ Giữ nguyên: Bomb, Trail, Power system, Special slot
-- ============================================================

local Collision = require 'src.utils.math.Collision'
local Easing    = require 'src.utils.math.Easing'

-- ────────────────────────────────────────────────────────────
--  LOAD SKILL DATA từ player_skills.json
--  Fallback về hardcode nếu file không tìm thấy
-- ────────────────────────────────────────────────────────────

local SkillData = nil

local function loadSkillData()
    -- Thử load JSON
    local ok, data = pcall(function()
        local json = require 'libs.json'   -- löve2d thường dùng rxi/json.lua
        local content = love.filesystem.read('assets/data/skills/player_skills.json')
        return json.decode(content)
    end)

    if ok and data then
        print("[PlayerAbilities] Loaded player_skills.json OK")
        return data
    else
        print("[PlayerAbilities] WARNING: Cannot load player_skills.json, using defaults")
        -- Hardcode fallback (mirror JSON)
        return {
            melee = {
                base = {
                    damage      = { base = 35, focusBonus = 15 },
                    cooldown    = 0.35,
                    hitbox      = {
                        range      = 64,
                        arcHalfRad = 1.1344,
                    },
                    swing_animation = {
                        duration   = 0.18,
                        startAngle = -0.9,
                        endAngle   =  0.9,
                        easing     = "quadOut",
                        arcColor   = { 0.4, 0.9, 1.0 },
                        arcAlpha   = 0.55,
                        lineWidth  = 2.5,
                    },
                    impact_effect = {
                        flashDuration  = 0.08,
                        hitStopFrames  = 2,
                    },
                    focus_modifier = {
                        rangeMult      = 0.75,
                        arcHalfRad     = 0.6981,
                        cooldownMult   = 0.8,
                        swingDuration  = 0.14,
                        arcColor       = { 1.0, 0.85, 0.2 },
                        arcAlpha       = 0.7,
                    },
                },
                power_scaling = {
                    ["1"] = { damageMult=1.0,  cooldown=0.38, rangeMult=1.0,  comboEnabled=false },
                    ["2"] = { damageMult=1.25, cooldown=0.32, rangeMult=1.1,  comboEnabled=false },
                    ["3"] = { damageMult=1.55, cooldown=0.27, rangeMult=1.2,  comboEnabled=true,
                        combo = { maxHits=2, comboWindow=0.45,
                            hit2 = { damageMult=0.8, arcHalfRad=1.3963, swingDir="opposite" } } },
                    ["4"] = { damageMult=2.0,  cooldown=0.22, rangeMult=1.35, comboEnabled=true,
                        combo = { maxHits=3, comboWindow=0.5,
                            hit2 = { damageMult=0.85, arcHalfRad=1.3090, swingDir="opposite" },
                            hit3 = { damageMult=1.3,  arcHalfRad=3.1416, hitbox_shape="circle",
                                     rangeMult=1.2, swingDuration=0.25, easing="sineOut",
                                     arcColor={0.8,0.4,1.0}, arcAlpha=0.8 } } },
                },
            },
            ranged = {
                slash_wave = {
                    condition  = { type="power_level", minLevel=3, fallback="melee_base" },
                    priority   = 10,
                    projectile = { speed=520, lifetime=0.55, damage=22, pierce=true,
                                   color={0.4,0.9,1.0}, glowRadius=8, width=48, height=14 },
                    fire       = { cooldown=0.55, direction="mouse_angle" },
                },
                charged_beam = {
                    condition  = { type="power_level", minLevel=4, extraCond="focus_mode",
                                   fallback="slash_wave" },
                    priority   = 20,
                    charge     = { minTime=0.4, maxTime=1.2 },
                    projectile = { damage=80, lifetime=0.18, length=500, color={1.0,0.9,0.3},
                                   coreColor={1,1,1}, glowRadius=20 },
                    fire       = { cooldown=1.2, direction="mouse_angle" },
                },
            },
            bomb = {
                base = {
                    maxStock=3, duration=2.0, damagePerSec=200, iframes=2.2,
                    visual = { flashAlphaMax=0.35, ringColor={0.6,0.9,1.0},
                               ringLineWidth=3, waveInterval=0.15 },
                },
            },
            trail = {
                base = {
                    sampleInterval=0.04, maxSamples=8,
                    alphaStart=0.5, fadeMult=2.5,
                    color={0.0,0.4,0.9}, alphaFactor=0.6,
                },
            },
            focus = {
                speedMult=0.55, showHitboxDot=true,
                dotColor={1,1,1}, dotRadius=2.5, dotPulseSpeed=3.0,
            },
            graze = {
                radius=28, pointsPerGraze=10, cooldownPerBullet=0.25,
                visual = { ringColor={0.4,0.8,1.0}, ringAlphaMax=0.6,
                           ringExpandMult=1.6, expandDuration=0.5 },
            },
        }
    end
end

-- ────────────────────────────────────────────────────────────
--  PROJECTILE FACTORY (cho ranged slash wave)
-- ────────────────────────────────────────────────────────────

local function newProjectile(x, y, angle, cfg)
    local speed = cfg.speed or 520
    return {
        x        = x,
        y        = y,
        vx       = math.cos(angle) * speed,
        vy       = math.sin(angle) * speed,
        width    = cfg.width    or 48,
        height   = cfg.height   or 14,
        angle    = angle,
        damage   = cfg.damage   or 22,
        pierce   = cfg.pierce   or false,
        lifetime = cfg.lifetime or 0.55,
        _age     = 0,
        color    = cfg.color    or { 0.4, 0.9, 1.0 },
        glowRadius = cfg.glowRadius or 8,
        isAlive  = true,
        _hitList = {},   -- entities đã hit (pierce guard)
    }
end

-- ────────────────────────────────────────────────────────────
--  POWER LEVEL: chỉ còn ảnh hưởng melee scaling + ranged unlock
--  (Không còn shot pattern)
-- ────────────────────────────────────────────────────────────
local MAX_POWER = 4

-- ────────────────────────────────────────────────────────────
--  ABILITIES OBJECT
-- ────────────────────────────────────────────────────────────

local PlayerAbilities = {}
PlayerAbilities.__index = PlayerAbilities

---@param player table  Player instance
---@return table  PlayerAbilities instance
function PlayerAbilities.new(player)
    local ab = setmetatable({}, PlayerAbilities)

    ab.player     = player
    SkillData     = SkillData or loadSkillData()
    ab._skillData = SkillData

    -- ── Power level ───────────────────────────────────────────
    ab.powerLevel = 1

    -- ── Melee state ───────────────────────────────────────────
    ab._meleeCooldown    = 0          -- countdown đến lần đánh tiếp theo
    ab._swingTimer       = 0          -- timer animation swing hiện tại
    ab._swingActive      = false      -- đang trong animation swing
    ab._swingDuration    = 0          -- duration swing hiện tại (lấy từ JSON)
    ab._swingStartAngle  = 0          -- góc bắt đầu swing (relative to attackAngle)
    ab._swingEndAngle    = 0          -- góc kết thúc swing
    ab._swingEasingFn    = nil        -- hàm easing cho swing arc
    ab._swingArcColor    = { 0.4, 0.9, 1.0 }
    ab._swingArcAlpha    = 0.55
    ab._swingLineWidth   = 2.5
    ab._attackAngle      = 0          -- hướng đánh (mouse angle)
    ab._currentSwingDuration = 0      -- được đọc bởi PlayerStates.attacking

    -- Combo state
    ab._comboHit         = 0          -- hit hiện tại trong combo (0 = chưa đánh)
    ab._comboWindowTimer = 0          -- đếm ngược cửa sổ combo
    ab._comboDir         = 1          -- +1 hoặc -1 (đổi chiều mỗi hit)

    -- Impact effect
    ab._impactFlashTimer = 0
    ab._impactFlashDuration = 0
    ab._hitStopTimer     = 0
    ab._hitStopDuration  = 0

    -- ── Ranged state ──────────────────────────────────────────
    ab.projectiles       = {}         -- slash wave projectiles
    ab._rangedCooldown   = 0

    -- Charged beam state
    ab._chargeTimer      = 0          -- thời gian đang giữ charge
    ab._isCharging       = false
    ab._chargeRatio      = 0          -- [0..1] mức charge
    ab._beamFlashTimer   = 0
    ab._beamActive       = false
    ab._beamTimer        = 0
    ab._beamAngle        = 0
    ab._beamLifetime     = 0

    -- ── Bomb ──────────────────────────────────────────────────
    local bombCfg          = SkillData.bomb.base
    ab._bombActive         = false
    ab._bombTimer          = 0
    ab._bombDuration       = bombCfg.duration       or 2.0
    ab._bombDamageRate     = bombCfg.damagePerSec   or 200
    ab._bombWaveTimer      = 0
    ab._bombWaveInterval   = bombCfg.visual.waveInterval or 0.15
    ab._bombIframes        = bombCfg.iframes        or 2.2
    ab.bombStock           = bombCfg.maxStock       or 3

    -- ── Trail / After-image ───────────────────────────────────
    local trailCfg         = SkillData.trail.base
    ab._trail              = {}
    ab._trailTimer         = 0
    ab._trailInterval      = trailCfg.sampleInterval or 0.04
    ab._trailMaxSamples    = trailCfg.maxSamples     or 8
    ab._trailFadeMult      = trailCfg.fadeMult       or 2.5
    ab._trailAlphaStart    = trailCfg.alphaStart     or 0.5
    ab._trailColor         = trailCfg.color          or { 0, 0.4, 0.9 }
    ab._trailAlphaFactor   = trailCfg.alphaFactor    or 0.6

    -- ── Special ability slot ──────────────────────────────────
    ab.specialAbility      = nil

    return ab
end

-- ────────────────────────────────────────────────────────────
--  UPDATE
-- ────────────────────────────────────────────────────────────

---@param dt number
function PlayerAbilities:update(dt)
    local player = self.player

    -- Hit-stop: đóng băng mọi thứ N frame
    if self._hitStopTimer > 0 then
        self._hitStopTimer = self._hitStopTimer - dt
        return   -- bỏ qua toàn bộ update khi hit-stop
    end

    -- ── Cooldowns ──────────────────────────────────────────────
    if self._meleeCooldown   > 0 then self._meleeCooldown  = math.max(0, self._meleeCooldown  - dt) end
    if self._rangedCooldown  > 0 then self._rangedCooldown = math.max(0, self._rangedCooldown - dt) end

    -- ── Combo window countdown ────────────────────────────────
    if self._comboWindowTimer > 0 then
        self._comboWindowTimer = self._comboWindowTimer - dt
        if self._comboWindowTimer <= 0 then
            -- Hết cửa sổ combo → reset
            self._comboHit = 0
            self._comboDir = 1
        end
    end

    -- ── Swing animation timer ──────────────────────────────────
    if self._swingActive then
        self._swingTimer = self._swingTimer + dt
        if self._swingTimer >= self._swingDuration then
            self._swingActive = false
            self._swingTimer  = self._swingDuration
        end
    end

    -- ── Impact flash ──────────────────────────────────────────
    if self._impactFlashTimer > 0 then
        self._impactFlashTimer = math.max(0, self._impactFlashTimer - dt)
    end

    -- ── Charged beam ──────────────────────────────────────────
    if self._isCharging then
        self:_updateCharge(dt)
    end
    if self._beamActive then
        self:_updateBeam(dt)
    end

    -- ── Ranged projectiles ────────────────────────────────────
    self:_updateProjectiles(dt)

    -- ── Bomb ──────────────────────────────────────────────────
    if self._bombActive then
        self:_updateBomb(dt)
    end

    -- ── Trail ─────────────────────────────────────────────────
    self._trailTimer = self._trailTimer + dt
    if self._trailTimer >= self._trailInterval then
        self._trailTimer = 0
        self:_sampleTrail()
    end
    self:_updateTrail(dt)

    -- ── Special ability ───────────────────────────────────────
    if self.specialAbility and self.specialAbility.update then
        self.specialAbility:update(player, dt)
    end
end

-- ────────────────────────────────────────────────────────────
--  ENTRY POINT: tryAttack()
--  Gọi từ Player:mousepressed(1). Quyết định:
--    1. Charged beam (hold) → bắt đầu charge nếu đủ điều kiện
--    2. Ranged slash wave   → nếu đủ điều kiện + không có melee target
--    3. Melee               → mặc định
--  Trả về true nếu attack được kích hoạt (để state machine biết)
-- ────────────────────────────────────────────────────────────

---Gọi khi click chuột trái xuống.
---@return boolean  true nếu attack được kích hoạt
function PlayerAbilities:tryAttack()
    local player = self.player
    if player.isDead then return false end

    -- ── Ưu tiên cao nhất: Charged beam (cần giữ, không phải click) ──
    -- Charged beam bắt đầu charge ở mousedown, bắn khi mouseup
    -- → Xử lý ở startCharge() / releaseCharge() riêng biệt

    -- ── Kiểm tra combo window ─────────────────────────────────
    local scaling    = self:_getScaling()
    local canCombo   = scaling.comboEnabled
                    and self._comboHit > 0
                    and self._comboWindowTimer > 0

    if canCombo then
        return self:_doComboHit(scaling)
    end

    -- ── Cooldown check ────────────────────────────────────────
    if self._meleeCooldown > 0 and self._rangedCooldown > 0 then
        return false
    end

    -- ── Lấy góc tấn công (player → chuột) ────────────────────
    local mx, my    = love.mouse.getPosition()
    local angle     = math.atan2(my - player.y, mx - player.x)

    -- ── Kiểm tra có melee target trong range không ────────────
    local meleeTargets = self:_getMeleeTargets(angle)
    local hasMeleeTarget = #meleeTargets > 0

    -- ── Quyết định melee hay ranged ───────────────────────────
    if hasMeleeTarget or not self:_canUseRanged() then
        -- Melee
        if self._meleeCooldown > 0 then return false end
        return self:_doMeleeAttack(angle, scaling, meleeTargets)
    else
        -- Ranged (slash wave)
        if self._rangedCooldown > 0 then return false end
        return self:_doRangedAttack(angle)
    end
end

---Gọi khi giữ chuột trái (charged beam).
function PlayerAbilities:startCharge()
    if not self:_canUseChargedBeam() then return end
    if self._isCharging then return end
    self._isCharging  = true
    self._chargeTimer = 0
    self._chargeRatio = 0
    local mx, my = love.mouse.getPosition()
    self._beamAngle = math.atan2(my - self.player.y, mx - self.player.x)
end

---Gọi khi nhả chuột trái (bắn charged beam).
---@return boolean  true nếu bắn được
function PlayerAbilities:releaseCharge()
    if not self._isCharging then return false end
    self._isCharging = false

    local chargeCfg = self._skillData.ranged.charged_beam.charge
    if self._chargeTimer < (chargeCfg.minTime or 0.4) then
        self._chargeTimer = 0
        self._chargeRatio = 0
        return false   -- charge chưa đủ → hủy
    end

    return self:_fireBeam()
end

-- ────────────────────────────────────────────────────────────
--  MELEE INTERNALS
-- ────────────────────────────────────────────────────────────

function PlayerAbilities:_getScaling()
    local lvlKey  = tostring(self.powerLevel)
    local scaling = self._skillData.melee.power_scaling[lvlKey]
    return scaling or self._skillData.melee.power_scaling["1"]
end

function PlayerAbilities:_getMeleeTargets(angle)
    local player  = self.player
    local base    = self._skillData.melee.base
    local scaling = self:_getScaling()
    local focus   = self._skillData.melee.base.focus_modifier

    local range   = base.hitbox.range * (scaling.rangeMult or 1.0)
    local arcHalf = base.hitbox.arcHalfRad

    if player.isFocused then
        range   = range   * (focus.rangeMult or 0.75)
        arcHalf = focus.arcHalfRad or arcHalf
    end

    -- Lấy danh sách enemy + boss từ combatManager
    local cm      = player.combatManager
    local targets = {}
    if cm then
        if cm.enemies then
            for _, e in ipairs(cm.enemies) do table.insert(targets, e) end
        end
        if cm.boss and not cm.boss.isDead then
            table.insert(targets, cm.boss)
        end
    end

    return Collision.meleeTargets(
        player.x, player.y,
        angle, arcHalf, range,
        targets
    )
end

---Thực hiện melee hit 1 (hoặc hit đầu trong combo).
---@param angle   number
---@param scaling table
---@param targets table  Đã được Collision.meleeTargets() lọc + sort
---@return boolean
function PlayerAbilities:_doMeleeAttack(angle, scaling, targets)
    local player = self.player
    local base   = self._skillData.melee.base
    local focus  = base.focus_modifier

    -- ── Tính damage ───────────────────────────────────────────
    local dmgBase  = base.damage.base * (scaling.damageMult or 1.0)
    local dmg      = player.isFocused and (dmgBase + base.damage.focusBonus) or dmgBase

    -- ── Apply damage lên tất cả target trong arc ──────────────
    local didHit = false
    for _, hit in ipairs(targets) do
        hit.entity:takeDamage(dmg, { source = "melee", attacker = player })
        didHit = true
    end

    -- ── Cooldown ──────────────────────────────────────────────
    local cd = scaling.cooldown or base.cooldown
    if player.isFocused then cd = cd * (focus.cooldownMult or 0.8) end
    self._meleeCooldown = cd

    -- ── Bắt đầu swing animation ───────────────────────────────
    local animCfg = base.swing_animation
    local swingDur = player.isFocused and focus.swingDuration or animCfg.duration

    self:_startSwingAnim(angle, {
        duration   = swingDur,
        startAngle = animCfg.startAngle,
        endAngle   = animCfg.endAngle,
        easing     = animCfg.easing,
        arcColor   = player.isFocused and focus.arcColor or animCfg.arcColor,
        arcAlpha   = player.isFocused and focus.arcAlpha or animCfg.arcAlpha,
        lineWidth  = animCfg.lineWidth or 2.5,
    })

    -- ── Impact effect ──────────────────────────────────────────
    if didHit then
        local imp = base.impact_effect
        self._impactFlashTimer    = imp.flashDuration   or 0.08
        self._impactFlashDuration = imp.flashDuration   or 0.08
        -- Hit-stop: đóng băng update
        local fps   = love.timer.getFPS()
        if fps > 0 then
            self._hitStopTimer    = (imp.hitStopFrames or 2) / fps
        end
    end

    -- ── Combo setup ───────────────────────────────────────────
    if scaling.comboEnabled then
        self._comboHit         = 1
        self._comboWindowTimer = scaling.combo and scaling.combo.comboWindow or 0.45
        self._comboDir         = 1
    end

    return true
end

---Combo hit 2 hoặc hit 3.
---@param scaling table
---@return boolean
function PlayerAbilities:_doComboHit(scaling)
    local player = self.player
    local base   = self._skillData.melee.base
    local combo  = scaling.combo

    local nextHit = self._comboHit + 1
    local hitCfg  = combo["hit" .. nextHit]
    if not hitCfg then
        -- Không còn hit trong combo → reset
        self._comboHit         = 0
        self._comboWindowTimer = 0
        return false
    end

    -- ── Góc tấn công: đổi chiều nếu swingDir = "opposite" ────
    local mx, my = love.mouse.getPosition()
    local angle  = math.atan2(my - player.y, mx - player.x)
    if hitCfg.swingDir == "opposite" then
        self._comboDir = -self._comboDir
    end

    -- ── Damage ────────────────────────────────────────────────
    local dmgBase = base.damage.base * (scaling.damageMult or 1.0) * (hitCfg.damageMult or 1.0)
    local dmg     = player.isFocused and (dmgBase + base.damage.focusBonus) or dmgBase

    -- ── Lấy targets trong arc combo ───────────────────────────
    local arcHalf  = hitCfg.arcHalfRad  or base.hitbox.arcHalfRad
    local range    = base.hitbox.range  * (scaling.rangeMult or 1.0) * (hitCfg.rangeMult or 1.0)

    local cm = player.combatManager
    local allTargets = {}
    if cm then
        if cm.enemies then for _, e in ipairs(cm.enemies) do table.insert(allTargets, e) end end
        if cm.boss and not cm.boss.isDead then table.insert(allTargets, cm.boss) end
    end

    -- Hit 3 (finisher) dùng full circle → không cần arc check
    local hitTargets
    if hitCfg.hitbox_shape == "circle" then
        hitTargets = Collision.inRadius(player.x, player.y, range, allTargets)
        -- Wrap thành cùng format với meleeTargets
        local wrapped = {}
        for _, e in ipairs(hitTargets) do
            table.insert(wrapped, { entity = e, distSq = 0 })
        end
        hitTargets = wrapped
    else
        hitTargets = Collision.meleeTargets(
            player.x, player.y,
            angle, arcHalf, range,
            allTargets
        )
    end

    local didHit = false
    for _, hit in ipairs(hitTargets) do
        hit.entity:takeDamage(dmg, { source = "melee_combo", attacker = player })
        didHit = true
    end

    -- ── Swing animation ───────────────────────────────────────
    local swingDur   = hitCfg.swingDuration or base.swing_animation.duration
    local easingName = hitCfg.easing        or base.swing_animation.easing
    local arcColor   = hitCfg.arcColor      or base.swing_animation.arcColor
    local arcAlpha   = hitCfg.arcAlpha      or base.swing_animation.arcAlpha

    -- Swing ngược chiều cho "opposite"
    local startA = base.swing_animation.startAngle * self._comboDir
    local endA   = base.swing_animation.endAngle   * self._comboDir

    self:_startSwingAnim(angle, {
        duration   = swingDur,
        startAngle = startA,
        endAngle   = endA,
        easing     = easingName,
        arcColor   = arcColor,
        arcAlpha   = arcAlpha,
        lineWidth  = base.swing_animation.lineWidth or 2.5,
    })

    -- ── Impact + screen shake (finisher) ──────────────────────
    if didHit then
        local imp = base.impact_effect
        self._impactFlashTimer    = (imp.flashDuration or 0.08) * 1.3
        self._impactFlashDuration = self._impactFlashTimer
        local fps = love.timer.getFPS()
        if fps > 0 then self._hitStopTimer = (imp.hitStopFrames or 2) / fps end

        -- Finisher screen shake
        if hitCfg.screenShake and player.camera then
            player.camera:shake(hitCfg.screenShake.intensity, hitCfg.screenShake.duration)
        end
    end

    -- ── Combo progression ─────────────────────────────────────
    self._comboHit = nextHit
    if nextHit >= combo.maxHits then
        -- Combo kết thúc sau hit cuối
        self._comboHit         = 0
        self._comboWindowTimer = 0
    else
        self._comboWindowTimer = combo.comboWindow or 0.45
    end

    self._meleeCooldown = scaling.cooldown * 0.6  -- cooldown ngắn hơn giữa combo hits

    return true
end

---Bắt đầu animation swing arc.
---@param attackAngle number  Góc tấn công (player → chuột)
---@param cfg         table
function PlayerAbilities:_startSwingAnim(attackAngle, cfg)
    self._attackAngle            = attackAngle
    self._swingActive            = true
    self._swingTimer             = 0
    self._swingDuration          = cfg.duration    or 0.18
    self._swingStartAngle        = cfg.startAngle  or -0.9
    self._swingEndAngle          = cfg.endAngle    or  0.9
    self._swingEasingFn          = Easing.get(cfg.easing or "quadOut")
    self._swingArcColor          = cfg.arcColor    or { 0.4, 0.9, 1.0 }
    self._swingArcAlpha          = cfg.arcAlpha    or 0.55
    self._swingLineWidth         = cfg.lineWidth   or 2.5
    -- Expose cho PlayerStates.attacking
    self._currentSwingDuration   = self._swingDuration
end

-- ────────────────────────────────────────────────────────────
--  RANGED INTERNALS
-- ────────────────────────────────────────────────────────────

function PlayerAbilities:_canUseRanged()
    local cfg = self._skillData.ranged.slash_wave
    return self.powerLevel >= (cfg.condition.minLevel or 3)
end

function PlayerAbilities:_canUseChargedBeam()
    local cfg = self._skillData.ranged.charged_beam
    return self.powerLevel >= (cfg.condition.minLevel or 4)
       and self.player.isFocused
end

---Bắn Slash Wave.
---@param angle number
---@return boolean
function PlayerAbilities:_doRangedAttack(angle)
    local player  = self.player
    local cfg     = self._skillData.ranged.slash_wave
    local projCfg = cfg.projectile

    local p = newProjectile(player.x, player.y, angle, projCfg)
    table.insert(self.projectiles, p)

    self._rangedCooldown = cfg.fire.cooldown or 0.55

    -- Swing animation ringan untuk ranged
    self:_startSwingAnim(angle, {
        duration   = 0.12,
        startAngle = -0.4,
        endAngle   =  0.4,
        easing     = "linear",
        arcColor   = projCfg.color or { 0.4, 0.9, 1.0 },
        arcAlpha   = 0.35,
        lineWidth  = 1.5,
    })

    return true
end

function PlayerAbilities:_updateProjectiles(dt)
    local player = self.player
    local cm     = player.combatManager
    local W      = love.graphics.getWidth()
    local H      = love.graphics.getHeight()

    for i = #self.projectiles, 1, -1 do
        local p = self.projectiles[i]
        if not p.isAlive then
            table.remove(self.projectiles, i)
        else
            p.x    = p.x + p.vx * dt
            p.y    = p.y + p.vy * dt
            p._age = p._age + dt

            -- Out of bounds / lifetime
            if p._age >= p.lifetime
            or p.x < -50 or p.x > W + 50
            or p.y < -50 or p.y > H + 50 then
                p.isAlive = false
            else
                -- Va chạm với enemies + boss
                if cm then
                    local allTargets = {}
                    if cm.enemies then
                        for _, e in ipairs(cm.enemies) do table.insert(allTargets, e) end
                    end
                    if cm.boss and not cm.boss.isDead then
                        table.insert(allTargets, cm.boss)
                    end

                    for _, target in ipairs(allTargets) do
                        if target.isActive ~= false and not target.isDead then
                            -- Guard: pierce → chỉ hit 1 lần mỗi target
                            if not p._hitList[target] then
                                local tr = target.hitboxRadius or target.radius or 20
                                if Collision.circleAabb(
                                    target.x, target.y, tr,
                                    p.x - p.width * 0.5,
                                    p.y - p.height * 0.5,
                                    p.width, p.height)
                                then
                                    target:takeDamage(p.damage, { source = "ranged", attacker = player })
                                    p._hitList[target] = true
                                    if not p.pierce then
                                        p.isAlive = false
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  CHARGED BEAM INTERNALS
-- ────────────────────────────────────────────────────────────

function PlayerAbilities:_updateCharge(dt)
    local cfg      = self._skillData.ranged.charged_beam.charge
    local maxTime  = cfg.maxTime or 1.2
    self._chargeTimer = self._chargeTimer + dt
    self._chargeRatio = math.min(self._chargeTimer / maxTime, 1.0)

    -- Auto-fire khi đạt max charge
    if self._chargeTimer >= maxTime then
        self._isCharging = false
        self:_fireBeam()
    end
end

function PlayerAbilities:_fireBeam()
    local player = self.player
    local cfg    = self._skillData.ranged.charged_beam
    local projCfg= cfg.projectile

    -- Damage scale theo charge ratio (partial charge = weaker)
    local fullDmg  = projCfg.damage or 80
    local dmg      = fullDmg * (self._chargeRatio ^ 0.7)

    -- Raycast: tìm tất cả target trên đường beam
    local mx, my   = love.mouse.getPosition()
    local bx, by   = player.x, player.y
    local angle    = self._beamAngle
    local dx       = math.cos(angle)
    local dy       = math.sin(angle)
    local beamLen  = projCfg.length or 500

    local cm = player.combatManager
    if cm then
        local allTargets = {}
        if cm.enemies then for _, e in ipairs(cm.enemies) do table.insert(allTargets, e) end end
        if cm.boss and not cm.boss.isDead then table.insert(allTargets, cm.boss) end

        for _, target in ipairs(allTargets) do
            if target.isActive ~= false and not target.isDead then
                local tr = target.hitboxRadius or target.radius or 20
                local hit, _ = Collision.rayCircle(bx, by, dx, dy, beamLen, target.x, target.y, tr)
                if hit then
                    target:takeDamage(dmg, { source = "charged_beam", attacker = player })
                end
            end
        end
    end

    -- Beam visual
    self._beamActive   = true
    self._beamTimer    = 0
    self._beamLifetime = cfg.projectile.lifetime or 0.18
    self._beamAngle    = angle
    self._rangedCooldown = cfg.fire.cooldown or 1.2

    -- Screen shake
    local animCfg = cfg.animation
    if animCfg and animCfg.screenShake and player.camera then
        player.camera:shake(
            animCfg.screenShake.intensity or 5,
            animCfg.screenShake.duration  or 0.2
        )
    end

    self._chargeTimer = 0
    self._chargeRatio = 0
    return true
end

function PlayerAbilities:_updateBeam(dt)
    self._beamTimer = self._beamTimer + dt
    if self._beamTimer >= self._beamLifetime then
        self._beamActive = false
        self._beamTimer  = 0
    end
end

-- ────────────────────────────────────────────────────────────
--  BOMB
-- ────────────────────────────────────────────────────────────

function PlayerAbilities:activateBomb()
    if self._bombActive    then return end
    if self.bombStock <= 0 then return end

    self.bombStock     = self.bombStock - 1
    self._bombActive   = true
    self._bombTimer    = 0
    self._bombWaveTimer= 0

    -- Xoá đạn boss
    local bm = self.player.combatManager and self.player.combatManager.bulletManager
    if bm and bm.projectiles then
        for _, b in ipairs(bm.projectiles) do b.isAlive = false end
    end

    -- I-frames
    self.player:startInvincibility(self._bombIframes)

    print("[PlayerAbilities] BOMB activated — screen cleared!")
end

---@param dt number
function PlayerAbilities:_updateBomb(dt)
    local player = self.player
    self._bombTimer     = self._bombTimer + dt
    self._bombWaveTimer = self._bombWaveTimer + dt

    -- Damage enemy + boss
    local cm = player.combatManager
    if cm then
        if cm.enemies then
            for _, e in ipairs(cm.enemies) do
                if not e.isDead then
                    e:takeDamage(self._bombDamageRate * dt,
                        { ignoreDefense=true, ignoreIFrames=true, silent=true })
                end
            end
        end
        if cm.boss and not cm.boss.isDead then
            cm.boss:takeDamage(self._bombDamageRate * dt,
                { ignoreDefense=true, ignoreIFrames=true, silent=true })
        end
    end

    if self._bombWaveTimer >= self._bombWaveInterval then
        self._bombWaveTimer = self._bombWaveTimer - self._bombWaveInterval
        -- TODO: spawn expanding ring particle
    end

    if self._bombTimer >= self._bombDuration then
        self._bombActive = false
        self._bombTimer  = 0
        -- Lưu ý: isInvincible sẽ tự động được Actor:update đặt về false 
        -- khi _iFramesTimer (được set bởi startInvincibility) về 0.
        print("[PlayerAbilities] BOMB ended")
    end
end

-- ────────────────────────────────────────────────────────────
--  POWER SYSTEM
-- ────────────────────────────────────────────────────────────

---@param amount number?
function PlayerAbilities:gainPower(amount)
    local old = self.powerLevel
    self.powerLevel = math.min(MAX_POWER, self.powerLevel + (amount or 1))
    if self.powerLevel ~= old then
        print(string.format("[PlayerAbilities] Power: %d → %d", old, self.powerLevel))
    end
end

---@param amount number?
function PlayerAbilities:losePower(amount)
    self.powerLevel = math.max(1, self.powerLevel - (amount or 1))
    -- Reset combo khi mất power
    self._comboHit         = 0
    self._comboWindowTimer = 0
end

function PlayerAbilities:getPowerLevel()  return self.powerLevel end
function PlayerAbilities:isMaxPower()     return self.powerLevel >= MAX_POWER end

-- ────────────────────────────────────────────────────────────
--  SPECIAL ABILITY SLOT
-- ────────────────────────────────────────────────────────────

function PlayerAbilities:setSpecial(ability)
    self.specialAbility = ability
end

function PlayerAbilities:activateSpecial()
    if self.specialAbility and self.specialAbility.activate then
        self.specialAbility:activate(self.player)
    end
end

-- ────────────────────────────────────────────────────────────
--  TRAIL / AFTER-IMAGE
-- ────────────────────────────────────────────────────────────

function PlayerAbilities:_sampleTrail()
    local player = self.player
    local vel    = player.velocity
    if vel and (vel.x ~= 0 or vel.y ~= 0) then
        table.insert(self._trail, {
            x     = player.x,
            y     = player.y,
            alpha = self._trailAlphaStart,
        })
        if #self._trail > self._trailMaxSamples then
            table.remove(self._trail, 1)
        end
    end
end

function PlayerAbilities:_updateTrail(dt)
    for i = #self._trail, 1, -1 do
        local t = self._trail[i]
        t.alpha = t.alpha - dt * self._trailFadeMult
        if t.alpha <= 0 then table.remove(self._trail, i) end
    end
end

-- ────────────────────────────────────────────────────────────
--  INPUT RELAY
-- ────────────────────────────────────────────────────────────

---@param key string
function PlayerAbilities:keypressed(key)
    if key == "x" then self:activateBomb() end
    if key == "c" then self:activateSpecial() end
    if self.specialAbility and self.specialAbility.keypressed then
        self.specialAbility:keypressed(self.player, key)
    end
end

---@param key string
function PlayerAbilities:keyreleased(key)
    -- reserved
end

-- ────────────────────────────────────────────────────────────
--  DRAW
-- ────────────────────────────────────────────────────────────

function PlayerAbilities:draw()
    local player = self.player

    -- ── Trail ─────────────────────────────────────────────────
    local tc = self._trailColor
    for _, t in ipairs(self._trail) do
        love.graphics.setColor(tc[1], tc[2], tc[3], t.alpha * self._trailAlphaFactor)
        love.graphics.rectangle("fill",
            t.x - player.width  * 0.5,
            t.y - player.height * 0.5,
            player.width, player.height)
    end

    -- ── Swing arc animation ───────────────────────────────────
    if self._swingActive then
        local t        = Easing.progress(self._swingTimer, self._swingDuration)
        local easedT   = self._swingEasingFn and self._swingEasingFn(t) or t
        local curAngle = self._swingStartAngle
                       + (self._swingEndAngle - self._swingStartAngle) * easedT
        local alpha    = self._swingArcAlpha * Easing.pulse(t)
        local col      = self._swingArcColor
        local range    = self._skillData.melee.base.hitbox.range
                       * (self:_getScaling().rangeMult or 1.0)

        love.graphics.push()
        love.graphics.setColor(col[1], col[2], col[3], alpha)
        love.graphics.setLineWidth(self._swingLineWidth)
        love.graphics.arc(
            "line", "open",
            player.x, player.y,
            range,
            self._attackAngle + self._swingStartAngle,
            self._attackAngle + curAngle
        )
        love.graphics.setLineWidth(1)
        love.graphics.pop()
    end

    -- ── Impact flash ──────────────────────────────────────────
    if self._impactFlashTimer > 0 and self._impactFlashDuration > 0 then
        local t     = Easing.progress(
            self._impactFlashDuration - self._impactFlashTimer,
            self._impactFlashDuration)
        local alpha = Easing.pulse(t) * 0.6
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.circle("fill", player.x, player.y,
            self._skillData.melee.base.hitbox.range * 0.5)
    end

    -- ── Slash wave projectiles ────────────────────────────────
    for _, p in ipairs(self.projectiles) do
        if p.isAlive then
            local ageRatio = p._age / p.lifetime
            local alpha    = Easing.map(ageRatio, 1.0, 0.3, Easing.sineOut)
            local c        = p.color

            love.graphics.push()
            love.graphics.translate(p.x, p.y)
            love.graphics.rotate(p.angle)

            -- Glow
            love.graphics.setColor(c[1], c[2], c[3], alpha * 0.3)
            love.graphics.ellipse("fill", 0, 0,
                p.width * 0.5 + p.glowRadius,
                p.height * 0.5 + p.glowRadius * 0.4)

            -- Core
            love.graphics.setColor(c[1], c[2], c[3], alpha)
            love.graphics.ellipse("fill", 0, 0, p.width * 0.5, p.height * 0.5)

            -- Highlight
            love.graphics.setColor(1, 1, 1, alpha * 0.5)
            love.graphics.ellipse("fill", -p.width * 0.1, -p.height * 0.1,
                p.width * 0.25, p.height * 0.25)

            love.graphics.pop()
        end
    end

    -- ── Charged beam visual ───────────────────────────────────
    if self._beamActive then
        local t       = Easing.progress(self._beamTimer, self._beamLifetime)
        local alpha   = Easing.map(t, 1.0, 0, Easing.quadOut)
        local cfg     = self._skillData.ranged.charged_beam.projectile
        local beamLen = cfg.length or 500
        local beamW   = cfg.width  or 12
        local cc      = cfg.coreColor  or { 1, 1, 1 }
        local bc      = cfg.color      or { 1.0, 0.9, 0.3 }
        local dx      = math.cos(self._beamAngle)
        local dy      = math.sin(self._beamAngle)

        love.graphics.push()
        love.graphics.translate(self.player.x, self.player.y)
        love.graphics.rotate(self._beamAngle)

        -- Glow layer
        love.graphics.setColor(bc[1], bc[2], bc[3], alpha * 0.25)
        love.graphics.rectangle("fill", 0, -(beamW + cfg.glowRadius) * 0.5,
            beamLen, beamW + cfg.glowRadius)

        -- Core beam
        love.graphics.setColor(bc[1], bc[2], bc[3], alpha)
        love.graphics.rectangle("fill", 0, -beamW * 0.5, beamLen, beamW)

        -- White center
        love.graphics.setColor(cc[1], cc[2], cc[3], alpha * 0.9)
        love.graphics.rectangle("fill", 0, -beamW * 0.2, beamLen, beamW * 0.4)

        love.graphics.pop()
    end

    -- ── Charge indicator ──────────────────────────────────────
    if self._isCharging and self._chargeRatio > 0 then
        local ratio  = self._chargeRatio
        local pulse  = 0.5 + 0.5 * math.sin(love.timer.getTime() * 12)
        local radius = 8 + ratio * 24 + pulse * 4 * ratio
        local c      = { 1.0, 0.85, 0.2 }

        love.graphics.setColor(c[1], c[2], c[3], ratio * 0.4)
        love.graphics.circle("fill", player.x, player.y, radius * 1.4)
        love.graphics.setColor(c[1], c[2], c[3], ratio * 0.85)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", player.x, player.y, radius)
        love.graphics.setLineWidth(1)
    end

    -- ── Bomb overlay ──────────────────────────────────────────
    if self._bombActive then
        local W     = love.graphics.getWidth()
        local H     = love.graphics.getHeight()
        local t     = Easing.progress(self._bombTimer, self._bombDuration)
        local vis   = self._skillData.bomb.base.visual
        local alpha = Easing.pulse(t) * (vis.flashAlphaMax or 0.35)

        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.rectangle("fill", 0, 0, W, H)

        local rc = vis.ringColor or { 0.6, 0.9, 1.0 }
        local r  = t * math.sqrt(W*W + H*H)
        love.graphics.setColor(rc[1], rc[2], rc[3], alpha * 1.5)
        love.graphics.setLineWidth(vis.ringLineWidth or 3)
        love.graphics.circle("line", player.x, player.y, r)
        love.graphics.setLineWidth(1)
    end

    -- ── Special ability ───────────────────────────────────────
    if self.specialAbility and self.specialAbility.draw then
        self.specialAbility:draw(player)
    end

    love.graphics.setColor(1, 1, 1)
end

-- ────────────────────────────────────────────────────────────
--  DEBUG
-- ────────────────────────────────────────────────────────────

function PlayerAbilities:drawDebug()
    local player = self.player
    local x, y   = 10, love.graphics.getHeight() - 110

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", x - 4, y - 4, 260, 100, 4)

    love.graphics.setColor(0.4, 1, 0.8)
    love.graphics.print(string.format("Power:  %d / %d", self.powerLevel, MAX_POWER), x, y)
    love.graphics.print(string.format("Melee CD: %.2f  Ranged CD: %.2f", self._meleeCooldown, self._rangedCooldown), x, y+16)
    love.graphics.print(string.format("Combo hit: %d  Window: %.2f", self._comboHit, self._comboWindowTimer), x, y+32)
    love.graphics.print(string.format("Charge: %.0f%%  Beam: %s", self._chargeRatio*100, tostring(self._beamActive)), x, y+48)
    love.graphics.print(string.format("Bomb stock: %d  Active: %s", self.bombStock, tostring(self._bombActive)), x, y+64)
    love.graphics.print(string.format("Projectiles: %d  Trail: %d", #self.projectiles, #self._trail), x, y+80)

    -- Vẽ melee arc debug
    if player.state == "attacking" or love.keyboard.isDown("tab") then
        local mx, my = love.mouse.getPosition()
        local angle  = math.atan2(my - player.y, mx - player.x)
        local base   = self._skillData.melee.base
        local focus  = base.focus_modifier
        local scaling= self:_getScaling()
        local range  = base.hitbox.range * (scaling.rangeMult or 1.0)
        local arc    = player.isFocused and focus.arcHalfRad or base.hitbox.arcHalfRad

        Collision.drawMeleeArc(player.x, player.y, angle, arc, range)
    end

    love.graphics.setColor(1, 1, 1)
end

-- ────────────────────────────────────────────────────────────
--  EXPORT
-- ────────────────────────────────────────────────────────────

return {
    new       = function(player) return PlayerAbilities.new(player) end,
    MAX_POWER = MAX_POWER,
}
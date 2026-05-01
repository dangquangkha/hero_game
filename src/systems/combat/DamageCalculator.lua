-- src/systems/combat/DamageCalculator.lua
-- ============================================================
--  DamageCalculator — Tính toán sát thương cuối cùng
--
--  Vai trò trong kiến trúc:
--    DamageSystem nhận raw damage từ CollisionSystem
--         ↓ truyền vào
--    DamageCalculator.calculate(raw, attacker, defender)
--         ↓ trả về
--    finalDamage (số) → DamageSystem gọi entity:takeDamage(final)
--
--  Nguyên tắc thiết kế:
--    - Module thuần túy (pure functions) — KHÔNG class, KHÔNG state
--    - KHÔNG biết về entities cụ thể — chỉ nhận stats table
--    - Dễ mở rộng: thêm elemental, crit, buff/debuff sau này
--    - An toàn khi attacker hoặc defender là nil (fallback về raw)
--
--  Hiện tại (Phase 1 — chưa có stat system):
--    calculate() trả về raw damage trực tiếp.
--    Các hàm con (crit, elemental, defense) đã được viết sẵn
--    nhưng chỉ được gọi khi stats tồn tại → không ảnh hưởng gameplay
--    hiện tại, sẵn sàng khi bạn thêm stat system sau.
-- ============================================================

local DamageCalculator = {}

-- ────────────────────────────────────────────────────────────
--  CONSTANTS — Điều chỉnh tại đây khi balance game
-- ────────────────────────────────────────────────────────────

local DEFAULTS = {
    -- Crit
    CRIT_CHANCE     = 0.0,    -- 0% mặc định (chưa có stat system)
    CRIT_MULTIPLIER = 2.0,    -- Crit gây x2 damage

    -- Defense reduction
    -- finalDamage = rawDamage * (100 / (100 + defense))
    -- defense=0   → nhận 100%
    -- defense=50  → nhận 66.7%
    -- defense=100 → nhận 50%
    BASE_DEFENSE    = 0,

    -- Elemental multipliers
    ELEMENT_WEAK    = 1.5,    -- Điểm yếu  → x1.5
    ELEMENT_RESIST  = 0.5,    -- Kháng cự  → x0.5
    ELEMENT_NEUTRAL = 1.0,    -- Trung tính → x1.0

    -- Damage floor: không bao giờ gây < 1 damage
    MIN_DAMAGE      = 1,
}

-- ────────────────────────────────────────────────────────────
--  Bảng khắc chế nguyên tố (element chart)
--  Mở rộng khi có elemental system
--  Cấu trúc: [attacker_element][defender_element] = multiplier
-- ────────────────────────────────────────────────────────────

local ELEMENT_CHART = {
    fire  = { water = DEFAULTS.ELEMENT_RESIST, wind  = DEFAULTS.ELEMENT_WEAK   },
    water = { fire  = DEFAULTS.ELEMENT_WEAK,   earth = DEFAULTS.ELEMENT_RESIST  },
    wind  = { fire  = DEFAULTS.ELEMENT_RESIST, earth = DEFAULTS.ELEMENT_WEAK   },
    earth = { wind  = DEFAULTS.ELEMENT_RESIST, water = DEFAULTS.ELEMENT_WEAK   },
}

-- ────────────────────────────────────────────────────────────
--  PUBLIC: calculate
--  Hàm chính — DamageSystem gọi hàm này.
--
--  @param rawDamage  number        Damage thô từ bullet.damage
--  @param attacker   table|nil     Entity tấn công
--                                  Cần có: .stats.critChance, .element
--  @param defender   table|nil     Entity nhận đòn
--                                  Cần có: .stats.defense, .element
--  @return           number        Damage cuối (integer, >= MIN_DAMAGE)
-- ────────────────────────────────────────────────────────────

function DamageCalculator.calculate(rawDamage, attacker, defender)
    -- Guard: rawDamage phải là số hợp lệ
    if type(rawDamage) ~= "number" or rawDamage <= 0 then
        return DEFAULTS.MIN_DAMAGE
    end

    local damage = rawDamage

    -- Bước 1: Elemental multiplier
    -- Chỉ tính khi cả hai bên có element
    if attacker and defender then
        damage = damage * DamageCalculator.getElementMultiplier(
            attacker.element,
            defender.element
        )
    end

    -- Bước 2: Defense reduction
    -- Chỉ tính khi defender có stats.defense
    if defender and defender.stats and defender.stats.defense then
        damage = DamageCalculator.applyDefense(damage, defender.stats.defense)
    end

    -- Bước 3: Critical hit
    -- Chỉ tính khi attacker có stats.critChance
    if attacker and attacker.stats and attacker.stats.critChance then
        damage = DamageCalculator.applyCrit(damage, attacker.stats.critChance)
    end

    -- Bước 4: Damage floor — không bao giờ < MIN_DAMAGE
    damage = math.max(DEFAULTS.MIN_DAMAGE, math.floor(damage))

    return damage
end

-- ────────────────────────────────────────────────────────────
--  getElementMultiplier
--  Tra bảng ELEMENT_CHART để lấy multiplier.
--
--  @param atkElement  string|nil   "fire", "water", "wind", "earth", nil
--  @param defElement  string|nil
--  @return            number       1.0 nếu không có element
-- ────────────────────────────────────────────────────────────

function DamageCalculator.getElementMultiplier(atkElement, defElement)
    if not atkElement or not defElement then
        return DEFAULTS.ELEMENT_NEUTRAL
    end

    local row = ELEMENT_CHART[atkElement]
    if not row then
        return DEFAULTS.ELEMENT_NEUTRAL
    end

    return row[defElement] or DEFAULTS.ELEMENT_NEUTRAL
end

-- ────────────────────────────────────────────────────────────
--  applyDefense
--  Công thức: damage * 100 / (100 + defense)
--  defense=0   → nhận 100%
--  defense=100 → nhận 50%
--
--  @param damage   number
--  @param defense  number  (>= 0)
--  @return         number
-- ────────────────────────────────────────────────────────────

function DamageCalculator.applyDefense(damage, defense)
    defense = math.max(0, defense or 0)
    return damage * (100 / (100 + defense))
end

-- ────────────────────────────────────────────────────────────
--  applyCrit
--  Roll crit dựa trên critChance [0.0 .. 1.0].
--
--  @param damage      number
--  @param critChance  number  [0.0 .. 1.0]
--  @return            number
-- ────────────────────────────────────────────────────────────

function DamageCalculator.applyCrit(damage, critChance)
    critChance = math.max(0, math.min(1, critChance or 0))
    if math.random() < critChance then
        return damage * DEFAULTS.CRIT_MULTIPLIER
    end
    return damage
end

-- ────────────────────────────────────────────────────────────
--  isCrit
--  Pure check — không apply damage, dùng cho UI "CRIT!" popup.
--
--  @param critChance  number  [0.0 .. 1.0]
--  @return            boolean
-- ────────────────────────────────────────────────────────────

function DamageCalculator.isCrit(critChance)
    critChance = math.max(0, math.min(1, critChance or 0))
    return math.random() < critChance
end

-- ────────────────────────────────────────────────────────────
--  EXPORT CONSTANTS (để UI hoặc SkillSystem đọc nếu cần)
-- ────────────────────────────────────────────────────────────

DamageCalculator.DEFAULTS      = DEFAULTS
DamageCalculator.ELEMENT_CHART = ELEMENT_CHART

--[[
  VÍ DỤ SỬ DỤNG:

  -- Hiện tại (chưa có stat system) — DamageSystem gọi:
  local dmg = DamageCalculator.calculate(bullet.damage, nil, player)
  -- → trả về bullet.damage (defense=0, no crit, no element)

  -- Khi có stat system đầy đủ:
  local dmg = DamageCalculator.calculate(
      bullet.damage,
      { element = "fire",  stats = { critChance = 0.15 } },
      { element = "water", stats = { defense = 30 } }
  )
  -- → fire vs water: x1.5 → defense(100/130) → crit roll 15%

  -- Hiện "CRIT!" popup mà không tính lại damage:
  if DamageCalculator.isCrit(player.stats.critChance) then
      numberPopup:show("CRIT!", x, y, { 1, 0.8, 0 })
  end
--]]

return DamageCalculator
-- src/utils/math/Easing.lua
-- ============================================================
--  Easing — Hàm nội suy phi tuyến
--
--  Tái sử dụng cho: animation UI, trail fade, melee swing arc,
--  camera shake decay, hurt flash, bomb overlay alpha...
--
--  Tất cả hàm nhận t ∈ [0..1] và trả về giá trị ∈ [0..1]
--  (trừ elastic/back có thể vượt nhẹ ra ngoài khoảng này).
--
--  Cách dùng:
--    local Easing = require 'src.utils.math.Easing'
--
--    -- Nội suy đơn giản:
--    local v = Easing.quadOut(t)          -- t: 0→1, v: 0→1
--
--    -- Nội suy có start/end/duration:
--    local v = Easing.map(t, 0, 1, Easing.sineOut)
--
--    -- Trong update loop:
--    self._timer = self._timer + dt
--    local t     = math.min(self._timer / self._duration, 1)
--    local alpha = Easing.quadOut(t) * 0.8
-- ============================================================

local Easing = {}

-- ────────────────────────────────────────────────────────────
--  HELPER NỘI BỘ
-- ────────────────────────────────────────────────────────────

---Clamp t về [0, 1] — bảo vệ khi timer vượt duration.
---@param t number
---@return number
local function clamp01(t)
    if t < 0 then return 0 end
    if t > 1 then return 1 end
    return t
end

-- ────────────────────────────────────────────────────────────
--  LINEAR
-- ────────────────────────────────────────────────────────────

---Tuyến tính — không có gia tốc/giảm tốc.
---Dùng cho: thanh máu, loading bar, debug overlay.
---@param t number  [0..1]
---@return number
function Easing.linear(t)
    return clamp01(t)
end

-- ────────────────────────────────────────────────────────────
--  QUAD  (bậc 2 — mượt, phổ biến nhất)
-- ────────────────────────────────────────────────────────────

---Quad ease-in: bắt đầu chậm, tăng tốc.
---Dùng cho: đạn lao nhanh, zoom in.
---@param t number  [0..1]
---@return number
function Easing.quadIn(t)
    t = clamp01(t)
    return t * t
end

---Quad ease-out: bắt đầu nhanh, giảm dần → dừng mượt.
---Dùng cho: melee swing arc, UI panel trượt vào, bomb circle mở rộng.
---@param t number  [0..1]
---@return number
function Easing.quadOut(t)
    t = clamp01(t)
    return t * (2 - t)
end

---Quad ease-in-out: chậm → nhanh → chậm.
---Dùng cho: camera pan, object di chuyển giữa 2 điểm.
---@param t number  [0..1]
---@return number
function Easing.quadInOut(t)
    t = clamp01(t)
    if t < 0.5 then
        return 2 * t * t
    else
        return -1 + (4 - 2 * t) * t
    end
end

-- ────────────────────────────────────────────────────────────
--  SINE  (bậc sin — cực mượt, tự nhiên nhất)
-- ────────────────────────────────────────────────────────────

---Sine ease-in: khởi đầu cực nhẹ, tăng dần.
---Dùng cho: fade in nhân vật sau i-frames.
---@param t number  [0..1]
---@return number
function Easing.sineIn(t)
    t = clamp01(t)
    return 1 - math.cos(t * math.pi * 0.5)
end

---Sine ease-out: giảm tốc mượt mà, tự nhiên.
---Dùng cho: trail alpha fade, hurt flash tắt dần, graze ring mờ dần.
---@param t number  [0..1]
---@return number
function Easing.sineOut(t)
    t = clamp01(t)
    return math.sin(t * math.pi * 0.5)
end

---Sine ease-in-out: mượt nhất trong các loại — dùng nhiều nhất.
---Dùng cho: HUD pulse, score pop animation, bất kỳ loop animation nào.
---@param t number  [0..1]
---@return number
function Easing.sineInOut(t)
    t = clamp01(t)
    return 0.5 * (1 - math.cos(t * math.pi))
end

-- ────────────────────────────────────────────────────────────
--  PULSE  (sin đầy đủ: 0→1→0 trong t=0..1)
--  Rất hữu ích cho hiệu ứng nhấp nháy, ping, vòng graze
-- ────────────────────────────────────────────────────────────

---Pulse hình sin: lên rồi xuống trong 1 chu kỳ.
---Dùng cho: vòng graze expand/fade, hurt blink, bomb shockwave alpha.
---@param t number  [0..1]
---@return number   đỉnh ở t=0.5
function Easing.pulse(t)
    t = clamp01(t)
    return math.sin(t * math.pi)
end

---Pulse nhanh bậc 2: lên-xuống nhưng sắc nét hơn sin.
---Dùng cho: score pop (xuất hiện mạnh → biến mất nhanh).
---@param t number  [0..1]
---@return number
function Easing.pulseSq(t)
    t = clamp01(t)
    local s = math.sin(t * math.pi)
    return s * s
end

-- ────────────────────────────────────────────────────────────
--  STEP & SMOOTHSTEP
-- ────────────────────────────────────────────────────────────

---Hard step tại ngưỡng edge (0 trước, 1 sau).
---Dùng cho: hiện/ẩn tức thì, trigger logic.
---@param t    number  [0..1]
---@param edge number? Ngưỡng (mặc định 0.5)
---@return number  0 hoặc 1
function Easing.step(t, edge)
    edge = edge or 0.5
    return clamp01(t) >= edge and 1 or 0
end

---Smoothstep: interpolation bậc 3, không cần sin/cos.
---Nhanh hơn sineInOut, đủ mượt cho hầu hết UI.
---@param t number  [0..1]
---@return number
function Easing.smoothstep(t)
    t = clamp01(t)
    return t * t * (3 - 2 * t)
end

---Smootherstep: bậc 5 — còn mượt hơn smoothstep.
---Dùng cho: camera lerp, tween vị trí quan trọng.
---@param t number  [0..1]
---@return number
function Easing.smootherstep(t)
    t = clamp01(t)
    return t * t * t * (t * (t * 6 - 15) + 10)
end

-- ────────────────────────────────────────────────────────────
--  UTILITY: MAP & APPLY
-- ────────────────────────────────────────────────────────────

---Áp dụng easing function để nội suy từ `from` đến `to`.
---  v = Easing.map(t, from, to, Easing.quadOut)
---@param t       number    [0..1]
---@param from    number    Giá trị đầu
---@param to      number    Giá trị cuối
---@param easeFn  function  Easing function (t → [0..1])
---@return number
function Easing.map(t, from, to, easeFn)
    local e = easeFn(t)
    return from + (to - from) * e
end

---Tính t chuẩn hóa từ timer và duration, clamp về [0,1].
---  t = Easing.progress(self._timer, self._duration)
---@param timer    number  Thời gian đã trôi qua
---@param duration number  Tổng thời gian
---@return number  t ∈ [0..1]
function Easing.progress(timer, duration)
    if duration <= 0 then return 1 end
    return math.min(timer / duration, 1)
end

---Flip t: 1-t (đảo ngược chiều easing).
---  Dùng ease-out làm ease-in: Easing.flip(Easing.quadOut)(t)
---@param easeFn function
---@return function
function Easing.flip(easeFn)
    return function(t) return 1 - easeFn(1 - t) end
end

---Ghép hai phase: ease-in [0..0.5] rồi ease-out [0.5..1].
---@param inFn  function
---@param outFn function
---@return function
function Easing.inOut(inFn, outFn)
    return function(t)
        t = clamp01(t)
        if t < 0.5 then
            return inFn(t * 2) * 0.5
        else
            return 0.5 + outFn((t - 0.5) * 2) * 0.5
        end
    end
end

-- ────────────────────────────────────────────────────────────
--  BẢNG THAM CHIẾU NHANH
--  Dùng khi muốn chọn easing bằng string (VD: từ JSON skill data)
-- ────────────────────────────────────────────────────────────

---@type table<string, function>
Easing.registry = {
    linear       = Easing.linear,
    quadIn       = Easing.quadIn,
    quadOut      = Easing.quadOut,
    quadInOut    = Easing.quadInOut,
    sineIn       = Easing.sineIn,
    sineOut      = Easing.sineOut,
    sineInOut    = Easing.sineInOut,
    pulse        = Easing.pulse,
    pulseSq      = Easing.pulseSq,
    step         = Easing.step,
    smoothstep   = Easing.smoothstep,
    smootherstep = Easing.smootherstep,
}

---Lấy easing function từ tên string (fallback về linear nếu không tìm thấy).
---  Dùng khi load từ player_skills.json:
---  local fn = Easing.get(skillData.swingEasing)
---@param name string
---@return function
function Easing.get(name)
    local fn = Easing.registry[name]
    if not fn then
        print("[Easing] WARNING: unknown easing '" .. tostring(name) .. "', fallback to linear")
        return Easing.linear
    end
    return fn
end

-- ────────────────────────────────────────────────────────────
--  EXPORT
-- ────────────────────────────────────────────────────────────

--[[
  VÍ DỤ SỬ DỤNG TRONG GAME:

  -- Melee swing arc (quadOut → bắt đầu nhanh, dừng mượt):
  local t     = Easing.progress(self._swingTimer, self._swingDuration)
  local angle = Easing.map(t, -math.pi/4, math.pi/4, Easing.quadOut)

  -- Trail alpha fade (sineOut → tắt dần tự nhiên):
  local t     = Easing.progress(age, maxAge)
  local alpha = Easing.map(t, 0.5, 0, Easing.sineOut)

  -- Hurt flash (pulse → sáng lên rồi về 0):
  local t     = Easing.progress(self._hurtTimer, 0.3)
  local flash = Easing.pulse(t) * 0.8

  -- Graze ring expand:
  local t      = Easing.progress(self._grazeTimer, 0.5)
  local radius = Easing.map(t, grazeR, grazeR * 1.6, Easing.quadOut)
  local alpha  = Easing.map(t, 0.6,  0,              Easing.sineOut)
--]]

return Easing
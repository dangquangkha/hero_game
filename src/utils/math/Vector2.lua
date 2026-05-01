-- src/utils/math/Vector2.lua
-- ============================================================
--  Vector2 — Toán học vector 2D dạng OOP
--
--  Thiết kế tái sử dụng: Player, Boss, Enemy, Bullet đều dùng
--  chung module này — không viết lại toán vector ở từng entity.
--
--  Hai cách dùng:
--    1. OOP  : local v = Vector2.new(3, 4)  → v:length(), v:normalize()...
--    2. Static: Vector2.add(a, b)            → trả về Vector2 mới
--
--  Tất cả phương thức OOP KHÔNG mutate self (immutable style),
--  trừ :set() và :setXY() được đánh dấu rõ.
--  → An toàn khi dùng chung ref giữa nhiều system.
-- ============================================================

local Vector2 = {}
Vector2.__index = Vector2

-- ────────────────────────────────────────────────────────────
--  CONSTRUCTOR
-- ────────────────────────────────────────────────────────────

---Tạo vector mới.
---@param x number?  (mặc định 0)
---@param y number?  (mặc định 0)
---@return Vector2
function Vector2.new(x, y)
    return setmetatable({ x = x or 0, y = y or 0 }, Vector2)
end

---Trả về vector (0, 0).
---@return Vector2
function Vector2.zero()
    return Vector2.new(0, 0)
end

---Alias ngắn (dùng như V(3,4) thay vì Vector2.new(3,4)).
---@param x number?
---@param y number?
---@return Vector2
local function V(x, y) return Vector2.new(x, y) end

---Clone vector hiện tại.
---@return Vector2
function Vector2:clone()
    return V(self.x, self.y)
end

---Gán giá trị từ vector khác (MUTATEs self).
---@param other Vector2
---@return Vector2  self (chaining)
function Vector2:set(other)
    self.x = other.x
    self.y = other.y
    return self
end

---Gán x, y trực tiếp (MUTATEs self).
---@param x number
---@param y number
---@return Vector2  self (chaining)
function Vector2:setXY(x, y)
    self.x = x
    self.y = y
    return self
end

-- ────────────────────────────────────────────────────────────
--  PHÉP TOÁN CƠ BẢN (trả về Vector2 mới, không mutate)
-- ────────────────────────────────────────────────────────────

---Cộng hai vector.
---@param other Vector2
---@return Vector2
function Vector2:add(other)
    return V(self.x + other.x, self.y + other.y)
end

---Trừ vector khác khỏi self.
---@param other Vector2
---@return Vector2
function Vector2:sub(other)
    return V(self.x - other.x, self.y - other.y)
end

---Nhân vô hướng (scale).
---@param scalar number
---@return Vector2
function Vector2:scale(scalar)
    return V(self.x * scalar, self.y * scalar)
end

---Chia vô hướng.
---@param scalar number
---@return Vector2
function Vector2:div(scalar)
    if scalar == 0 then return V(0, 0) end
    return V(self.x / scalar, self.y / scalar)
end

---Negation (đảo chiều vector).
---@return Vector2
function Vector2:negate()
    return V(-self.x, -self.y)
end

-- ────────────────────────────────────────────────────────────
--  ĐỘ DÀI & NORMALIZE
-- ────────────────────────────────────────────────────────────

---Độ dài bình phương (tránh sqrt khi chỉ so sánh).
---@return number
function Vector2:lengthSq()
    return self.x * self.x + self.y * self.y
end

---Độ dài (magnitude).
---@return number
function Vector2:length()
    return math.sqrt(self.x * self.x + self.y * self.y)
end

---Khoảng cách bình phương tới vector khác.
---@param other Vector2
---@return number
function Vector2:distSq(other)
    local dx = self.x - other.x
    local dy = self.y - other.y
    return dx * dx + dy * dy
end

---Khoảng cách tới vector khác.
---@param other Vector2
---@return number
function Vector2:dist(other)
    return math.sqrt(self:distSq(other))
end

---Trả về vector đơn vị (normalized). Nếu length=0 trả về (0,0).
---@return Vector2
function Vector2:normalize()
    local len = self:length()
    if len == 0 then return V(0, 0) end
    return V(self.x / len, self.y / len)
end

---Clamp độ dài về tối đa maxLen.
---Hữu ích khi giới hạn tốc độ di chuyển.
---@param maxLen number
---@return Vector2
function Vector2:clampLength(maxLen)
    local x, y = self.x, self.y
    local lenSq = x * x + y * y
    
    -- Kiểm tra NaN hoặc Infinity
    if lenSq ~= lenSq or lenSq == 1/0 then
        return setmetatable({ x = 0, y = 0 }, Vector2)
    end

    if lenSq <= maxLen * maxLen or lenSq == 0 then 
        return setmetatable({ x = x, y = y }, Vector2)
    end

    local len = math.sqrt(lenSq)
    local factor = maxLen / len
    return setmetatable({ x = x * factor, y = y * factor }, Vector2)
end

-- ────────────────────────────────────────────────────────────
--  TÍCH VÔ HƯỚNG (DOT PRODUCT)
-- ────────────────────────────────────────────────────────────

---Dot product với vector khác.
---  > 0 : cùng hướng chung
---  = 0 : vuông góc
---  < 0 : ngược hướng
---@param other Vector2
---@return number
function Vector2:dot(other)
    return self.x * other.x + self.y * other.y
end

---Cross product 2D (trả về scalar — z-component).
---  > 0 : other nằm bên trái self (counter-clockwise)
---  < 0 : other nằm bên phải self (clockwise)
---@param other Vector2
---@return number
function Vector2:cross(other)
    return self.x * other.y - self.y * other.x
end

-- ────────────────────────────────────────────────────────────
--  GÓC
-- ────────────────────────────────────────────────────────────

---Góc của vector tính từ trục X dương (radian, -π .. π).
---@return number
function Vector2:angle()
    return math.atan2(self.y, self.x)
end

---Tạo vector từ góc và độ dài.
---@param angle  number  Góc radian
---@param length number? (mặc định 1)
---@return Vector2
function Vector2.fromAngle(angle, length)
    length = length or 1
    return V(math.cos(angle) * length, math.sin(angle) * length)
end

---Vector chỉ hướng từ self → target.
---Trả về (0,0) nếu cùng điểm.
---@param target Vector2
---@return Vector2
function Vector2:directionTo(target)
    return target:sub(self):normalize()
end

---Góc từ self sang target (radian).
---@param target Vector2
---@return number
function Vector2:angleTo(target)
    return math.atan2(target.y - self.y, target.x - self.x)
end

-- ────────────────────────────────────────────────────────────
--  TOÁN TỬ LUA (metamethods)
-- ────────────────────────────────────────────────────────────

-- Cho phép dùng +, -, *, == trực tiếp giữa các Vector2
Vector2.__add = function(a, b) return a:add(b) end
Vector2.__sub = function(a, b) return a:sub(b) end
Vector2.__mul = function(a, b)
    -- v * scalar  HOẶC  scalar * v
    if type(a) == "number" then return b:scale(a) end
    if type(b) == "number" then return a:scale(b) end
    -- v * v → dot product (scalar)
    return a:dot(b)
end
Vector2.__unm = function(a) return a:negate() end
Vector2.__eq  = function(a, b) return a.x == b.x and a.y == b.y end
Vector2.__tostring = function(v)
    return string.format("Vector2(%.2f, %.2f)", v.x, v.y)
end

-- ────────────────────────────────────────────────────────────
--  STATIC HELPERS (không cần instance)
-- ────────────────────────────────────────────────────────────

---Cộng hai vector dạng static (tiện khi không muốn tạo instance).
---@param a Vector2
---@param b Vector2
---@return Vector2
function Vector2.add(a, b) return a:add(b) end

---Trừ hai vector dạng static.
---@param a Vector2
---@param b Vector2
---@return Vector2
function Vector2.sub(a, b) return a:sub(b) end

---Scale dạng static.
---@param v      Vector2
---@param scalar number
---@return Vector2
function Vector2.scale(v, scalar) return v:scale(scalar) end

---Khoảng cách giữa hai điểm (tạo instance tạm).
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number
function Vector2.distance(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return math.sqrt(dx * dx + dy * dy)
end

---Khoảng cách bình phương (tránh sqrt).
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number
function Vector2.distanceSq(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

---Dot product dạng raw (không tạo instance — fastest path).
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number
function Vector2.dot2(ax, ay, bx, by)
    return ax * bx + ay * by
end

---Vector zero.
---@return Vector2
function Vector2.zero() return V(0, 0) end

---Vector đơn vị trục X.
---@return Vector2
function Vector2.right() return V(1, 0) end

---Vector đơn vị trục Y.
---@return Vector2
function Vector2.down() return V(0, 1) end

-- ────────────────────────────────────────────────────────────
--  LERP
--  Dùng cho mouse-follow, smooth camera, projectile homing...
-- ────────────────────────────────────────────────────────────

---Linear interpolation giữa hai vector.
---  t=0 → a,  t=1 → b
---@param a Vector2
---@param b Vector2
---@param t number   [0..1]
---@return Vector2
function Vector2.lerp(a, b, t)
    return V(
        a.x + (b.x - a.x) * t,
        a.y + (b.y - a.y) * t
    )
end

---Lerp nhanh kiểu "exponential decay" — mượt không cần t tuyệt đối.
---  Dùng: pos = Vector2.expLerp(pos, target, factor, dt)
---  factor ~15 → "dính vào con trỏ gần như ngay lập tức" (theo yêu cầu)
---  factor ~6  → mượt rõ rệt có đà
---
---  Công thức: pos + (target - pos) * (1 - e^(-factor*dt))
---  Không phụ thuộc framerate (frame-rate independent).
---@param current Vector2
---@param target  Vector2
---@param factor  number   tốc độ hội tụ (>0)
---@param dt      number   delta time
---@return Vector2
function Vector2.expLerp(current, target, factor, dt)
    factor = factor or 15
    local t = 1 - math.exp(-factor * (dt or 0))
    return Vector2.lerp(current, target, t)
end

-- ────────────────────────────────────────────────────────────
--  EXPORT
-- ────────────────────────────────────────────────────────────

--  Cách dùng trong entity:
--    local Vector2 = require 'src.utils.math.Vector2'
--    local pos = Vector2.new(100, 200)
--    local vel = Vector2.fromAngle(math.pi/4, 300)   -- 300 px/s góc 45°
--    pos = Vector2.expLerp(pos, mouseTarget, 15, dt)  -- mouse follow

return Vector2
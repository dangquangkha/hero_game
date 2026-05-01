-- your-game/src/entities/base/Entity.lua
-- ============================================================
--  Entity — Base class cho mọi object tồn tại trong game world
--  Cung cấp: vị trí, kích thước, vòng đời (alive/dead), tag hệ thống
-- ============================================================

local class = require 'libs.middleclass.middleclass'

local Entity = class('Entity')

-- ────────────────────────────────────────────────────────────
--  CONSTRUCTOR
-- ────────────────────────────────────────────────────────────

---@param x        number   Tọa độ X ban đầu
---@param y        number   Tọa độ Y ban đầu
---@param w        number?  Chiều rộng bounding box  (mặc định 0 - dùng radius)
---@param h        number?  Chiều cao  bounding box  (mặc định 0)
---@param radius   number?  Bán kính hitbox tròn     (mặc định 0)
function Entity:initialize(x, y, w, h, radius)
    -- ── Vị trí & kích thước ──────────────────────────────────
    self.x      = x      or 0
    self.y      = y      or 0
    self.width  = w      or 0
    self.height = h      or 0
    self.radius = radius or 0   -- dùng cho collision hình tròn (phổ biến trong Danmaku)

    -- ── Vòng đời ─────────────────────────────────────────────
    self.isAlive   = true    -- false → Entity bị đánh dấu để xóa khỏi danh sách
    self.isVisible = true    -- false → skip vẽ nhưng vẫn update (VD: invisible trap)
    self.isActive  = true    -- false → skip cả update lẫn collision (frozen/paused)

    -- ── Nhận dạng ────────────────────────────────────────────
    -- tags là một set (table với key = tag, value = true)
    -- VD: entity.tags["enemy"] = true   entity.tags["projectile"] = true
    self.tags = {}
    self.id   = Entity._nextId        -- ID duy nhất, tự tăng
    Entity._nextId = Entity._nextId + 1

    -- ── Phân lớp vẽ (draw layer / Z-order) ──────────────────
    -- Giá trị nhỏ hơn vẽ trước (nằm dưới).  Mặc định 0.
    -- Boss = -10 | Bullet = 0 | Player = 10 | UI = 100
    self.zOrder = 0
end

-- Bộ đếm ID toàn cục (static)
Entity._nextId = 1

-- ────────────────────────────────────────────────────────────
--  VÒNG ĐỜI (LIFECYCLE)
-- ────────────────────────────────────────────────────────────

--- Được gọi mỗi frame bởi Manager/Scene.
--- Các subclass override hàm này để thêm logic riêng.
---@param dt number Delta time (giây)
function Entity:update(dt)
    -- Base Entity không có logic update.
    -- Subclass override và gọi Entity.update(self, dt) nếu cần.
end

--- Được gọi mỗi frame để render Entity.
--- Các subclass override hàm này.
function Entity:draw()
    -- Base Entity không vẽ gì.
end

--- Đánh dấu Entity là "đã chết" để Manager dọn dẹp.
--- Không xóa ngay lập tức — Manager sẽ lọc ra sau frame.
function Entity:destroy()
    self.isAlive  = false
    self.isActive = false
    self:onDestroy()
end

--- Hook: Gọi khi Entity bị destroy.  Subclass override để cleanup.
function Entity:onDestroy()
    -- VD: phát hiệu ứng nổ, trả về object pool, v.v.
end

-- ────────────────────────────────────────────────────────────
--  TAG SYSTEM
-- ────────────────────────────────────────────────────────────

--- Thêm một tag vào Entity.
---@param tag string
function Entity:addTag(tag)
    self.tags[tag] = true
end

--- Xóa một tag khỏi Entity.
---@param tag string
function Entity:removeTag(tag)
    self.tags[tag] = nil
end

--- Kiểm tra Entity có tag đó không.
---@param tag string
---@return boolean
function Entity:hasTag(tag)
    return self.tags[tag] == true
end

-- ────────────────────────────────────────────────────────────
--  POSITION HELPERS
-- ────────────────────────────────────────────────────────────

--- Đặt vị trí Entity.
---@param x number
---@param y number
function Entity:setPosition(x, y)
    self.x = x
    self.y = y
end

--- Dịch chuyển Entity tương đối.
---@param dx number
---@param dy number
function Entity:translate(dx, dy)
    self.x = self.x + dx
    self.y = self.y + dy
end

--- Khoảng cách Euclidean đến một điểm (x, y).
---@param x number
---@param y number
---@return number
function Entity:distanceTo(x, y)
    local dx = self.x - x
    local dy = self.y - y
    return math.sqrt(dx * dx + dy * dy)
end

--- Khoảng cách bình phương đến một điểm — nhanh hơn khi chỉ cần so sánh.
---@param x number
---@param y number
---@return number
function Entity:distanceSqTo(x, y)
    local dx = self.x - x
    local dy = self.y - y
    return dx * dx + dy * dy
end

--- Góc (radian) từ Entity hiện tại nhắm đến điểm (x, y).
---@param x number
---@param y number
---@return number
function Entity:angleTo(x, y)
    return math.atan2(y - self.y, x - self.x)
end

-- ────────────────────────────────────────────────────────────
--  BOUNDS HELPERS
-- ────────────────────────────────────────────────────────────

--- Trả về bounding box {left, top, right, bottom}.
---@return table
function Entity:getBounds()
    local hw = self.width  * 0.5
    local hh = self.height * 0.5
    return {
        left   = self.x - hw,
        top    = self.y - hh,
        right  = self.x + hw,
        bottom = self.y + hh,
    }
end

--- Kiểm tra một điểm (px, py) có nằm trong bounding box không.
---@param px number
---@param py number
---@return boolean
function Entity:containsPoint(px, py)
    local b = self:getBounds()
    return px >= b.left and px <= b.right
       and py >= b.top  and py <= b.bottom
end

-- ────────────────────────────────────────────────────────────
--  DEBUG
-- ────────────────────────────────────────────────────────────

--- Vẽ hitbox/bounding box để debug (gọi từ DebugUI hoặc override :draw()).
---@param showRadius boolean? Có vẽ vòng tròn radius không (mặc định true)
function Entity:drawDebug(showRadius)
    if not self.isVisible then return end

    love.graphics.push()
    love.graphics.setLineWidth(1)

    -- Bounding box (màu vàng)
    if self.width > 0 and self.height > 0 then
        love.graphics.setColor(1, 1, 0, 0.6)
        local b = self:getBounds()
        love.graphics.rectangle("line", b.left, b.top, self.width, self.height)
    end

    -- Hitbox radius (màu đỏ nhạt)
    if showRadius ~= false and self.radius > 0 then
        love.graphics.setColor(1, 0.2, 0.2, 0.5)
        love.graphics.circle("line", self.x, self.y, self.radius)
    end

    -- Tâm điểm
    love.graphics.setColor(0, 1, 0, 0.9)
    love.graphics.circle("fill", self.x, self.y, 2)

    -- ID label
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.print("E#" .. self.id, self.x + 4, self.y - 12)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

--- Trả về chuỗi mô tả Entity để in log.
---@return string
function Entity:__tostring()
    return string.format("[Entity#%d '%s'] x=%.1f y=%.1f alive=%s",
        self.id,
        self.class.name,
        self.x, self.y,
        tostring(self.isAlive))
end

return Entity
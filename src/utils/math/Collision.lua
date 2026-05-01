-- src/utils/math/Collision.lua
-- ============================================================
--  Collision — Hệ thống va chạm OOP tái sử dụng
--
--  Thiết kế: Tách hoàn toàn khỏi từng entity cụ thể.
--  Player, Boss, Enemy, Bullet đều dùng chung module này.
--
--  Hai lớp API:
--    1. Static pure functions  — test hình học thuần túy,
--       không biết entity là gì, zero allocation.
--       Dùng trong hot loop (bullet hell, melee range check).
--
--    2. Entity-aware helpers   — nhận table entity có
--       {x, y, radius / width, height}, tự chọn shape phù hợp.
--       Dùng cho high-level game logic (CombatManager, v.v.)
--
--  Spatial hash grid (broad-phase) được giữ nguyên từ
--  CollisionSystem.lua gốc — module này KHÔNG duplicate,
--  chỉ bổ sung lớp OOP và melee-specific helpers.
--
--  Yêu cầu: CollisionSystem.lua vẫn tồn tại và được load
--  bởi CombatManager / BulletManager như cũ.
-- ============================================================

local Collision = {}

-- ────────────────────────────────────────────────────────────
--  1. STATIC PURE FUNCTIONS
--  Không tạo table, không GC — an toàn trong inner loop
-- ────────────────────────────────────────────────────────────

-- ── Circle vs Circle ─────────────────────────────────────────

---Kiểm tra 2 hình tròn có chồng nhau không.
---Đây là test phổ biến nhất trong Danmaku / melee range check.
---@param ax number   Tâm A x
---@param ay number   Tâm A y
---@param ar number   Bán kính A
---@param bx number   Tâm B x
---@param by number   Tâm B y
---@param br number   Bán kính B
---@return boolean
function Collision.circleCircle(ax, ay, ar, bx, by, br)
    local dx   = ax - bx
    local dy   = ay - by
    local sumR = ar + br
    return (dx * dx + dy * dy) <= (sumR * sumR)
end

---Khoảng cách bình phương giữa 2 tâm (tránh sqrt).
---Dùng khi cần so sánh nhiều target để chọn gần nhất.
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number
function Collision.distSq(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return dx * dx + dy * dy
end

---Khoảng cách thực giữa 2 điểm.
---@param ax number
---@param ay number
---@param bx number
---@param by number
---@return number
function Collision.dist(ax, ay, bx, by)
    local dx = ax - bx
    local dy = ay - by
    return math.sqrt(dx * dx + dy * dy)
end

---Kiểm tra điểm có nằm trong hình tròn không.
---Dùng cho: click detection, spell area, AoE.
---@param px number  Điểm x
---@param py number  Điểm y
---@param cx number  Tâm x
---@param cy number  Tâm y
---@param cr number  Bán kính
---@return boolean
function Collision.pointInCircle(px, py, cx, cy, cr)
    local dx = px - cx
    local dy = py - cy
    return (dx * dx + dy * dy) <= (cr * cr)
end

-- ── AABB vs AABB ─────────────────────────────────────────────

---Kiểm tra 2 hình chữ nhật căn trục có chồng nhau không.
---Tọa độ là góc trên-trái (left, top).
---@param ax number  Left A
---@param ay number  Top A
---@param aw number  Width A
---@param ah number  Height A
---@param bx number  Left B
---@param by number  Top B
---@param bw number  Width B
---@param bh number  Height B
---@return boolean
function Collision.aabbAabb(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and ax + aw > bx
       and ay < by + bh and ay + ah > by
end

---Kiểm tra điểm có nằm trong AABB không.
---@param px number
---@param py number
---@param rx number  Left
---@param ry number  Top
---@param rw number  Width
---@param rh number  Height
---@return boolean
function Collision.pointInAabb(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw
       and py >= ry and py <= ry + rh
end

-- ── Circle vs AABB ───────────────────────────────────────────

---Kiểm tra hình tròn có chồng với AABB không.
---Tọa độ rect là góc trên-trái.
---@param cx number  Tâm circle x
---@param cy number  Tâm circle y
---@param cr number  Bán kính
---@param rx number  Left rect
---@param ry number  Top rect
---@param rw number  Width rect
---@param rh number  Height rect
---@return boolean
function Collision.circleAabb(cx, cy, cr, rx, ry, rw, rh)
    local nearX = math.max(rx, math.min(cx, rx + rw))
    local nearY = math.max(ry, math.min(cy, ry + rh))
    local dx    = cx - nearX
    local dy    = cy - nearY
    return (dx * dx + dy * dy) <= (cr * cr)
end

-- ── Raycast ──────────────────────────────────────────────────

---Raycast: kiểm tra tia có giao với hình tròn không.
---Dùng cho: laser attack, line-of-sight check, sword slash ray.
---@param ox  number   Gốc ray x
---@param oy  number   Gốc ray y
---@param dx  number   Hướng ray x (đã normalize)
---@param dy  number   Hướng ray y (đã normalize)
---@param len number   Độ dài tia
---@param cx  number   Tâm circle x
---@param cy  number   Tâm circle y
---@param cr  number   Bán kính circle
---@return boolean hit
---@return number  distance  Khoảng cách từ gốc đến điểm giao (math.huge nếu không hit)
function Collision.rayCircle(ox, oy, dx, dy, len, cx, cy, cr)
    local fx   = cx - ox
    local fy   = cy - oy
    local proj = math.max(0, math.min(len, fx * dx + fy * dy))
    local nx   = ox + dx * proj
    local ny   = oy + dy * proj
    local ex   = cx - nx
    local ey   = cy - ny
    if ex * ex + ey * ey <= cr * cr then
        return true, proj
    end
    return false, math.huge
end

-- ────────────────────────────────────────────────────────────
--  2. ENTITY-AWARE HELPERS
--  Entity cần có: x, y, và (radius > 0) HOẶC (width, height)
--  Tọa độ entity là TÂM sprite (không phải top-left).
-- ────────────────────────────────────────────────────────────

---Tự động chọn test phù hợp dựa trên shape của entity.
---Ưu tiên circle nếu có radius > 0 (chuẩn Danmaku).
---@param a table  {x, y, radius?} hoặc {x, y, width, height}
---@param b table
---@return boolean
function Collision.check(a, b)
    local aCircle = (a.radius or 0) > 0
    local bCircle = (b.radius or 0) > 0

    if aCircle and bCircle then
        return Collision.circleCircle(
            a.x, a.y, a.radius,
            b.x, b.y, b.radius)

    elseif aCircle then
        local hw = (b.width  or 0) * 0.5
        local hh = (b.height or 0) * 0.5
        return Collision.circleAabb(
            a.x, a.y, a.radius,
            b.x - hw, b.y - hh, b.width or 0, b.height or 0)

    elseif bCircle then
        local hw = (a.width  or 0) * 0.5
        local hh = (a.height or 0) * 0.5
        return Collision.circleAabb(
            b.x, b.y, b.radius,
            a.x - hw, a.y - hh, a.width or 0, a.height or 0)

    else
        local ahw = (a.width  or 0) * 0.5
        local ahh = (a.height or 0) * 0.5
        local bhw = (b.width  or 0) * 0.5
        local bhh = (b.height or 0) * 0.5
        return Collision.aabbAabb(
            a.x - ahw, a.y - ahh, a.width  or 0, a.height or 0,
            b.x - bhw, b.y - bhh, b.width  or 0, b.height or 0)
    end
end

---Trả về entity đầu tiên trong list va chạm với entity.
---@param entity table
---@param list   table    Array of entities
---@param filter function? filter(other) → bool
---@return table|nil
function Collision.firstHit(entity, list, filter)
    for _, other in ipairs(list) do
        if other ~= entity and other.isActive ~= false then
            if (not filter or filter(other)) and Collision.check(entity, other) then
                return other
            end
        end
    end
    return nil
end

---Trả về tất cả entity trong list va chạm với entity.
---@param entity table
---@param list   table
---@param filter function?
---@return table  Array of colliding entities
function Collision.allHits(entity, list, filter)
    local hits = {}
    for _, other in ipairs(list) do
        if other ~= entity and other.isActive ~= false then
            if (not filter or filter(other)) and Collision.check(entity, other) then
                table.insert(hits, other)
            end
        end
    end
    return hits
end

---Trả về tất cả entity trong list nằm trong phạm vi radius từ điểm (x, y).
---Dùng cho: AoE skill, bomb clear, melee sweep.
---@param x      number
---@param y      number
---@param radius number
---@param list   table
---@param filter function?
---@return table
function Collision.inRadius(x, y, radius, list, filter)
    local result = {}
    local r2     = radius * radius
    for _, entity in ipairs(list) do
        if entity.isActive ~= false then
            local dx = entity.x - x
            local dy = entity.y - y
            if dx * dx + dy * dy <= r2 then
                if not filter or filter(entity) then
                    table.insert(result, entity)
                end
            end
        end
    end
    return result
end

---Trả về entity gần nhất trong list (hoặc nil nếu list rỗng).
---Dùng cho: melee auto-target, homing projectile seed.
---@param x      number   Điểm tham chiếu x
---@param y      number   Điểm tham chiếu y
---@param list   table    Array of entities
---@param filter function? filter(entity) → bool
---@return table|nil  entity gần nhất
---@return number     khoảng cách bình phương (math.huge nếu nil)
function Collision.nearest(x, y, list, filter)
    local best     = nil
    local bestDistSq = math.huge
    for _, entity in ipairs(list) do
        if entity.isActive ~= false then
            if not filter or filter(entity) then
                local dx = entity.x - x
                local dy = entity.y - y
                local d2 = dx * dx + dy * dy
                if d2 < bestDistSq then
                    bestDistSq = d2
                    best       = entity
                end
            end
        end
    end
    return best, bestDistSq
end

-- ────────────────────────────────────────────────────────────
--  3. MELEE-SPECIFIC HELPERS
--  Dành riêng cho combat cận chiến của Player
--  (tái sử dụng được cho Enemy melee nếu cần)
-- ────────────────────────────────────────────────────────────

---Kiểm tra entity có nằm trong vùng tấn công melee không.
---Vùng tấn công là một cung (arc) trước mặt attacker.
---
---  attackerAngle: hướng nhìn/tấn công (radian, từ atan2)
---  arcHalf: nửa góc cung (radian). VD: math.pi/3 = cung 120°
---  range: bán kính tấn công (pixel)
---
---Dùng cho: Player click trái → check enemy/boss trong arc.
---@param ax          number  Attacker x
---@param ay          number  Attacker y
---@param attackAngle number  Hướng tấn công (radian)
---@param arcHalf     number  Nửa góc cung (radian)
---@param range       number  Bán kính tối đa
---@param tx          number  Target x
---@param ty          number  Target y
---@param tr          number  Target radius (0 nếu point)
---@return boolean
function Collision.inMeleeArc(ax, ay, attackAngle, arcHalf, range, tx, ty, tr)
    -- Bước 1: kiểm tra khoảng cách (circle check nhanh trước)
    local dx     = tx - ax
    local dy     = ty - ay
    local distSq = dx * dx + dy * dy
    local maxR   = range + tr
    if distSq > maxR * maxR then return false end

    -- Bước 2: kiểm tra góc nằm trong cung
    local angle   = math.atan2(dy, dx)
    local diff    = angle - attackAngle

    -- Wrap diff về [-π, π] (Dùng if để tránh treo game nếu diff là Inf)
    if diff >  math.pi then diff = diff - 2 * math.pi end
    if diff < -math.pi then diff = diff + 2 * math.pi end

    return math.abs(diff) <= arcHalf
end

---Kiểm tra nhanh: entity có trong phạm vi melee hình tròn không.
---Phiên bản đơn giản hơn inMeleeArc — không cần hướng nhìn.
---Dùng khi melee là "vùng xung quanh" thay vì arc định hướng.
---@param ax    number  Attacker x
---@param ay    number  Attacker y
---@param range number  Bán kính
---@param tx    number  Target x
---@param ty    number  Target y
---@param tr    number  Target radius
---@return boolean
function Collision.inMeleeRange(ax, ay, range, tx, ty, tr)
    local dx = tx - ax
    local dy = ty - ay
    local maxR = range + tr
    return (dx * dx + dy * dy) <= (maxR * maxR)
end

---Tìm tất cả target trong vùng melee arc từ list.
---Trả về array sắp xếp theo khoảng cách gần nhất.
---@param ax          number
---@param ay          number
---@param attackAngle number
---@param arcHalf     number
---@param range       number
---@param list        table   Array of entities
---@param filter      function? filter(entity) → bool
---@return table  Array of {entity, distSq} sắp xếp gần → xa
function Collision.meleeTargets(ax, ay, attackAngle, arcHalf, range, list, filter)
    local result = {}
    for _, entity in ipairs(list) do
        if entity.isActive ~= false and not entity.isDead then
            if not filter or filter(entity) then
                local tr = entity.hitboxRadius or entity.radius or 0
                if Collision.inMeleeArc(ax, ay, attackAngle, arcHalf, range, entity.x, entity.y, tr) then
                    local dx = entity.x - ax
                    local dy = entity.y - ay
                    table.insert(result, { entity = entity, distSq = dx*dx + dy*dy })
                end
            end
        end
    end
    -- Sắp xếp gần → xa
    table.sort(result, function(a, b) return a.distSq < b.distSq end)
    return result
end

-- ────────────────────────────────────────────────────────────
--  4. SCREEN BOUNDS
-- ────────────────────────────────────────────────────────────

---Kiểm tra entity có nằm ngoài màn hình không.
---Dùng để cull bullet, despawn enemy ra ngoài view.
---@param entity table  {x, y, radius?}
---@param margin number? Lề thêm (mặc định 32)
---@return boolean  true nếu NGOÀI biên
function Collision.isOutOfBounds(entity, margin)
    margin  = margin or 32
    local r = entity.radius or 0
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()
    return entity.x + r < -margin
        or entity.x - r > W + margin
        or entity.y + r < -margin
        or entity.y - r > H + margin
end

---Clamp entity vào trong màn hình.
---MUTATEs entity.x và entity.y.
---@param entity table   {x, y, width?, height?, radius?}
---@param margin number? Lề (mặc định 8)
function Collision.clampToScreen(entity, margin)
    margin   = margin or 8
    local W  = love.graphics.getWidth()
    local H  = love.graphics.getHeight()
    local r  = entity.radius or 0
    local hw = entity.width  and entity.width  * 0.5 or r
    local hh = entity.height and entity.height * 0.5 or r

    entity.x = math.max(margin + hw, math.min(W - margin - hw, entity.x))
    entity.y = math.max(margin + hh, math.min(H - margin - hh, entity.y))
end

-- ────────────────────────────────────────────────────────────
--  5. DEBUG DRAW
-- ────────────────────────────────────────────────────────────

---Vẽ hitbox của entity (debug).
---@param entity table
---@param color  table?  {r,g,b,a} mặc định đỏ
function Collision.drawHitbox(entity, color)
    color = color or { 1, 0.2, 0.2, 0.7 }
    love.graphics.push()
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.7)
    love.graphics.setLineWidth(1)

    if (entity.hitboxRadius or 0) > 0 then
        love.graphics.circle("line", entity.x, entity.y, entity.hitboxRadius)
    elseif (entity.radius or 0) > 0 then
        love.graphics.circle("line", entity.x, entity.y, entity.radius)
    elseif entity.width and entity.height then
        love.graphics.rectangle("line",
            entity.x - entity.width  * 0.5,
            entity.y - entity.height * 0.5,
            entity.width, entity.height)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

---Vẽ melee arc để debug (gọi từ Player:drawDebug).
---@param ax          number
---@param ay          number
---@param attackAngle number
---@param arcHalf     number
---@param range       number
---@param color       table?  {r,g,b,a}
function Collision.drawMeleeArc(ax, ay, attackAngle, arcHalf, range, color)
    color = color or { 1, 0.6, 0, 0.4 }
    love.graphics.push()
    love.graphics.setColor(color[1], color[2], color[3], color[4] or 0.4)
    love.graphics.setLineWidth(1)

    local startAngle = attackAngle - arcHalf
    local endAngle   = attackAngle + arcHalf

    -- Vẽ cung arc
    love.graphics.arc("line", "open", ax, ay, range, startAngle, endAngle)

    -- Vẽ 2 cạnh bên
    love.graphics.line(ax, ay,
        ax + math.cos(startAngle) * range,
        ay + math.sin(startAngle) * range)
    love.graphics.line(ax, ay,
        ax + math.cos(endAngle) * range,
        ay + math.sin(endAngle) * range)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

-- ────────────────────────────────────────────────────────────
--  EXPORT
-- ────────────────────────────────────────────────────────────

--[[
  VÍ DỤ SỬ DỤNG:

  local Collision = require 'src.utils.math.Collision'

  -- Melee range check (Player click trái):
  local angle   = math.atan2(mouseY - player.y, mouseX - player.x)
  local targets = Collision.meleeTargets(
      player.x, player.y,
      angle,
      math.pi / 2.5,    -- cung 144°
      60,               -- range 60px
      combatManager:getEnemies()
  )
  for _, hit in ipairs(targets) do
      hit.entity:takeDamage(player.meleeDamage)
  end

  -- Bullet vs player (hot loop — dùng circleCircle raw):
  if Collision.circleCircle(bx, by, br, player.x, player.y, player.hitboxRadius) then
      player:takeDamage(1)
  end

  -- Clamp player vào màn hình:
  Collision.clampToScreen(player, 8)
--]]

return Collision
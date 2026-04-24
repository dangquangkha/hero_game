-- your-game/src/entities/bosses/Boss.lua

local class = require 'libs.middleclass.middleclass' -- Đảm bảo bạn đã cài đặt thư viện middleclass
-- Import lớp cha Actor nếu có (nếu không thì Boss sẽ là lớp cơ sở)
-- Import component quản lý phase
local BossPhaseManager = require 'src.entities.bosses.BossPhaseManager'

-- Khởi tạo class Boss (Lý tưởng nhất là nó kế thừa từ Actor.lua, nhưng ở đây ta dựng Base Boss)
local Boss = class('Boss')

function Boss:initialize(x, y, combatManager, maxHp)
    self.x = x
    self.y = y
    self.combatManager = combatManager
    
    -- Chỉ số sinh tồn cơ bản
    self.maxHp = maxHp or 1000
    self.hp = self.maxHp
    self.isDead = false
    
    -- Quản lý trạng thái
    self.state = "idle" -- "idle", "attacking", "transitioning"
    
    -- Quản lý nhịp độ đánh
    self.attackCooldown = 2.0 -- Mặc định 2s
    self.attackTimer = 0
    self.currentAttackIndex = 1
    
    -- Gắn Component Phase Manager vào Boss
    self.phaseManager = BossPhaseManager(self)
    
    -- Thiết lập các ngưỡng máu mặc định (Lớp con có thể ghi đè lại nếu muốn)
    self.phaseManager:setThresholds({
        {hpRatio = 0.66, phase = 2},
        {hpRatio = 0.33, phase = 3}
    })
end

function Boss:update(dt)
    if self.isDead then return end

    -- Ủy quyền cho Phase Manager kiểm tra máu và tự động gọi Hook đổi Phase nếu cần
    self.phaseManager:update()

    -- Nếu đang diễn cảnh chuyển phase thì boss không bắn đạn
    if self.state == "transitioning" then return end

    -- Đếm ngược để gọi đòn tấn công
    self.attackTimer = self.attackTimer + dt
    if self.attackTimer >= self.attackCooldown then
        self.attackTimer = 0
        self:castAttack() -- Hàm ảo sẽ do lớp con quyết định
    end
end

-- Hàm nhận sát thương (CombatManager sẽ gọi hàm này)
function Boss:takeDamage(amount)
    if self.isDead then return end
    
    self.hp = self.hp - amount
    if self.hp <= 0 then
        self.hp = 0
        self.isDead = true
    end
end

-- Lấy Phase hiện tại từ Manager
function Boss:getCurrentPhase()
    return self.phaseManager:getCurrentPhase()
end

-- ==================================================
-- CÁC HÀM ẢO & HOOKS (Dành cho lớp con ghi đè)
-- ==================================================

-- Hàm này tự động được BossPhaseManager gọi khi tới ngưỡng máu
function Boss:onPhaseChange(newPhase)
    self.state = "transitioning"
    self.currentAttackIndex = 1
    
    -- Mặc định: Dọn sạch đạn cũ trên màn hình mỗi khi qua Phase mới
    if self.combatManager and self.combatManager.bulletManager then
        self.combatManager.bulletManager:clear()
    end
    
    -- Lớp con (DemonKing) sẽ gọi override hàm này để cấu hình thêm (ví dụ: đổi cooldown, đổi màu)
    -- Giả lập việc đợi diễn hoạt ảnh 3s ở đây (Trong thực tế bạn dùng timer.lua)
    self.state = "idle" 
end

function Boss:castAttack()
    -- Lớp con bắt buộc phải ghi đè hàm này để gắn BulletPatterns
    error("Subclasses must implement castAttack()")
end

function Boss:draw()
    -- Lớp con sẽ tự vẽ hình ảnh của riêng nó
end

return Boss
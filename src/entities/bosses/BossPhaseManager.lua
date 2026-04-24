-- your-game/src/entities/bosses/BossPhaseManager.lua

local class = require 'libs.middleclass'

local BossPhaseManager = class('BossPhaseManager')

function BossPhaseManager:initialize(boss)
    self.boss = boss -- Lưu tham chiếu tới Boss đang sở hữu Component này
    self.currentPhase = 1
    self.thresholds = {} 
    -- Cấu trúc thresholds: { {hpRatio = 0.66, phase = 2}, {hpRatio = 0.33, phase = 3} }
end

-- Hàm để Boss truyền vào các mốc máu chuyển phase
function BossPhaseManager:setThresholds(thresholds)
    self.thresholds = thresholds
end

-- Hàm này sẽ được Boss gọi mỗi frame trong update() của nó
function BossPhaseManager:update()
    if self.boss.isDead then return end

    -- Tính toán phần trăm máu hiện tại
    local hpRatio = self.boss.hp / self.boss.maxHp

    -- Kiểm tra các ngưỡng máu (Lặp từ Phase lớn nhất xuống)
    for i = #self.thresholds, 1, -1 do
        local t = self.thresholds[i]
        -- Nếu máu rớt xuống dưới mốc VÀ chưa ở Phase đó thì kích hoạt
        if hpRatio <= t.hpRatio and self.currentPhase < t.phase then
            self:changePhase(t.phase)
            break
        end
    end
end

-- Xử lý đổi Phase
function BossPhaseManager:changePhase(newPhase)
    self.currentPhase = newPhase
    
    -- Kích hoạt sự kiện (Hook) trên Boss để Boss tự dọn dẹp đạn, chuyển hoạt ảnh, tăng tốc độ...
    if self.boss.onPhaseChange then
        self.boss:onPhaseChange(newPhase)
    end
end

-- Trả về Phase hiện tại để Boss biết đường xả chiêu
function BossPhaseManager:getCurrentPhase()
    return self.currentPhase
end

return BossPhaseManager
local Gamestate    = require 'libs.hump.gamestate'
-- Đã xóa require BattleScreen ở đây để tránh Circular Dependency

local GameOverScreen = {}

-- ============================================================
--  CẤU HÌNH
-- ============================================================

local CONFIG = {
    TITLE          = "GAME OVER",
    TITLE_X        = love.graphics.getWidth() * 0.5,
    TITLE_Y        = love.graphics.getHeight() * 0.4,
    TITLE_COLOR    = { 1, 0.3, 0.3 },

    HINT_PRESS_START = "Bấm phím bất kỳ để thử lại",
    HINT_X         = love.graphics.getWidth() * 0.5,
    HINT_Y         = love.graphics.getHeight() * 0.6,
    HINT_COLOR     = { 0.8, 0.8, 0.8 },
}

-- ============================================================
--  enter
-- ============================================================

function GameOverScreen:enter(prev, params)
    print("[GameOverScreen] enter")
    
    -- Load default fonts to avoid FT_New_Face errors
    self.fontTitle = love.graphics.newFont(48)
    self.fontHint  = love.graphics.newFont(16)

    if prev then
        print("[GameOverScreen] Previous screen: " .. tostring(type(prev)) .. " class=" .. tostring(prev.class or "none"))
    end
    
    -- Bắt buộc phải lưu params nếu cần tái sử dụng
    self.params = params
end

-- ============================================================
--  draw
-- ============================================================

function GameOverScreen:draw()
    local W = love.graphics.getWidth()
    local H = love.graphics.getHeight()

    -- 1. Vẽ background
    love.graphics.clear(0.1, 0.05, 0.05)

    -- 2. Vẽ title
    love.graphics.setColor(CONFIG.TITLE_COLOR)
    if self.fontTitle then love.graphics.setFont(self.fontTitle) end
    love.graphics.printf(CONFIG.TITLE, 0, CONFIG.TITLE_Y, W, "center")

    -- 3. Vẽ hint
    love.graphics.setColor(CONFIG.HINT_COLOR)
    if self.fontHint then love.graphics.setFont(self.fontHint) end
    love.graphics.printf(CONFIG.HINT_PRESS_START, 0, CONFIG.HINT_Y, W, "center")
end

-- ============================================================
--  keypressed
-- ============================================================

function GameOverScreen:keypressed(key)
    print("[GameOverScreen] keypressed: " .. tostring(key))
    
    local BattleScreen = require 'src.screens.BattleScreen'
    Gamestate.switch(BattleScreen, self.params)
end

-- ============================================================
--  mousepressed
-- ============================================================

function GameOverScreen:mousepressed(x, y, button, istouch, presses)
    print("[GameOverScreen] mousepressed: " .. tostring(button))
    
    local BattleScreen = require 'src.screens.BattleScreen'
    Gamestate.switch(BattleScreen, self.params)
end

-- ============================================================
--  Return
-- ============================================================

return GameOverScreen
Gamestate    = require 'libs.hump.gamestate'
BattleScreen = require 'src.screens.BattleScreen'

function love.update(dt)
    local status, err = pcall(function()
        Gamestate.update(dt)
    end)
    if not status then
        print("\n[CRITICAL ERROR IN UPDATE]")
        print(err)
        love.event.quit()
    end
end

function love.draw()
    local status, err = pcall(function()
        Gamestate.draw()
    end)
    if not status then
        print("\n[CRITICAL ERROR IN DRAW]")
        print(err)
        love.event.quit()
    end
end

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    -- Vào thẳng BattleScreen
    Gamestate.switch(BattleScreen)
end

function love.mousepressed(x, y, button, istouch, presses)
    Gamestate.mousepressed(x, y, button, istouch, presses)
end

function love.mousereleased(x, y, button, istouch, presses)
    Gamestate.mousereleased(x, y, button, istouch, presses)
end

function love.keypressed(key)
    if key == "q" and love.keyboard.isDown("lctrl") then
        love.event.quit()
    end
    Gamestate.keypressed(key)
end

function love.keyreleased(key)
    Gamestate.keyreleased(key)
end

-- ────────────────────────────────────────────────────────────
--  ERROR HANDLER
--  Không relay qua registerEvents() — hump tự bỏ qua errorhandler
--  (xem comment trong gamestate.lua: "don't overwrite love.errorhandler")
-- ────────────────────────────────────────────────────────────

function love.errorhandler(msg)
    print("\n╔══════════════════════════════════════╗")
    print("║           LOVE2D ERROR               ║")
    print("╚══════════════════════════════════════╝")
    print(msg)
    print(debug.traceback("", 2))

    return function()
        love.event.pump()
        for e, a, b, c in love.event.poll() do
            if e == "quit"      then return 1 end
            if e == "keypressed" and a == "escape" then return 1 end
        end

        love.graphics.clear(0.1, 0.05, 0.05)
        love.graphics.setColor(1, 0.3, 0.3)
        love.graphics.print("ERROR:", 20, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(msg, 20, 45, love.graphics.getWidth() - 40)
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.print("[ESC] để thoát", 20, love.graphics.getHeight() - 30)
        love.graphics.present()
    end
end

--[[
==============================================================
  SƠ ĐỒ RELAY INPUT (sau registerEvents)
==============================================================

  Người dùng nhấn phím / chuột
       ↓
  love.keypressed(key)          ← hàm gốc khai báo ở bước 1
       ↓  (wrap bởi registerEvents)
  GS.keypressed(key)            ← Gamestate relay
       ↓
  BattleScreen:keypressed(key)  ← screen hiện tại nhận
       ↓
  player:keypressed(key)        ← Player xử lý

  Tương tự cho mousepressed, mousereleased, update, draw...

==============================================================
  BattleScreen CẦN CÓ CÁC HÀM NÀY để player nhận input:
==============================================================

  function BattleScreen:keypressed(key)
      self.player:keypressed(key)
  end

  function BattleScreen:keyreleased(key)
      self.player:keyreleased(key)
  end

  -- BẮT BUỘC cho mouse-driven player:
  function BattleScreen:mousepressed(x, y, button)
      self.player:mousepressed(x, y, button)
  end

  function BattleScreen:mousereleased(x, y, button)
      self.player:mousereleased(x, y, button)
  end

==============================================================
  THÊM SCREEN MỚI
==============================================================

  local DragonLord = require 'src.entities.bosses.types.DragonLord'
  Gamestate.switch(BattleScreen, { bossClass = DragonLord })

==============================================================
  LUỒNG SCREEN ĐẦY ĐỦ (khi có các screen khác)
==============================================================

  love.load → SplashScreen
           → MainMenu
           → BattleScreen ──push──→ PauseMenu
                          ←──pop───
                          ──switch──→ VictoryScreen
                          ──switch──→ GameOverScreen
--]]
-- your-game/conf.lua
-- ============================================================
--  LÖVE2D Configuration
--  Chạy TRƯỚC main.lua — cấu hình window, modules, identity.
--  Tài liệu: https://love2d.org/wiki/Config_Files
-- ============================================================

function love.conf(t)

    -- ── Thông tin game ────────────────────────────────────────
    t.identity    = "your-game"        -- Tên thư mục save data
    t.version     = "11.4"             -- Phiên bản LÖVE tối thiểu
    t.console     = true               -- Windows: bật cmd console khi debug

    -- ── Cửa sổ ───────────────────────────────────────────────
    t.window.title        = "Your Game — Bullet Hell RPG"
    t.window.icon         = nil        -- "assets/images/ui/icon.png" khi có
    t.window.width        = 800
    t.window.height       = 600
    t.window.resizable    = false
    t.window.fullscreen   = false
    t.window.vsync        = 1          -- 1 = bật VSync (cap 60fps)
    t.window.minwidth     = 800
    t.window.minheight    = 600
    t.window.x            = nil        -- nil = căn giữa màn hình
    t.window.y            = nil

    -- ── Modules (tắt những gì không dùng để tiết kiệm RAM) ───
    t.modules.audio      = true
    t.modules.data       = true
    t.modules.event      = true
    t.modules.font       = true
    t.modules.graphics   = true
    t.modules.image      = true
    t.modules.joystick   = false       -- Bật khi hỗ trợ gamepad
    t.modules.keyboard   = true
    t.modules.math       = true
    t.modules.mouse      = true
    t.modules.physics    = false       -- Không dùng Box2D
    t.modules.sound      = true
    t.modules.system     = true
    t.modules.thread     = false
    t.modules.timer      = true
    t.modules.touch      = false
    t.modules.video      = false
    t.modules.window     = true

end
-- scratch/test_player.lua
-- Unit test độc lập để cô lập lỗi treo trong Player:update

-- 1. Mock Love2D environment
love = {
    mouse = { getPosition = function() return 400, 300 end },
    keyboard = { isDown = function() return false end },
    graphics = { getWidth = function() return 800 end, getHeight = function() return 600 end },
    timer = { getTime = function() return 0 end }
}

-- 2. Load dependencies (Mocking what's not needed)
local class = require 'libs.middleclass.middleclass'
Vector2     = require 'src.utils.math.Vector2'

-- Mock components that Player depends on
local StateMachine = class('StateMachine')
function StateMachine:initialize() end
function StateMachine:update() end

local PlayerAbilities = class('PlayerAbilities')
function PlayerAbilities:initialize() end
function PlayerAbilities:update() end

-- Mock Actor (base class)
Actor = class('Actor')
function Actor:initialize(x, y)
    self.x, self.y = x, y
    self.isActive = true
    self._iFramesTimer = 0
end
function Actor:update(dt) 
    print("  [Actor] update start")
    if self._iFramesTimer > 0 then self._iFramesTimer = self._iFramesTimer - dt end
    print("  [Actor] update end")
end

-- 3. Load Player (monkey-patching requires to use mocks)
local Player = require 'src.entities.player.Player'

-- 4. Execute Test
print("Starting Player:update test...")
local mockCM = {}
local p = Player(400, 500, mockCM, {})
p.isActive = true

print("Running first update frame...")
local dt = 0.016
p:update(dt)
print("Update finished successfully!")

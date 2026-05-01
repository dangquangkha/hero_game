local VictoryScreen = {}
function VictoryScreen:enter(prev, params) end
function VictoryScreen:draw()
    love.graphics.print("VICTORY!", 350, 280)
end
return VictoryScreen
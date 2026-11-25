-- Линия BEC целиком: энтанглер + Поле слева, затвор, Матрица + узлы справа.
-- Порядок тика: энтанглер, Поле, Матрица (питание узлов), узлы.
local Storage = require("sim.storage")
local Diode = require("sim.diode")
local Assembler = require("sim.assembler")
local Node = require("sim.node")
local Entangler = require("sim.entangler")

local W = {}
W.__index = W

-- o = {fieldStrength, assemblerEu, entanglerEu, nodes = k, filterSlots}
function W.new(o)
  local w = setmetatable({t = 0, onTick = nil}, W)
  w.storage = Storage.new(o.fieldStrength or 1)
  w.diode = Diode.new(o.filterSlots or 19)
  w.asm = Assembler.new(o.assemblerEu or 0)
  w.ent = Entangler.new(o.entanglerEu or 0, function(t, a) w.storage:add(t, a) end)
  local net = {asm = w.asm}
  -- типы в Поле, видимые справа через затвор, не входящие в рецепт
  function net.slowdowns(required)
    local n = 0
    for t in pairs(w.storage.contents) do
      if w.diode:allows(t) and required[t] == nil then n = n + 1 end
    end
    return n
  end
  function net.drain(t, a)
    if not w.diode:allows(t) then return 0 end
    return w.storage:remove(t, a)
  end
  w.net = net
  w.nodes = {}
  for i = 1, (o.nodes or 1) do w.nodes[i] = Node.new(net) end
  w.asm.nodes = w.nodes
  return w
end

function W:tick()
  self.t = self.t + 1
  self.ent:tick()
  self.storage:tick()
  self.asm:postTick()
  for _, n in ipairs(self.nodes) do n:tick() end
  if self.onTick then self.onTick(self) end
end

function W:run(maxTicks, untilFn)
  for _ = 1, maxTicks do
    self:tick()
    if untilFn and untilFn(self) then return true end
  end
  return false
end

function W:allIdle()
  for _, n in ipairs(self.nodes) do if n:crafting() then return false end end
  return true
end

return W

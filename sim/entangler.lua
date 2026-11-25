-- Энтанглер (MTEBECGenerator): цикл по model/entangler.cycle, выход в конце цикла в левую сеть.
local model = require("model.entangler")

local E = {}
E.__index = E

function E.new(maxPower, inject)
  return setmetatable({maxPower = maxPower, inputs = {}, inject = inject, progress = 0, maxProgress = 0,
    allowed = true, cycles = 0, eu = 0}, E)
end

function E:feed(t, amount) self.inputs[t] = (self.inputs[t] or 0) + amount end

function E:tick()
  if self.maxProgress == 0 then
    if not self.allowed then return end
    local c = model.cycle(self.inputs, self.maxPower)
    if not c then return end
    for t, v in pairs(c.used) do
      local left = self.inputs[t] - v
      self.inputs[t] = left > 0 and left or nil
    end
    self.cur, self.progress, self.maxProgress = c, 0, c.dur
  end
  self.progress = self.progress + 1
  self.eu = self.eu + self.cur.eut
  if self.progress >= self.maxProgress then
    for t, v in pairs(self.cur.out) do self.inject(t, v) end
    self.cycles = self.cycles + 1
    self.cur, self.progress, self.maxProgress = nil, 0, 0
  end
end

return E

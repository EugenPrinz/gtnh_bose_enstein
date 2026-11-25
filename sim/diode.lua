-- Maxwell Gate (MTEBECDiode): правая сеть видит левую только пока затвор работает.
-- Фильтры: пустой список = пропускать всё.
local D = {}
D.__index = D

function D.new(slots)
  return setmetatable({slots = slots or 19, filters = {}, allowed = true, powered = true}, D)
end

function D:working() return self.allowed and self.powered end

-- filters: список типов (как setCondensateFilters)
function D:setFilters(list)
  assert(#list <= self.slots, "фильтров больше, чем слотов")
  self.filters = {}
  for _, t in ipairs(list) do self.filters[t] = true end
end

function D:allows(t)
  if not self:working() then return false end
  return next(self.filters) == nil or self.filters[t] == true
end

return D

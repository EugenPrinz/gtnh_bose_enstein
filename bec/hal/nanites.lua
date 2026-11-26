-- Извлечение нанитов из Матрицы (вариант A, как у Armisael5 — проверено в игре): Transposer между двумя IO Port.
-- В выходном слоте 12 одного порта — пустышка-метка («markerSide»), рабочая ячейка лежит в слоте 7 другого.
-- Ячейка в порт с меткой → он вытягивает наниты из шины (storage bus Extract Only) → ячейка обратно → выгрузка в подсеть.
local G = require("hal.gtbase")

local N = {}
N.__index = N

N.CELL_SLOT, N.MARKER_SLOT = 7, 12

function N.new(component) return setmetatable({c = component}, N) end

-- Найти Transposer с меткой; запоминает {p, marker, other}
function N:find()
  for addr in self.c.list("transposer", true) do
    local p = self.c.proxy(addr)
    local sides, marker = {}, nil
    for side = 0, 5 do
      local size = G.call(p, "getInventorySize", side)
      if type(size) == "number" and size > 0 then
        sides[#sides + 1] = side
        if G.call(p, "getStackInSlot", side, N.MARKER_SLOT) then marker = side end
      end
    end
    if marker then
      local other
      for _, s in ipairs(sides) do if s ~= marker then other = s end end
      if other then self.t = {p = p, marker = marker, other = other}; return self.t end
    end
  end
  return nil, "не найден Transposer с меткой в слоте " .. N.MARKER_SLOT .. " IO Port подсети нанитов"
end

-- Перенести ячейку (слот 7) с повторами до timeout; sleep, now — из main
function N:move(from, to, sleep, now, timeout)
  local t0 = now()
  repeat
    local moved = G.call(self.t.p, "transferItem", from, to, 1, N.CELL_SLOT, 1)
    if moved == 1 then return true end
    sleep(0.05)
  until now() - t0 > (timeout or 2)
  return nil, "ячейка не переносится (слот " .. N.CELL_SLOT .. ", сторона " .. from .. ")"
end

-- Где ячейка: "rest" | "marker" | nil
function N:where()
  if not self.t then return nil end
  if G.call(self.t.p, "getStackInSlot", self.t.other, N.CELL_SLOT) then return "rest" end
  if G.call(self.t.p, "getStackInSlot", self.t.marker, N.CELL_SLOT) then return "marker" end
  return nil
end

-- После сбоя ячейка могла остаться в порту с меткой — вернуть
function N:recover(sleep, now, timeout)
  if not self.t then local ok, e = self:find(); if not ok then return nil, e end end
  local w = self:where()
  if w == "rest" then return true end
  if w == "marker" then return self:move(self.t.marker, self.t.other, sleep, now, timeout) end
  return nil, "нет рабочей ячейки ни в одном IO Port подсети нанитов"
end

-- Вытянуть все наниты из Матрицы в подсеть
function N:extract(sleep, now, timeout)
  if not self.t then local ok, e = self:find(); if not ok then return nil, e end end
  local ok, e = self:move(self.t.other, self.t.marker, sleep, now, timeout)
  if not ok then return nil, "в порт извлечения: " .. e end
  ok, e = self:move(self.t.marker, self.t.other, sleep, now, timeout)
  if not ok then return nil, "обратно: " .. e end
  return true
end

N.USES = {"getInventorySize", "getStackInSlot", "transferItem"}

return N

-- Извлечение нанитов из Матрицы (вариант A, как у Armisael5 — проверено в игре): Transposer между двумя IO Port.
-- В выходе 8…12 одного порта — пустышка-метка (порт извлечения), рабочая ячейка — в выходе 7 другого.
-- В выход руками не положить (AE2: вставка только во вход) — метку кладёт сам порт: 2 ячейки во вход, из 7 забрать.
-- Оба порта — «Move to output when work is done»: при 3 Superluminal один проход переносит всё, и ячейка выходит
-- даже с пустой шины (в режиме «when empty» она осталась бы во входе, а вход Transposer не разгружает).
-- Ячейка в порт с меткой → он вытягивает наниты из шины (storage bus Extract Only) → ячейка обратно → выгрузка в подсеть.
local G = require("hal.gtbase")

local N = {}
N.__index = N

N.CELL_SLOT, N.MARKER_FROM, N.MARKER_TO = 7, 8, 12

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
        for slot = N.MARKER_FROM, N.MARKER_TO do
          if G.call(p, "getStackInSlot", side, slot) then marker = side end
        end
      end
    end
    if marker then
      local other
      for _, s in ipairs(sides) do if s ~= marker then other = s end end
      if other then self.t = {p = p, marker = marker, other = other}; return self.t end
    end
  end
  return nil, "не найден Transposer с меткой (пустая ячейка в выходе 8–12 порта извлечения)"
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

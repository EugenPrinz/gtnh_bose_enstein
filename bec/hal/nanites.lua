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

-- Найти Transposer с меткой; запоминает {p, marker, other}. Transposer может касаться и посторонних
-- инвентарей: второй порт — сторона с ячейкой в слоте 7, иначе инвентарь того же размера, что порт с меткой.
function N:find()
  local seen = {}
  for addr in self.c.list("transposer", true) do
    local p = self.c.proxy(addr)
    local inv, marker = {}, nil
    for side = 0, 5 do
      local size = G.call(p, "getInventorySize", side)
      if type(size) == "number" and size > 0 then
        inv[side] = size
        if size >= N.MARKER_TO then
          for slot = N.MARKER_FROM, N.MARKER_TO do
            if G.call(p, "getStackInSlot", side, slot) then marker = side end
          end
        end
      end
    end
    local list = {}
    for side, size in pairs(inv) do list[#list + 1] = side .. ":" .. size end
    seen[#seen + 1] = addr:sub(1, 8) .. " [" .. table.concat(list, " ") .. "]"
    if marker then
      local other
      for side in pairs(inv) do
        if side ~= marker and G.call(p, "getStackInSlot", side, N.CELL_SLOT) then other = side end
      end
      if not other then
        for side, size in pairs(inv) do if side ~= marker and size == inv[marker] then other = side end end
      end
      if other then self.t = {p = p, marker = marker, other = other}; return self.t end
      return nil, "у Transposer " .. addr:sub(1, 8) .. " есть порт с меткой (сторона " .. marker .. "), второго IO Port нет"
    end
  end
  if #seen == 0 then return nil, "нет компонента transposer" end
  return nil, "не найден Transposer с меткой (пустая ячейка в выходе 8–12 порта извлечения); видно: " .. table.concat(seen, ", ")
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
  return nil, string.format("нет рабочей ячейки в выходе %d ни одного IO Port (метка — сторона %d, выгрузка — сторона %d)",
    N.CELL_SLOT, self.t.marker, self.t.other)
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

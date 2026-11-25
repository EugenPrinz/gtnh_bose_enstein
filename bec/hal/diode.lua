-- Maxwell Gate (bec_diode). Пустой список фильтров = пропускать всё, поэтому слот 1 всегда
-- занят фиктивным фильтром (по умолчанию вода): маршрут рецепта — слоты 2..n (DESIGN §1.1, инвариант 1).
local G = require("hal.gtbase")
local recipe = require("model.recipe")

local D = setmetatable({}, {__index = G.Base})
D.__index = D

function D.wrap(proxy, dummy)
  local o = G.wrap(proxy, D)
  o.dummy = dummy or "water"
  return o
end

function D:count() return self:call("getCondensateFilterCount") or 0 end

-- Фильтры по слотам: {[слот] = тип модели | имя жидкости}
function D:filters()
  local raw = self:call("getCondensateFilters")
  if type(raw) ~= "table" then return nil end
  local out = {}
  for slot, name in pairs(raw) do out[slot] = recipe.typeOfFluid(name) or name end
  return out
end

-- Таблица для setCondensateFilters: слот 1 — фиктивный, дальше типы по имени
function D:layout(types)
  local list = {}
  for _, t in ipairs(types) do list[#list + 1] = t end
  table.sort(list)
  local n = self:count()
  if #list + 1 > n then return nil, string.format("типов %d, а слотов под маршрут %d", #list, n - 1) end
  local tbl = {[1] = self.dummy}
  for i, t in ipairs(list) do
    if not recipe.condensates[t] then return nil, "неизвестный конденсат " .. tostring(t) end
    tbl[i + 1] = recipe.fluid(t)
  end
  return tbl
end

-- Маршрут рецепта. Применится со следующего тика — проверять check() позже.
function D:route(types)
  local tbl, err = self:layout(types)
  if not tbl then return nil, err end
  local _, e = self:call("setCondensateFilters", tbl)
  if e then return nil, e end
  return true
end

-- Закрыть маршрут: остаётся только фиктивный фильтр
function D:close() return self:route({}) end

-- Фильтры совпадают с маршрутом types? Возвращает true или false, описание расхождения
function D:check(types)
  local want, err = self:layout(types)
  if not want then return false, err end
  local raw = self:call("getCondensateFilters")
  if type(raw) ~= "table" then return false, "не читаются фильтры" end
  for slot = 1, self:count() do
    if raw[slot] ~= want[slot] then
      return false, string.format("слот %d: %s вместо %s", slot, tostring(raw[slot]), tostring(want[slot]))
    end
  end
  return true
end

-- Фиктивный фильтр на месте (иначе пустой список откроет всё)
function D:hasDummy()
  local raw = self:call("getCondensateFilters")
  return type(raw) == "table" and raw[1] == self.dummy
end

function D:snapshot()
  local s = G.Base.snapshot(self)
  s.slots, s.filters = self:count(), self:filters()
  return s
end

D.USES = {"getCondensateFilterCount", "getCondensateFilters", "setCondensateFilters"}

return D

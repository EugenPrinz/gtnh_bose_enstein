-- Containment Field (bec_storage). Инвариант 7: поле никогда не выключается — setAllowed(false) запрещён.
-- Инвариант 5: напряжённость меняется только между партиями и не ниже текущего объёма.
local G = require("hal.gtbase")
local recipe = require("model.recipe")

local S = setmetatable({}, {__index = G.Base})
S.__index = S

function S.wrap(proxy) return G.wrap(proxy, S) end

function S:setAllowed(b)
  if not b then error("инвариант 7: Поле нельзя выключать — запас сотрётся", 2) end
  return G.Base.setAllowed(self, true)
end

function S:strength() return self:call("getFieldStrength") end

-- Тип → L
function S:stored()
  local raw = self:call("getStoredCondensate")
  if type(raw) ~= "table" then return nil end
  local out = {}
  for name, a in pairs(raw) do out[recipe.typeOfFluid(name) or name] = a end
  return out
end

function S:amount()
  local s = 0
  for _, a in pairs(self:stored() or {}) do s = s + a end
  return s
end

-- Новая напряжённость. Ниже текущего объёма — отказ (начнётся распад). Применится со следующего тика.
function S:setStrength(n)
  assert(math.type(n) == "integer" and n >= 1, "напряжённость — целое ≥ 1")
  local have = self:amount()
  if n < have then return nil, string.format("напряжённость %d ниже объёма %d", n, have) end
  local _, e = self:call("setFieldStrength", n)
  if e then return nil, e end
  return true
end

function S:snapshot()
  local s = G.Base.snapshot(self)
  s.strength, s.stored = self:strength(), self:stored()
  return s
end

S.USES = {"getFieldStrength", "getStoredCondensate", "setFieldStrength"}

return S

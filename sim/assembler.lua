-- Observation Array (MTEBECAssembler).
-- Тир = самый младший по ordinal NaniteTier среди непустых шин; нанитов = min(30720, сумма).
-- Каждый тик питает узлы по порядку, пока хватает входной EU (getMaxInputEu, без округления).
local recipe = require("model.recipe")

local ORD, TIER = {}, {}
for i, n in ipairs(recipe.NANITES) do ORD[n.name] = i; TIER[n.name] = n.tier end

local A = {}
A.__index = A

function A.new(maxInputEu)
  return setmetatable({maxInputEu = maxInputEu, hatches = {}, running = true, nodes = {}}, A)
end

-- hatches: {{kind = "Carbon", count = 64}, ...}
function A:setNanites(hatches) self.hatches = hatches or {} end

function A:tier()
  local best
  for _, h in ipairs(self.hatches) do
    if h.count > 0 and ORD[h.kind] and (not best or ORD[h.kind] < ORD[best]) then best = h.kind end
  end
  return best and TIER[best] or nil
end

function A:available()
  local s = 0
  for _, h in ipairs(self.hatches) do
    if h.count > 0 and ORD[h.kind] then s = s + h.count end
  end
  return math.min(recipe.MAX_NANITES, s)
end

function A:postTick()
  local eu = self.maxInputEu
  for _, n in ipairs(self.nodes) do
    n.powered = false
    local req = n:assemblerEUt()
    if eu >= req then
      eu = eu - req
      n.powered = true
    end
  end
end

return A

-- Рецепты IO Node: шаги, конденсат, предел параллелей. По MTEBECIONode (GT5U 5.09.54.275).
local data = require("model.data")

local M = {}

M.MAX_NANITES = 2048 * 15 -- MTEBECAssembler.MAX_NANITES

-- NaniteTier в порядке ordinal: тир Матрицы = самый младший по ordinal среди непустых шин.
-- Рецепты используют TIER_TO_NANITE: 1 Carbon, 2 Silver, 3 Gold, 4 Transcendent, 5 SixPhasedCopper,
-- 6 WhiteDwarf, 7 BlackDwarf, 8 Universium, 9 Eternity, 10 MagMatter.
M.NANITES = {
  {name = "Carbon", tier = 1}, {name = "Glowstone", tier = 1}, {name = "Silver", tier = 2},
  {name = "Neutronium", tier = 2}, {name = "Gold", tier = 3}, {name = "Transcendent", tier = 4},
  {name = "SixPhasedCopper", tier = 5}, {name = "WhiteDwarf", tier = 6}, {name = "BlackDwarf", tier = 7},
  {name = "Universium", tier = 8}, {name = "Eternity", tier = 9}, {name = "MagMatter", tier = 10},
}
M.NANITE_FOR_TIER = {"Carbon", "Silver", "Gold", "Transcendent", "SixPhasedCopper",
  "WhiteDwarf", "BlackDwarf", "Universium", "Eternity", "MagMatter"}

-- GTValues.V: ULV..UXV, MAX = Integer.MAX_VALUE - 7, «ошибочный» тир 15
local V = {[0] = 8, 32, 128, 512, 2048, 8192, 32768, 131072, 524288,
  2097152, 8388608, 33554432, 134217728, 536870912, 2147483640, 8589934592}
M.V = V

-- GTUtility.getTier: (ceil(log2 l) - 2) // 2, с границами
local function getTier(l)
  if l > V[14] then return 15 end
  if l <= V[0] then return 0 end
  local log2, x = 0, l - 1
  while x > 0 do log2 = log2 + 1; x = x >> 1 end
  return (log2 - 2) // 2
end
M.getTier = getTier

-- GTUtility.roundUpVoltage: напряжение тира, в который попадает x
function M.roundUpVoltage(x)
  if x > V[15] then return x end
  return V[getTier(x)]
end

-- IntDivisionIterator: делит длительность на n примерно равных частей (Math.round(float))
local function divide(total, n)
  local parts, remaining = {}, total
  for counter = 0, n - 1 do
    local left = n - counter
    local v
    if remaining == 0 then
      v = 0
    elseif left == 1 then
      v = remaining
    else
      v = math.floor(remaining / left + 0.5)
    end
    parts[#parts + 1] = v
    remaining = remaining - v
  end
  return parts
end
M.divide = divide

-- Шаги рецепта: {tier, start, stop, index}; узел в шаге i, если start <= progress < stop
function M.steps(r)
  local parts, steps, cur = divide(r.dur, #r.tiers), {}, 0
  for i, len in ipairs(parts) do
    steps[i] = {tier = r.tiers[i], start = cur, stop = cur + len, index = i}
    cur = cur + len
  end
  return steps
end

-- Шаг, содержащий прогресс p (getCurrentStep), или nil
function M.stepAt(steps, p)
  for _, s in ipairs(steps) do
    if s.start <= p and p < s.stop then return s end
  end
  return nil
end

-- Первый шаг после текущего с тиром выше provided (getNextProgressGate)
function M.nextGate(steps, p, provided)
  local s = M.stepAt(steps, p)
  if not s or not provided then return nil end
  local i = s.index
  while steps[i].tier <= provided do
    i = i + 1
    if i > #steps then return nil end
  end
  return steps[i]
end

-- Конденсат на партию: тип → L (cond × P)
function M.condensate(r, P)
  local out = {}
  for t, a in pairs(r.cond) do out[t] = a * P end
  return out
end

-- Предел P по питанию Матрицы: доступно roundUpVoltage(maxInputEu) × 1A, без разгона
function M.maxParallelByPower(r, assemblerMaxInputEu)
  return M.roundUpVoltage(assemblerMaxInputEu) // r.eut
end

function M.maxTier(r)
  local m = 0
  for _, t in ipairs(r.tiers) do if t > m then m = t end end
  return m
end

function M.byName(name)
  for _, r in ipairs(data.recipes) do
    if r.name == name then return r end
  end
  return nil
end

M.all = data.recipes
M.condensates = data.condensates

-- Имя жидкости конденсата в игре (CondensateType.registerFluids: "entangled_" + id) и обратно
local BY_FLUID = {}
for t, d in pairs(data.condensates) do BY_FLUID["entangled_" .. d.id] = t end
function M.fluid(t) return "entangled_" .. data.condensates[t].id end
function M.typeOfFluid(name) return BY_FLUID[name] end

return M

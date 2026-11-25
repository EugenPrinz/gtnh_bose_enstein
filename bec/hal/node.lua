-- IO Node (bec_io_node). Сеттеры драйвера срабатывают со следующего тика.
local G = require("hal.gtbase")
local recipe = require("model.recipe")

local N = setmetatable({}, {__index = G.Base})
N.__index = N

local function tierOf(t) return type(t) == "table" and t.tier or nil end

-- имя жидкости → тип модели; неизвестное оставляем как есть
local function fromFluids(m)
  if type(m) ~= "table" then return nil end
  local out = {}
  for name, a in pairs(m) do out[recipe.typeOfFluid(name) or name] = a end
  return out
end

function N.wrap(proxy) return G.wrap(proxy, N) end

-- 'idle', 'unpowered', 'assembler-offline', 'nanite-tier-too-low', 'paused-step', 'paused-immediate',
-- 'crafting', 'internal-error'
function N:state() return self:call("getState") end

-- Шаги рецепта: {tier, start, stop, index} c index от 1, как в model.recipe.steps; nil — нет рецепта
function N:steps()
  local raw = self:call("getRecipeSteps")
  if type(raw) ~= "table" then return nil end
  local out = {}
  for _, s in pairs(raw) do
    out[#out + 1] = {tier = tierOf(s.nanite), start = s.start, stop = s["end"], index = s.index + 1}
  end
  table.sort(out, function(a, b) return a.index < b.index end)
  return out
end

function N:requiredTier() return tierOf(self:call("getRequiredTier")) end
function N:providedTier() return tierOf(self:call("getProvidedTier")) end
function N:nanites() return self:call("getAvailableNanites") or 0 end
function N:slowdowns() return self:call("getSlowdowns") or 0 end
function N:parallels() return self:call("getParallelRecipesInProgress") or 0 end
function N:required() return fromFluids(self:call("getRequiredCondensate")) end
function N:consumed() return fromFluids(self:call("getConsumedCondensate")) end

function N:limits()
  return self:call("getMinParallel"), self:call("getMaxParallel")
end

-- min = max = P: узел берёт ровно P копий или ждёт
function N:setParallel(P)
  assert(math.type(P) == "integer" and P >= 1, "P должно быть целым ≥ 1")
  local ok, err = self:call("setMaxParallel", P)
  if err then return nil, err end
  ok, err = self:call("setMinParallel", P)
  if err then return nil, err end
  return true
end

function N:setSpeedDivisor(d) return self:call("setSpeedDivisor", d) end

-- Сколько конденсата ещё не забрано: тип → L
function N:missing()
  local req, got = self:required(), self:consumed() or {}
  if not req then return nil end
  local out = {}
  for t, a in pairs(req) do
    local m = a - (got[t] or 0)
    if m > 0 then out[t] = m end
  end
  return out
end

function N:snapshot()
  local s = G.Base.snapshot(self)
  s.state, s.requiredTier, s.providedTier = self:state(), self:requiredTier(), self:providedTier()
  s.nanites, s.slowdowns, s.parallels = self:nanites(), self:slowdowns(), self:parallels()
  s.minP, s.maxP = self:limits()
  return s
end

N.USES = {"getState", "getRecipeSteps", "getRequiredTier", "getProvidedTier", "getAvailableNanites",
  "getSlowdowns", "getParallelRecipesInProgress", "getRequiredCondensate", "getConsumedCondensate",
  "getMinParallel", "getMaxParallel", "setMaxParallel", "setMinParallel", "setSpeedDivisor"}

return N

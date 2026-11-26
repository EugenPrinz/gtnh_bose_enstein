-- Планирование партии: раскладка копий по узлам, стратегия нанитов, подача в энтанглер.
local recipe = require("model.recipe")
local timing = require("model.timing")
local ent = require("model.entangler")

local M = {}

-- Какие наниты заказать, чтобы Матрица дала тир T и как можно больше нанитов (MTEBECAssembler):
-- тир Матрицы — самый младший непустой, количество — сумма ВСЕХ непустых шин (≤ 30 720).
-- Поэтому: тир T обязателен, тиры выше T — «добавка» к количеству (по возрастанию), тиры ниже T — никогда.
-- stock: тир → сколько нанитов этого тира в подсети (варианты одного тира — Carbon/Glowstone, Silver/Neutronium —
-- уже сложены: у них общий номер паттерна). fill = false — без добавки, только тир T.
-- Возвращает {order = {{tier, count}, ...}, N} или nil, причина.
function M.naniteLoad(T, stock, fill)
  local have = stock[T] or 0
  if have < 1 then return nil, "нет нанитов тира " .. T end
  local cap = recipe.MAX_NANITES
  local order, N = {{T, math.min(have, cap)}}, math.min(have, cap)
  if fill ~= false then
    for t = T + 1, 10 do
      if N >= cap then break end
      local c = math.min(stock[t] or 0, cap - N)
      if c > 0 then order[#order + 1] = {t, c}; N = N + c end
    end
  end
  return {order = order, N = N}
end

-- Стратегия нанитов: const или swap — что быстрее (при равенстве const: меньше движений нанитов)
function M.assembly(r, Ps, N, swapTicks)
  local c = timing.line({recipe = r, Ps = Ps, N = N, strategy = "const"})
  local s = timing.line({recipe = r, Ps = Ps, N = N, strategy = "swap", swapTicks = swapTicks})
  if c and (not s or c.ticks <= s.ticks) then return "const", c, s end
  return "swap", s, c
end

-- Раскладка total копий на не более чем nodes узлов, не больше cap на узел, поровну
local function spread(total, nodes, cap)
  local n = math.min(nodes, total)
  local Ps, base, rem = {}, total // n, total % n
  for i = 1, n do Ps[i] = math.min(cap, base + (i <= rem and 1 or 0)) end
  return Ps
end
M.spread = spread

-- o = {recipe, copies, nodes, N, tier (макс. тир нанитов в наличии), assemblerEu, entanglerEu,
--      fieldStrength, swapTicks, have (тип → L уже в Поле)}
-- Возвращает план или nil, {ошибки}. Предупреждения — в plan.warnings.
function M.plan(o)
  local r, errs, warn = o.recipe, {}, {}
  local Tm = recipe.maxTier(r)
  if Tm > (o.tier or 10) then
    errs[#errs + 1] = string.format("нужны наниты тира %d, есть до %d", Tm, o.tier or 0)
  end
  local cap = recipe.maxParallelByPower(r, o.assemblerEu)
  local perWave = math.min(o.nodes * cap, o.assemblerEu // r.eut)
  if cap < 1 or perWave < 1 then
    errs[#errs + 1] = "Матрице не хватает питания даже на 1 параллель"
  end
  if #errs > 0 then return nil, errs end

  local p = {recipe = r, copies = o.copies, waves = {}, ticks = 0, warnings = warn}
  local left = o.copies
  while left > 0 do
    local Ps = spread(math.min(left, perWave), o.nodes, cap)
    local name, best = M.assembly(r, Ps, o.N, o.swapTicks or 60)
    if not best then return nil, {"не удалось рассчитать время сборки"} end
    p.waves[#p.waves + 1] = {Ps = Ps, strategy = name, ticks = best.ticks, swaps = best.swaps}
    p.ticks = p.ticks + best.ticks
    for _, P in ipairs(Ps) do left = left - P end
  end
  if #p.waves > 1 then
    warn[#warn + 1] = string.format("партия в %d волн: питание Матрицы даёт %d параллелей за раз", #p.waves, perWave)
  end

  -- конденсат на всю партию (v1: весь заранее в Поле)
  p.need, p.needTotal = {}, 0
  for t, a in pairs(r.cond) do
    local n = a * o.copies
    p.need[t] = n
    p.needTotal = p.needTotal + n
  end
  if o.fieldStrength and p.needTotal > o.fieldStrength then
    warn[#warn + 1] = string.format("конденсата на партию %d L > напряжённости поля %d: начнётся распад",
      p.needTotal, o.fieldStrength)
  end
  local missing = {}
  for t, n in pairs(p.need) do
    local m = n - ((o.have and o.have[t]) or 0)
    if m > 0 then missing[t] = m end
  end
  p.missing = missing
  if next(missing) then
    local mode, e = ent.best(missing, o.entanglerEu or 0)
    if not mode then
      errs[#errs + 1] = "энтанглеру не хватает EU даже на 1 параллель"
      return nil, errs
    end
    p.entMode, p.entTicks, p.entEu = mode, e.ticks, e.eu
  else
    p.entMode, p.entTicks, p.entEu = nil, 0, 0
  end
  p.totalTicks = p.entTicks + p.ticks
  return p
end

return M

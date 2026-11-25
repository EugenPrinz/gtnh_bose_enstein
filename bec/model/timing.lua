-- Точное время сборки партии на узлах одной Матрицы (по событиям, без потикового цикла).
-- Совпадает с потиковой логикой MTEBECIONode.incrementProgressTime (проверяется tests/ против sim/).
--
-- Прогресс узла: каждый тик acc += N; full = acc // D; acc -= full·D; p += full,
-- D = P · 2^|req − prov| · max(slowdowns + 1, speedDivisor).
-- Узел стоит (acc не растёт), если тир Матрицы ниже нужного шагу или нанитов нет.
-- Если следующий шаг требует тир выше поданного, прогресс упирается в его начало (лишний full пропадает).
--
-- Стратегии нанитов:
--   const — весь рецепт один тир = максимальный тир рецепта;
--   swap  — тир = максимум тиров текущих шагов незавершённых узлов; смена тира — пауза swapTicks
--           (наниты вынуты, все узлы стоят).
local recipe = require("model.recipe")

local M = {}

local function divisor(P, req, prov, slowdowns, sd)
  local diff = req > prov and req - prov or prov - req
  local slow = math.max(slowdowns + 1, sd)
  return P * (1 << diff) * slow
end

-- Целевой тир для swap: максимум по незавершённым узлам
local function swapTarget(nodes, steps)
  local t = 0
  for _, n in ipairs(nodes) do
    if not n.done then
      local s = recipe.stepAt(steps, n.p)
      if s.tier > t then t = s.tier end
    end
  end
  return t
end

-- o = {recipe, Ps = {P1..Pk}, N, strategy = "const"|"swap", swapTicks, slowdowns, speedDivisor, acc0}
-- Возвращает {ticks, done = {тик завершения по узлам}, swaps} или nil, err
function M.line(o)
  local r, N = o.recipe, o.N
  local S, slow, sd = o.swapTicks or 0, o.slowdowns or 0, o.speedDivisor or 1
  if N <= 0 then return nil, "нет нанитов" end
  local steps = recipe.steps(r)
  local nodes = {}
  for i, P in ipairs(o.Ps) do nodes[i] = {P = P, p = 0, acc = (o.acc0 and o.acc0[i]) or 0, done = false} end
  local prov
  if o.strategy == "swap" then prov = swapTarget(nodes, steps) else prov = recipe.maxTier(r) end
  local t, swaps, left = 0, 0, #nodes
  local guard = 0
  while left > 0 do
    guard = guard + 1
    if guard > 1e6 then return nil, "не сходится" end
    -- ближайшее событие: какой-то узел дошёл до конца своего шага
    local dt
    for _, n in ipairs(nodes) do
      if not n.done then
        local s = recipe.stepAt(steps, n.p)
        if s.tier > prov then return nil, "тир нанитов ниже нужного шагу" end
        n.D = divisor(n.P, s.tier, prov, slow, sd)
        n.gate = recipe.nextGate(steps, n.p, prov)
        local need = s.stop - n.p
        local k = (need * n.D - n.acc + N - 1) // N
        if k < 1 then k = 1 end
        if not dt or k < dt then dt = k end
      end
    end
    t = t + dt
    for _, n in ipairs(nodes) do
      if not n.done then
        local total = n.acc + dt * N
        local full = total // n.D
        n.acc = total - full * n.D
        local np = n.p + full
        if n.gate and np > n.gate.start then np = n.gate.start end
        n.p = np
        if n.p >= r.dur then n.done = true; n.doneAt = t; left = left - 1 end
      end
    end
    if o.strategy == "swap" and left > 0 then
      local target = swapTarget(nodes, steps)
      if target ~= prov then
        t = t + S
        swaps = swaps + 1
        prov = target
      end
    end
  end
  local done = {}
  for i, n in ipairs(nodes) do done[i] = n.doneAt end
  return {ticks = t, done = done, swaps = swaps}
end

return M

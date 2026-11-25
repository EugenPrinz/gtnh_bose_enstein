-- model/timing против потикового sim/: совпадение до тика для всех рецептов
local T = require("tests.t")
local World = require("sim.world")
local recipe = require("model.recipe")
local timing = require("model.timing")

local S = {}
local BIG = 1 << 50

-- Потиковый прогон линии; swap: программа ставит тир = максимум нужных тиров, смена — S тиков без нанитов
local function simulate(r, Ps, N, strategy, swapTicks, maxTicks)
  local w = World.new({fieldStrength = BIG, assemblerEu = BIG, nodes = #Ps})
  w.storage:tick()
  for t, a in pairs(r.cond) do w.storage:add(t, a * 1000) end
  w.diode:setFilters((function() local l = {} for t in pairs(r.cond) do l[#l + 1] = t end return l end)())
  local function set(tier) w.asm:setNanites({{kind = recipe.NANITE_FOR_TIER[tier], count = N}}) end
  for i, P in ipairs(Ps) do
    local n = w.nodes[i]
    n.maxParallel = P
    assert(n:start(r, P) == P)
  end
  local cur = strategy == "swap" and recipe.steps(r)[1].tier or recipe.maxTier(r)
  set(cur)
  local pending, wait, swaps = nil, 0, 0
  local done, left = {}, #Ps
  w.onTick = function()
    for i, n in ipairs(w.nodes) do
      if not done[i] and not n:crafting() then done[i] = w.t; left = left - 1 end
    end
    if strategy ~= "swap" then return end
    if pending then
      wait = wait - 1
      if wait <= 0 then cur = pending; pending = nil; set(cur) end
      return
    end
    local target = 0
    for _, n in ipairs(w.nodes) do
      if n:crafting() and n.requiredTier > target then target = n.requiredTier end
    end
    if target > 0 and target ~= cur then
      swaps = swaps + 1
      if swapTicks == 0 then cur = target; set(cur)
      else pending, wait = target, swapTicks; w.asm:setNanites({}) end
    end
  end
  local ok = w:run(maxTicks, function() return left == 0 end)
  for _, n in ipairs(w.nodes) do assert(not n.failed, n.failed) end
  return ok and w.t or nil, done, swaps
end

local function check(r, Ps, N, strategy, swapTicks)
  local m = assert(timing.line({recipe = r, Ps = Ps, N = N, strategy = strategy, swapTicks = swapTicks}))
  if m.ticks > 300000 then return false end
  local t, done, swaps = simulate(r, Ps, N, strategy, swapTicks, m.ticks + 10)
  local tag = string.format("%s P={%s} N=%d %s S=%d", r.name, table.concat(Ps, ","), N, strategy, swapTicks)
  T.eq(t, m.ticks, tag .. ": тики")
  for i = 1, #Ps do T.eq(done[i], m.done[i], tag .. ": узел " .. i) end
  T.eq(swaps, m.swaps, tag .. ": смен")
  return true
end

S["const: все рецепты, разные P и N"] = function()
  local n = 0
  for _, r in ipairs(recipe.all) do
    for _, Ps in ipairs({{1}, {2, 1, 1}, {3, 3}}) do
      for _, N in ipairs({30720, 7777, 1000}) do
        if check(r, Ps, N, "const", 0) then n = n + 1 end
      end
    end
  end
  T.ok(n >= 150, "проверено сочетаний: " .. n)
end

S["swap: все рецепты, пауза 0 и 40 тиков"] = function()
  local n = 0
  for _, r in ipairs(recipe.all) do
    for _, Ps in ipairs({{1}, {2, 1, 1}, {4, 3}}) do
      for _, N in ipairs({30720, 3001}) do
        for _, St in ipairs({0, 40}) do
          if check(r, Ps, N, "swap", St) then n = n + 1 end
        end
      end
    end
  end
  T.ok(n >= 150, "проверено сочетаний: " .. n)
end

S["const при одинаковом тире = dur·P/N"] = function()
  local r = {name = "t", tiers = {3, 3, 3}, dur = 9000, cond = {}, eut = 1}
  local m = timing.line({recipe = r, Ps = {2}, N = 600, strategy = "const"})
  T.eq(m.ticks, 30)
end

S["тир ниже нужного — ошибка, а не бесконечный цикл"] = function()
  local r = recipe.byName("Meta Material Sensor Array 1")
  local m, err = timing.line({recipe = r, Ps = {1}, N = 0, strategy = "const"})
  T.eq(m, nil)
  T.ok(err)
end

return S

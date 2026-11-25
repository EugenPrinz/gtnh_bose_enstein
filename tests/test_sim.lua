local T = require("tests.t")
local World = require("sim.world")
local recipe = require("model.recipe")

local S = {}
local BIG = 1 << 40

-- простой рецепт: один шаг тира tier, длительность dur, конденсат cond на 1 параллель
local function R(tiers, dur, cond)
  return {name = "test", tiers = tiers, dur = dur, cond = cond or {}, eut = 1, out = 1}
end

local function world(o)
  o = o or {}
  local w = World.new({fieldStrength = o.field or BIG, assemblerEu = o.asmEu or BIG, entanglerEu = o.entEu or BIG,
    nodes = o.nodes or 1})
  w.storage:tick() -- Поле запущено
  return w
end

local function nanites(w, tier, n)
  w.asm:setNanites({{kind = recipe.NANITE_FOR_TIER[tier], count = n}})
end

S["Поле: распад ×9/10 раз в 20 тиков, пока объём > напряжённости"] = function()
  local w = world({field = 1000})
  w.storage:add("Neutronium", 1500)
  local seen = {}
  for i = 1, 100 do
    w.storage:tick()
    if i % 20 == 0 then seen[#seen + 1] = w.storage.contents.Neutronium end
  end
  T.list(seen, {1350, 1215, 1093, 983, 983})
end

S["Поле: выключили — запас стёрт в конце цикла"] = function()
  local w = world()
  w.storage:add("Neutronium", 500)
  w.storage.allowed = false
  for _ = 1, 19 do w.storage:tick() end
  T.eq(w.storage.contents.Neutronium, 500)
  w.storage:tick()
  T.eq(next(w.storage.contents), nil)
end

S["Поле: обрыв питания — стёрто сразу"] = function()
  local w = world()
  w.storage:add("Neutronium", 500)
  w.storage.powered = false
  w.storage:tick()
  T.eq(next(w.storage.contents), nil)
end

S["узел: время = ceil(dur·D/N), D = P·2^|разница тиров|"] = function()
  local cases = {{1, 1, 7, 15}, {1, 3, 7, 58}, {2, 1, 7, 29}}
  for _, c in ipairs(cases) do
    local P, prov, N, want = c[1], c[2], c[3], c[4]
    local w = world()
    nanites(w, prov, N)
    local n = w.nodes[1]
    n.maxParallel = P
    T.eq(n:start(R({1}, 100), P), P)
    local ok = w:run(1000, function() return not n:crafting() end)
    T.ok(ok)
    T.eq(w.t, want, "P=" .. P .. " тир=" .. prov)
    T.eq(n.completed, P)
  end
end

S["узел: тир Матрицы ниже нужного — стоит"] = function()
  local w = world()
  nanites(w, 1, 100)
  local n = w.nodes[1]
  n:start(R({2}, 100), 1)
  w:run(50)
  T.eq(n.progress, 0)
  T.eq(n.state, "NaniteTierTooLow")
end

S["узел: загрязнитель замедляет ×2, >3 — рецепт потерян"] = function()
  local w = world()
  nanites(w, 1, 10)
  w.storage:add("Infinity", 1000) -- чужой тип, затвор без фильтров
  local n = w.nodes[1]
  n:start(R({1}, 100), 1)
  w:run(1000, function() return not n:crafting() end)
  T.eq(w.t, 20)
  T.eq(n.completed, 1)

  local w2 = world()
  nanites(w2, 1, 10)
  for _, t in ipairs({"Infinity", "Hypogen", "SpaceTime", "Time"}) do w2.storage:add(t, 10) end
  local n2 = w2.nodes[1]
  n2:start(R({1}, 100), 1)
  w2:tick()
  T.eq(n2.failed, "bec_clogged")
  T.ok(not n2:crafting())
end

S["узел: фильтр затвора убирает загрязнитель"] = function()
  local w = world()
  nanites(w, 1, 10)
  w.storage:add("Infinity", 1000)
  w.storage:add("Neutronium", 1000)
  w.diode:setFilters({"Neutronium"})
  local n = w.nodes[1]
  n:start(R({1}, 100, {Neutronium = 144}), 1)
  w:run(1000, function() return not n:crafting() end)
  T.eq(w.t, 10)
  T.eq(n.completed, 1)
  T.eq(w.storage.contents.Neutronium, 1000 - 144)
end

S["узел: конденсат забирается сразу, а не в конце"] = function()
  local w = world()
  nanites(w, 1, 1)
  w.storage:add("Neutronium", 1000)
  local n = w.nodes[1]
  n:start(R({1}, 100, {Neutronium = 288}), 1)
  w:tick()
  T.eq(n.consumed.Neutronium, 288)
  T.eq(w.storage.contents.Neutronium, 712)
end

S["узел: затвор выключен — провал в конце рецепта"] = function()
  local w = world()
  nanites(w, 1, 10)
  w.storage:add("Neutronium", 1000)
  w.diode.allowed = false
  local n = w.nodes[1]
  n:start(R({1}, 100, {Neutronium = 144}), 1)
  w:run(1000, function() return not n:crafting() end)
  T.eq(n.failed, "missing_condensate:Neutronium")
  T.eq(n.completed, 0)
  T.eq(w.storage.contents.Neutronium, 1000)
end

S["Матрица: питает узлы по порядку, пока хватает EU"] = function()
  local w = world({nodes = 3, asmEu = 25})
  nanites(w, 1, 10)
  for _, n in ipairs(w.nodes) do
    n.maxParallel = 1
    n:start({name = "t", tiers = {1}, dur = 100, cond = {}, eut = 10, out = 1}, 1)
  end
  w:tick()
  T.ok(w.nodes[1].powered and w.nodes[2].powered)
  T.ok(not w.nodes[3].powered)
  T.eq(w.nodes[3].state, "Unpowered")
  T.eq(w.nodes[3].progress, 0)
end

S["Матрица: тир — младший по ordinal, нанитов не больше 30720"] = function()
  local w = world()
  w.asm:setNanites({{kind = "Gold", count = 100}, {kind = "Carbon", count = 5}})
  T.eq(w.asm:tier(), 1)
  T.eq(w.asm:available(), 105)
  w.asm:setNanites({{kind = "Gold", count = 20000}, {kind = "Gold", count = 20000}, {kind = "Carbon", count = 0}})
  T.eq(w.asm:tier(), 3)
  T.eq(w.asm:available(), 30720)
end

S["узел: P режется по maxParallel, копиям и питанию"] = function()
  local w = world({asmEu = 33554432})
  local n = w.nodes[1]
  n.maxParallel = 8
  local r = recipe.byName("Structure Casing")
  T.eq(n:start(r, 3), 1) -- 4A UIV → 1 параллель
  local w2 = world()
  w2.nodes[1].maxParallel = 2
  w2.nodes[1].minParallel = 3
  local P, why = w2.nodes[1]:start(r, 5)
  T.eq(P, nil)
  T.eq(why, "not_enough_parallels")
end

S["speedDivisor: делит скорость и сбрасывает счётчик"] = function()
  local w = world()
  nanites(w, 1, 10)
  local n = w.nodes[1]
  n:setSpeedDivisor(4)
  n:start(R({1}, 100), 1)
  w:run(1000, function() return not n:crafting() end)
  T.eq(w.t, 40)
end

S["энтанглер: выход в Поле в конце цикла"] = function()
  local w = world({entEu = 2 * recipe.condensates.Neutronium.eut})
  w.ent:feed("Neutronium", 1440)
  w:run(799)
  T.eq(w.storage.contents.Neutronium, nil)
  w:run(1)
  T.eq(w.storage.contents.Neutronium, 288)
  w:run(3200)
  T.eq(w.storage.contents.Neutronium, 1440)
  T.eq(w.ent.cycles, 5)
end

return S

local T = require("tests.t")
local recipe = require("model.recipe")
local strategy = require("model.strategy")

local S = {}
local UIV, UMV, UXV = 8388608, 33554432, 536870912

S["раскладка копий поровну"] = function()
  T.list(strategy.spread(10, 4, 100), {3, 3, 2, 2})
  T.list(strategy.spread(2, 16, 100), {1, 1})
  T.list(strategy.spread(16, 16, 1), {1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1})
end

S["план: волны по питанию Матрицы"] = function()
  local r = recipe.byName("Structure Casing") -- UIV 31 457 280 EU/t
  local p = assert(strategy.plan({recipe = r, copies = 10, nodes = 4, N = 30720, tier = 10,
    assemblerEu = 4 * UMV, entanglerEu = 64 * UXV}))
  -- 4A UMV = 134 217 728 → cap на узел 4, всего за раз 134217728 // 31457280 = 4
  T.eq(#p.waves, 3)
  T.list(p.waves[1].Ps, {1, 1, 1, 1})
  T.list(p.waves[3].Ps, {1, 1})
  T.ok(#p.warnings >= 1)
end

S["план: ошибки тира и питания"] = function()
  local r = recipe.byName("Astral Array Fabricator")
  local p, e = strategy.plan({recipe = r, copies = 1, nodes = 1, N = 100, tier = 6, assemblerEu = UIV})
  T.eq(p, nil)
  T.eq(#e, 2)
end

S["план: конденсат с учётом запаса и предупреждение о поле"] = function()
  local r = recipe.byName("Meta Material Sensor Array 1")
  local p = assert(strategy.plan({recipe = r, copies = 2, nodes = 2, N = 30720, tier = 10,
    assemblerEu = 64 * UXV, entanglerEu = 64 * UXV, fieldStrength = 1000,
    have = {ChromaticGlass = 2304, Infinity = 0}}))
  T.eq(p.need.ChromaticGlass, 2304)
  T.eq(p.missing.ChromaticGlass, nil)
  T.eq(p.missing.Infinity, 1152)
  T.ok(p.entTicks > 0)
  T.ok(p.warnings[#p.warnings]:find("распад"))
end

S["стратегия: const, если смены нанитов дороже"] = function()
  local r = recipe.byName("Meta Material Sensor Array 1")
  local name = strategy.assembly(r, {4}, 4096, 60)
  T.eq(name, "const")
  local r2 = recipe.byName("Astral Array Fabricator")
  T.eq((strategy.assembly(r2, {4}, 4096, 60)), "swap")
end

S["наниты: тир T обязателен, старшие — добавка до 30 720, младшие — никогда"] = function()
  local l = assert(strategy.naniteLoad(4, {[1] = 30720, [4] = 64, [10] = 40000}))
  T.eq(l.N, 30720)
  T.eq(#l.order, 2)
  T.list(l.order[1], {4, 64}); T.list(l.order[2], {10, 30656})
  T.eq(strategy.naniteLoad(4, {[4] = 64, [10] = 40000}, false).N, 64)
  local none, why = strategy.naniteLoad(5, {[4] = 100, [6] = 100})
  T.eq(none, nil); T.ok(why:find("тира 5"))
end

S["наниты: в sim младший тир в соседней шине понижает тир, старший — только добавляет"] = function()
  local World = require("sim.world")
  local w = World.new({nodes = 1})
  w.asm:setNanites({{kind = "Transcendent", count = 64}, {kind = "MagMatter", count = 1000}})
  T.eq(w.asm:tier(), 4); T.eq(w.asm:available(), 1064)
  w.asm:setNanites({{kind = "Transcendent", count = 64}, {kind = "Glowstone", count = 1}})
  T.eq(w.asm:tier(), 1)
  w.asm:setNanites({{kind = "Carbon", count = 10}, {kind = "Glowstone", count = 5}})
  T.eq(w.asm:tier(), 1); T.eq(w.asm:available(), 15)
end

return S

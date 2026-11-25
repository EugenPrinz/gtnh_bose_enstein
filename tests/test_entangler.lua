local T = require("tests.t")
local ent = require("model.entangler")
local recipe = require("model.recipe")

local S = {}
local e = recipe.condensates.Neutronium.eut -- 1 966 080, у CosmicNeutronium такой же

S["один тип: параллели по EU"] = function()
  local c = ent.cycle({Neutronium = 1440}, 5 * e)
  T.eq(c.par.Neutronium, 5)
  T.eq(c.out.Neutronium, 720)
  T.eq(c.dur, 800)
  T.eq(c.eut, 5 * e)
end

S["остаток EU переходит к следующему типу"] = function()
  local c = ent.cycle({Neutronium = 144 * 100, CosmicNeutronium = 144 * 2}, 10 * e)
  T.eq(c.par.CosmicNeutronium, 2)
  T.eq(c.par.Neutronium, 8)
end

S["равный делёж при равных входах"] = function()
  local c = ent.cycle({Neutronium = 144 * 100, CosmicNeutronium = 144 * 100}, 9 * e)
  T.eq(c.par.CosmicNeutronium, 4) -- 4.5 → 4
  T.eq(c.par.Neutronium, 5)       -- остаток 5e на последнего
end

S["меньше одной единицы на входе — не запускается"] = function()
  T.eq(ent.cycle({Neutronium = 143}, 10 * e), nil)
end

S["не хватает EU на 1 параллель"] = function()
  T.eq(ent.cycle({Neutronium = 1440}, e - 1), nil)
  T.eq(ent.produce({Neutronium = 1440}, e - 1, "all"), nil)
end

S["длительность цикла = самый долгий активный тип"] = function()
  local a, b
  for t, d in pairs(recipe.condensates) do
    if d.dur ~= 800 and not b then b = t end
  end
  a = "Neutronium"
  local c = ent.cycle({[a] = 144 * 4, [b] = recipe.condensates[b].unit * 4}, 1e15)
  T.eq(c.dur, math.max(800, recipe.condensates[b].dur))
end

S["produce: циклы до нужного объёма"] = function()
  local r = ent.produce({Neutronium = 1440}, 2 * e, "all")
  T.eq(r.cycles, 5)
  T.eq(r.ticks, 4000)
end

S["группы по длительности, от длинных к коротким"] = function()
  local types = {}
  for t in pairs(recipe.condensates) do types[#types + 1] = t end
  local g = ent.groups(types, "group")
  local prev
  for _, grp in ipairs(g) do
    local d = recipe.condensates[grp[1]].dur
    for _, t in ipairs(grp) do T.eq(recipe.condensates[t].dur, d) end
    if prev then T.ok(d < prev) end
    prev = d
  end
  T.eq(#ent.groups(types, "all"), 1)
end

S["best выбирает меньшее время"] = function()
  local r = recipe.byName("Meta Material Sensor Array 1")
  local mode, best, other = ent.best(recipe.condensate(r, 4), 64 * 31457280)
  T.ok(mode == "all" or mode == "group")
  if other then T.ok(best.ticks <= other.ticks) end
end

return S

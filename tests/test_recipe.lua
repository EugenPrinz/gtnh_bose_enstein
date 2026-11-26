local T = require("tests.t")
local recipe = require("model.recipe")

local S = {}

S["деление длительности как IntDivisionIterator"] = function()
  T.list(recipe.divide(1000, 3), {333, 334, 333})
  T.list(recipe.divide(6000, 4), {1500, 1500, 1500, 1500})
  T.list(recipe.divide(10, 4), {3, 2, 3, 2}) -- round(2.5)=3, round(7/3)=2, round(2.5)=3, остаток 2
end

S["шаги Sensor Array 1"] = function()
  local r = recipe.byName("Meta Material Sensor Array 1")
  local st = recipe.steps(r)
  T.eq(#st, 4)
  T.list({st[1].start, st[2].start, st[3].start, st[4].start, st[4].stop}, {0, 1500, 3000, 4500, 6000})
  T.eq(recipe.stepAt(st, 1499).index, 1)
  T.eq(recipe.stepAt(st, 1500).index, 2)
  T.eq(recipe.stepAt(st, 6000), nil)
end

S["следующий барьер по тиру"] = function()
  local st = recipe.steps(recipe.byName("Meta Material Sensor Array 1")) -- тиры 4,1,2,1
  T.eq(recipe.nextGate(st, 1500, 1).index, 3)
  T.eq(recipe.nextGate(st, 1500, 2), nil)
  T.eq(recipe.nextGate(st, 0, 4), nil)
end

S["roundUpVoltage как GTUtility"] = function()
  T.eq(recipe.roundUpVoltage(8), 8)
  T.eq(recipe.roundUpVoltage(9), 32)
  T.eq(recipe.roundUpVoltage(33554432), 33554432)
  T.eq(recipe.roundUpVoltage(33554433), 134217728)
  T.eq(recipe.roundUpVoltage(536870913), 2147483640)
  T.eq(recipe.roundUpVoltage(2147483641), 8589934592)
  T.eq(recipe.roundUpVoltage(10000000000), 10000000000)
end

S["предел параллелей по питанию Матрицы"] = function()
  local r = recipe.byName("Structure Casing") -- UIV, 31 457 280 EU/t
  T.eq(r.eut, 31457280)
  T.eq(recipe.maxParallelByPower(r, 4 * 8388608), 1)     -- 4A UIV → округление до UMV
  T.eq(recipe.maxParallelByPower(r, 16 * 33554432), 17)  -- 16A UMV → UXV
  T.eq(recipe.maxParallelByPower(r, 8388608), 0)         -- 1A UIV < рецепта
end

S["конденсат на партию"] = function()
  local r = recipe.byName("Meta Material Sensor Array 1")
  local c = recipe.condensate(r, 3)
  T.eq(c.ChromaticGlass, 3456)
  T.eq(c.Infinity, 1728)
  T.eq(c.TranscendentMetal, 864)
end

S["данные: 19 конденсатов, 77 рецептов, тиры 1..10, предметные входы"] = function()
  local n = 0
  for _ in pairs(recipe.condensates) do n = n + 1 end
  T.eq(n, 19)
  T.eq(#recipe.all, 77)
  for _, r in ipairs(recipe.all) do T.ok(#r.items > 0, r.name .. ": нет предметных входов") end
  for _, r in ipairs(recipe.all) do
    for _, t in ipairs(r.tiers) do T.ok(t >= 1 and t <= 10, r.name) end
    for c in pairs(r.cond) do T.ok(recipe.condensates[c], r.name .. ": нет типа " .. c) end
  end
end

return S

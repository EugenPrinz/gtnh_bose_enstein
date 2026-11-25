-- Энтанглер (MTEBECGenerator.checkProcessing_EM, GT5U 5.09.54.275).
local recipe = require("model.recipe")

local M = {}
local CT = recipe.condensates

-- Один запуск цикла. inputs: тип → L исходной жидкости во входных хетчах; maxPower: getMaxInputEu.
-- Возвращает {dur, eut, par = {тип → параллели}, out = {тип → L конденсата}, used = {тип → L}} или nil.
-- В игре кандидаты идут из HashMap (порядок не определён) и сортируются стабильно;
-- здесь равные ключи сортируются по имени — для детерминизма.
function M.cycle(inputs, maxPower)
  local c = {}
  for t, amount in pairs(inputs) do
    local d = CT[t]
    if d and amount >= d.unit then
      c[#c + 1] = {t = t, d = d, maxIn = amount // d.unit, p = 0}
    end
  end
  if #c == 0 then return nil end
  table.sort(c, function(a, b)
    local ka, kb = a.maxIn * a.d.eut, b.maxIn * b.d.eut
    if ka ~= kb then return ka < kb end
    return a.t < b.t
  end)
  local rem = maxPower + 0.0 -- double, как в Java
  for i, x in ipairs(c) do
    local share = rem / (#c - i + 1)
    x.p = math.floor(math.min(x.maxIn, share / x.d.eut))
    rem = rem - x.p * x.d.eut
  end
  for _, x in ipairs(c) do
    local add = math.floor(math.min(x.maxIn - x.p, rem / x.d.eut))
    if add > 0 then
      x.p = x.p + add
      rem = rem - add * x.d.eut
    end
  end
  local r = {dur = 0, eut = 0, par = {}, out = {}, used = {}}
  local eu = 0.0
  for _, x in ipairs(c) do
    if x.p > 0 then
      r.par[x.t] = x.p
      r.out[x.t] = x.p * x.d.unit
      r.used[x.t] = x.p * x.d.unit
      if x.d.dur > r.dur then r.dur = x.d.dur end
      eu = eu + x.p * x.d.eut
    end
  end
  if r.dur == 0 then return nil end
  r.eut = math.ceil(eu)
  return r
end

-- Группы подачи: "all" — все типы сразу; "group" — по длительности рецепта, от длинных к коротким
function M.groups(types, mode)
  if mode == "all" then return {types} end
  local by, durs = {}, {}
  for _, t in ipairs(types) do
    local d = CT[t].dur
    if not by[d] then by[d] = {}; durs[#durs + 1] = d end
    table.insert(by[d], t)
  end
  table.sort(durs, function(a, b) return a > b end)
  local g = {}
  for _, d in ipairs(durs) do table.sort(by[d]); g[#g + 1] = by[d] end
  return g
end

-- Сколько тиков и EU нужно, чтобы получить need (тип → L) из исходных жидкостей.
-- Подача: в хетч кладётся ровно ceil(остаток / unit) × unit каждого типа группы.
-- Возвращает {ticks, eu, cycles} или nil, если энтанглеру не хватает EU даже на 1 параллель.
function M.produce(need, maxPower, mode)
  local types = {}
  for t, a in pairs(need) do if a > 0 then types[#types + 1] = t end end
  table.sort(types)
  local left = {}
  for _, t in ipairs(types) do left[t] = need[t] end
  local res = {ticks = 0, eu = 0, cycles = 0}
  for _, g in ipairs(M.groups(types, mode)) do
    while true do
      local inputs, any = {}, false
      for _, t in ipairs(g) do
        if left[t] > 0 then
          local u = CT[t].unit
          inputs[t] = (left[t] + u - 1) // u * u
          any = true
        end
      end
      if not any then break end
      local c = M.cycle(inputs, maxPower)
      if not c then return nil end
      res.ticks = res.ticks + c.dur
      res.eu = res.eu + c.eut * c.dur
      res.cycles = res.cycles + 1
      for t, v in pairs(c.out) do left[t] = math.max(0, left[t] - v) end
    end
  end
  return res
end

-- Лучший режим подачи: меньше тиков, при равенстве — "all"
function M.best(need, maxPower)
  local a, g = M.produce(need, maxPower, "all"), M.produce(need, maxPower, "group")
  if not a and not g then return nil end
  if a and (not g or a.ticks <= g.ticks) then return "all", a, g end
  return "group", g, a
end

return M

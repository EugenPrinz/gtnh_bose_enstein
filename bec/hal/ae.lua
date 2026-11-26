-- AE2 через OC: Input (me_interface), копии паттернов (fluid_interface), крафт нанитов (me_controller).
-- Логика сопоставления партии с паттерном — как у Armisael5 (проверено в игре): считаются только предметы,
-- в Input не должно быть ничего лишнего, число копий — минимум по всем предметам паттерна.
local G = require("hal.gtbase")
local recipe = require("model.recipe")

local A = {}
A.__index = A

-- Исходная (не запутанная) жидкость паттерна → тип конденсата. Имена — из реестра жидкостей GTNH
-- (таблица Armisael5 ENTANGLED_FLUID_NAMES), сверены с CondensateType: entangled_<id>.
A.SOURCE = {
  ["molten.bedrockium"] = "Bedrockium", ["molten.celestialtungsten"] = "CelestialTungsten",
  ["molten.chromaticglass"] = "ChromaticGlass", ["molten.cosmicneutronium"] = "CosmicNeutronium",
  ["molten.eternity"] = "Eternity", ["molten.hypogen"] = "Hypogen", ["molten.infinity"] = "Infinity",
  ["molten.magmatter"] = "MagMatter", ["molten.magnetohydrodynamicallyconstrainedstarmatter"] = "MHDCSM",
  ["molten.neutronium"] = "Neutronium", ["molten.spacetime"] = "SpaceTime",
  ["molten.transcendentmetal"] = "TranscendentMetal", ["molten.universium"] = "Universium",
  ["phononmedium"] = "PhononMedium", ["quarkgluonplasma"] = "QuarkGluonPlasma", ["spatialfluid"] = "Space",
  ["dimensionallyshiftedsuperfluid"] = "DimensionallyShiftedSuperfluid", ["temporalfluid"] = "Time",
  ["boundlesscosmicsolder"] = "BoundlessCosmicSolder",
}

-- component — API OC (list/proxy)
function A.new(component)
  return setmetatable({c = component, patterns = nil, craft = {}}, A)
end

local function first(c, t)
  for addr in c.list(t, true) do return c.proxy(addr) end
end

local function isFluid(e) return e.amount ~= nil and e.damage == nil end
local function key(e) return tostring(e.name) .. ":" .. tostring(e.damage) end

-- Предметы в Input: {ключ → количество}, всего штук; nil, ошибка
function A:input()
  local p = first(self.c, "me_interface")
  if not p then return nil, "нет me_interface (адаптер ME Interface сети Input)" end
  local items, err = G.call(p, "getItemsInNetwork")
  if type(items) ~= "table" then return nil, "не читается Input: " .. tostring(err) end
  local stock, total = {}, 0
  for _, it in ipairs(items) do
    if (it.size or 0) > 0 then stock[key(it)] = (stock[key(it)] or 0) + it.size; total = total + it.size end
  end
  return stock, total
end

-- Паттерны из копий (fluid_interface, слоты 1..36); кэш до rescan
function A:scanPatterns(force)
  if self.patterns and not force then return self.patterns end
  local list = {}
  for addr in self.c.list("fluid_interface", true) do
    local p = self.c.proxy(addr)
    for slot = 1, 36 do
      local pat = G.call(p, "getInterfacePattern", slot)
      if type(pat) == "table" and pat.inputs then list[#list + 1] = pat end
    end
  end
  self.patterns = list
  return list
end

-- Сколько копий паттерна в stock (nil — не он): только предметы, лишних ключей нет
local function copiesOf(pat, stock)
  local need = {}
  for _, e in pairs(pat.inputs) do
    if not isFluid(e) then need[key(e)] = (need[key(e)] or 0) + (e.size or 1) end
  end
  if not next(need) then return nil end
  for k in pairs(stock) do if not need[k] then return nil end end
  local n
  for k, s in pairs(need) do n = math.min(n or math.huge, (stock[k] or 0) // s) end
  return (n and n > 0) and n or nil
end
A.copiesOf = copiesOf

-- Партия в Input → {name, copies, out, fluids = {тип → L на копию}} или nil, причина
function A:identify(stock)
  for pass = 1, 2 do
    for _, pat in ipairs(self:scanPatterns(pass == 2)) do
      local n = copiesOf(pat, stock)
      if n then
        local fl, unknown = {}, nil
        for _, e in pairs(pat.inputs) do
          if isFluid(e) then
            local t = A.SOURCE[e.name] or recipe.typeOfFluid(e.name)
            if t then fl[t] = (fl[t] or 0) + e.amount else unknown = e.name end
          end
        end
        if unknown then return nil, "жидкость паттерна не знакома: " .. unknown end
        local o = pat.outputs and pat.outputs[1] or {}
        return {name = o.label or o.name or "?", copies = n, out = (o.size or 1) * n, fluids = fl}
      end
    end
  end
  return nil, "в Input есть предметы, но ни один паттерн-копия не подходит (смешанная партия?)"
end

-- ---------- наниты: фейковый крафт по паттернам с выходом «номер тира» ----------
local function ctrl(self) return first(self.c, "me_controller") end

-- Все паттерны тира t (варианты Carbon/Glowstone и Silver/Neutronium — все): {{craftable, size}}
function A:naniteCrafts(t, force)
  if self.craft[t] and not force then return self.craft[t] end
  local p = ctrl(self)
  if not p then return nil, "нет me_controller подсети нанитов" end
  local list, err = G.call(p, "getCraftables", {label = tostring(t)})
  if type(list) ~= "table" then return nil, tostring(err) end
  local out = {}
  for _, cr in ipairs(list) do
    local st = G.call(cr, "getItemStack") or G.call(cr, "getStack")
    if type(st) == "table" and (st.size or 0) > 0 then out[#out + 1] = {cr = cr, size = st.size} end
  end
  self.craft[t] = out
  return out
end

-- Сколько нанитов каждого тира можно заказать (= размеры паттернов): {тир → N}
function A:naniteStock()
  local s = {}
  for t = 1, 10 do
    local l = self:naniteCrafts(t) or {}
    for _, x in ipairs(l) do s[t] = (s[t] or 0) + x.size end
  end
  return s
end

-- Заказать count нанитов тира t (по паттернам тира, пока не наберётся). Возвращает список заданий.
function A:requestNanites(t, count)
  local jobs, left = {}, count
  for pass = 1, 2 do
    local l, err = self:naniteCrafts(t, pass == 2)
    if not l then return nil, err end
    jobs, left = {}, count
    local ok = true
    for _, x in ipairs(l) do
      if left <= 0 then break end
      local amount = math.min(x.size, left)
      local job, why = G.call(x.cr, "request", amount)
      if not job then ok = false; break end
      jobs[#jobs + 1] = job
      left = left - amount
    end
    if ok then return jobs end
    self.craft[t] = nil -- устаревшие craftables после перезагрузки чанка
  end
  return nil, "заказ нанитов тира " .. t .. " не принят"
end

-- Состояние задания: "done" | "wait" | "fail", причина
function A.jobState(job)
  if G.call(job, "isDone") then return "done" end
  if G.call(job, "isCanceled") then
    local _, why = G.call(job, "hasFailed")
    return "fail", type(why) == "string" and why or "крафт отменён"
  end
  return "wait"
end

return A

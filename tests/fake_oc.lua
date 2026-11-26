-- Фейковый component API поверх sim/world: те же имена методов и форматы, что у драйверов OC GTNH
-- (DriverBECIONode/Diode/Storage + общие методы GT). Сеттеры применяются на следующем тике, как в игре.
local recipe = require("model.recipe")
local METHODS = require("tests.oc_methods")

local F = {}
F.__index = F

local STATE = {Idle = "idle", Crafting = "crafting", Unpowered = "unpowered", AssemblerOffline = "assembler-offline",
  NaniteTierTooLow = "nanite-tier-too-low", PausedImmediate = "paused-immediate", InternalError = "internal-error"}

local function fluids(m)
  if not m then return nil end
  local out = {}
  for t, a in pairs(m) do out[recipe.fluid(t)] = a end
  return out
end

local function tierMap(t) return t and {name = recipe.NANITE_FOR_TIER[t], tier = t} or nil end

-- w — sim/world; opts.formed = {[kind] = false} — машина «не собрана»
function F.new(w, opts)
  local f = setmetatable({w = w, comps = {}, queue = {}, opts = opts or {}, n = 0}, F)
  return f
end

function F:later(fn) self.queue[#self.queue + 1] = fn end

function F:tick()
  local q = self.queue
  self.queue = {}
  for _, fn in ipairs(q) do fn() end
  if self.autostart then self:autostart() end
  if self.jobs then local keep = {} for _, j in ipairs(self.jobs) do if not j() then keep[#keep + 1] = j end end self.jobs = keep end
  self.w:tick()
end

function F:run(n) for _ = 1, n do self:tick() end end

-- Добавить компонент: ctype, getName, координаты, объект состояния allowed, реализация методов
function F:add(ctype, name, coords, impl, formed)
  self.n = self.n + 1
  local addr = string.format("%08x-0000-4000-8000-%012d", self.n, self.n)
  local st = {allowed = true}
  local base = {
    getName = function() return name end,
    getCoordinates = function() return coords[1], coords[2], coords[3] end,
    getEUMaxStored = function() return formed == false and 0 or 1000000 end,
    getStoredEU = function() return formed == false and 0 or 900000 end,
    getAverageElectricInput = function() return 0 end,
    isMachineActive = function() return formed ~= false and st.allowed end,
    hasWork = function() return false end,
    isWorkAllowed = function() return st.allowed end,
    setWorkAllowed = function(b) st.allowed = b; if impl.onAllowed then self:later(function() impl.onAllowed(b) end) end end,
    getWorkProgress = function() return 0 end,
    getWorkMaxProgress = function() return 0 end,
    getSensorInformation = function() return {"fake " .. name} end,
  }
  local proxy = {address = addr, type = ctype, __st = st}
  for m in pairs(METHODS[ctype]) do
    local fn = impl[m] or base[m]
    proxy[m] = fn or function() return nil end
  end
  self.comps[addr] = proxy
  return proxy, addr
end

function F:remove(addr) self.comps[addr] = nil end

-- component API
function F:api()
  local fake = self
  return {
    list = function(filter, exact)
      local addrs = {}
      for a, p in pairs(fake.comps) do
        if not filter or (exact and p.type == filter) or (not exact and p.type:find(filter, 1, true)) then
          addrs[#addrs + 1] = a
        end
      end
      table.sort(addrs)
      local i = 0
      return function()
        i = i + 1
        local a = addrs[i]
        if a then return a, fake.comps[a].type end
      end
    end,
    proxy = function(a) return fake.comps[a] end,
  }
end

-- ---------- AE2 и остальное оборудование ----------
-- o = {recipe = модельный рецепт партии, items = {{name, damage, label, size(на копию)}}, fluids = {{name, amount}},
--      outLabel, nanites = {тир → размер паттерна}}
function F:ae(o)
  local w, fake = self.w, self
  self.input = {}          -- предметы в сети Input
  self.pulses = 0
  self.jobs = {}
  local pat = {inputs = {}, outputs = {{label = o.outLabel or "Product", size = o.recipe.out or 1}}}
  for _, it in ipairs(o.items) do pat.inputs[#pat.inputs + 1] = {name = it.name, damage = it.damage or 0, label = it.label, size = it.size} end
  for _, f in ipairs(o.fluids or {}) do pat.inputs[#pat.inputs + 1] = {name = f.name, amount = f.amount} end
  self.pattern = pat
  self:add("fluid_interface", nil, nil, {getInterfacePattern = function(slot) return slot == 1 and pat or nil end})
  self:add("me_interface", nil, nil, {getItemsInNetwork = function()
    local l = {}
    for _, it in ipairs(fake.input) do if it.size > 0 then l[#l + 1] = {name = it.name, damage = it.damage, label = it.label, size = it.size} end end
    return l
  end})
  local function craftable(t, size, kind)
    -- как в игре (OC GTNH): метод getStack, выход паттерна не переименован
    -- метод значения OC — вызываемая таблица (type ~= "function"), как в игре
    local function method(f) return setmetatable({}, {__call = function(_, ...) return f(...) end}) end
    return {getStack = method(function() return {label = kind:gsub("(%l)(%u)", "%1 %2") .. " Nanites", size = size} end),
      request = method(function(amount)
        local job = {left = 3}
        fake.jobs[#fake.jobs + 1] = function()
          job.left = job.left - 1
          if job.left == 0 then
            local h = w.asm.hatches
            h[#h + 1] = {kind = kind, count = amount}
            w.asm:setNanites(h)
            return true
          end
        end
        return {isDone = method(function() return job.left <= 0 end), isCanceled = method(function() return false end),
          hasFailed = method(function() return false end)}
      end)}
  end
  local recipe = require("model.recipe")
  self:add("me_controller", nil, nil, {getCraftables = function()
    local l = {}
    for t, size in pairs(o.nanites) do l[#l + 1] = craftable(t, size, recipe.NANITE_FOR_TIER[t]) end
    return l
  end})
  self:add("redstone", nil, nil, {setOutput = function(tbl) if tbl[0] == 15 then fake.pulses = fake.pulses + 1 end end})
  -- Transposer: стороны 2 (порт с меткой) и 3 (ячейка отдыхает); ячейка в порт с меткой → наниты вынуты.
  -- Сторона 4 — посторонний инвентарь (как в игре: Transposer касается ещё какого-то блока)
  self.cell = 3
  self:add("transposer", nil, nil, {
    getInventorySize = function(side) return (side == 2 or side == 3) and 12 or side == 4 and 27 or nil end,
    getStackInSlot = function(side, slot)
      if side == 2 and slot == 8 then return {label = "метка", size = 1} end
      if slot == 7 and side == fake.cell then return {label = "cell", size = 1} end
    end,
    transferItem = function(from, to, n, fs, ts)
      if from ~= fake.cell or fs ~= 7 then return 0 end
      fake.cell = to
      if to == 2 then fake.extracted = (fake.extracted or 0) + 1; w.asm:setNanites({}) end
      return 1
    end})
  -- узел сам берёт рецепт, если разрешена работа и в Input хватает копий на minParallel
  self.autostart = function()
    for _, p in pairs(fake.comps) do
      if p.type == "bec_io_node" and p.__st.allowed and not p.__node:crafting() then
        local n, copies = p.__node, math.huge
        for i, it in ipairs(o.items) do copies = math.min(copies, (fake.input[i] and fake.input[i].size or 0) // it.size) end
        if copies >= n.minParallel and copies > 0 then
          local P = n:start(o.recipe, copies)
          if P then for i, it in ipairs(o.items) do fake.input[i].size = fake.input[i].size - P * it.size end end
        end
      end
    end
  end
  return self
end

-- Положить партию из k копий в Input
function F:batch(o, k)
  for i, it in ipairs(o.items) do
    self.input[i] = self.input[i] or {name = it.name, damage = it.damage or 0, label = it.label, size = 0}
    self.input[i].size = self.input[i].size + it.size * k
  end
end

-- Вся линия по миру w: Поле, затвор, энтанглер, Матрица и узлы
function F:line(o)
  o = o or {}
  local w, fake, formed = self.w, self, o.formed or {}
  self:add("bec_storage", "multi.bec.storage", {0, 10, 0}, {
    getFieldStrength = function() return w.storage.strength end,
    setFieldStrength = function(n) fake:later(function() w.storage.strength = n end) end,
    getStoredCondensate = function() return fluids(w.storage.contents) end,
    onAllowed = function(b) w.storage.allowed = b end,
  }, formed.storage)
  local slots = w.diode.slots
  local filt = {}
  self:add("bec_diode", "multi.bec.diode", {10, 10, 0}, {
    getCondensateFilterCount = function() return slots end,
    getCondensateFilters = function()
      local t = {}
      for i = 1, slots do t[i] = filt[i] end
      return t
    end,
    setCondensateFilters = function(tbl)
      for i = 1, slots do
        local v = tbl[i]
        if v ~= nil and v ~= "water" and not recipe.typeOfFluid(v) then error("Unknown fluid: " .. tostring(v)) end
      end
      fake:later(function()
        filt = {}
        local list = {}
        for i = 1, slots do
          filt[i] = tbl[i]
          local t = tbl[i] and recipe.typeOfFluid(tbl[i])
          if tbl[i] then list[#list + 1] = t or ("~" .. tbl[i]) end -- вода: фильтр есть, конденсата такого нет
        end
        w.diode:setFilters(list)
      end)
    end,
    onAllowed = function(b) w.diode.allowed = b end,
  }, formed.diode)
  self:add("gt_machine", "multi.bec.generator", {-10, 10, 0}, {onAllowed = function(b) w.ent.allowed = b end}, formed.entangler)
  self:add("gt_machine", "multi.bec.assembler", {20, 10, 0}, {}, formed.array)
  for i, n in ipairs(w.nodes) do
    local c = (o.nodeCoords and o.nodeCoords[i]) or {20 + i, 2, 8}
    local px = self:add("bec_io_node", "multi.bec.io-node", c, {
      getState = function() return STATE[n.state] or n.state end,
      getRecipeSteps = function()
        if not n.steps then return nil end
        local t = {}
        for k, s in ipairs(n.steps) do t[k] = {nanite = tierMap(s.tier), start = s.start, ["end"] = s.stop, index = s.index - 1} end
        return t
      end,
      getRequiredTier = function() return tierMap(n.requiredTier) end,
      getProvidedTier = function() return tierMap(w.asm:tier()) end,
      getAvailableNanites = function() return w.asm:available() end,
      getSlowdowns = function() return n.slowdowns end,
      getParallelRecipesInProgress = function() return n.P or 0 end,
      getRequiredCondensate = function() return fluids(n.required) end,
      getConsumedCondensate = function() return fluids(n.consumed) end,
      getMinParallel = function() return n.minParallel end,
      getMaxParallel = function() return n.maxParallel end,
      setMinParallel = function(v) fake:later(function() n.minParallel = v end) end,
      setMaxParallel = function(v) fake:later(function() n.maxParallel = v end) end,
      setSpeedDivisor = function(v) fake:later(function() n:setSpeedDivisor(v) end) end,
      isMachineActive = function() return n:crafting() end,
      hasWork = function() return n:crafting() end,
    }, formed.node)
    px.__node = n
  end
  return self
end

return F

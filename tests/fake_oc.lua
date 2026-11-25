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
  local proxy = {address = addr, type = ctype}
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
    self:add("bec_io_node", "multi.bec.io-node", c, {
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
  end
  return self
end

return F

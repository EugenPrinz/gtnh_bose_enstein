-- Автомат линии BEC (DESIGN §4): IDLE → IDENTIFY → PLAN → WAIT_COND → ROUTE → START → RUN → DRAIN → RETURN.
-- Без OC-библиотек: всё внешнее — в d = {component, sleep(с), now() → с, log, cfg, save(t), load() → t, layout}.
-- tick() делает один шаг; короткие ожидания (запуск узлов, крафт нанитов, перенос ячейки) — внутри шага.
local probe = require("hal.probe")
local AE = require("hal.ae")
local Shuttle = require("hal.shuttle")
local Nanites = require("hal.nanites")
local strategy = require("model.strategy")
local timing = require("model.timing")

local L = {}
L.__index = L

L.PHASES = {"IDLE", "IDENTIFY", "PLAN", "WAIT_COND", "ROUTE", "START", "RUN", "DRAIN", "RETURN", "FAULT"}
L.RU = {IDLE = "ожидание партии", IDENTIFY = "опознание партии", PLAN = "план", WAIT_COND = "жду конденсат",
  ROUTE = "маршрут затвора", START = "запуск узлов", RUN = "сборка", DRAIN = "извлечение нанитов",
  RETURN = "возврат ячейки", FAULT = "ОШИБКА"}

function L.new(d)
  local self = setmetatable({d = d, cfg = d.cfg, log = d.log}, L)
  self.ae = AE.new(d.component)
  self.sh = Shuttle.new(d.component)
  self.nan = Nanites.new(d.component)
  self.st = (d.load and d.load()) or {}
  self.st.phase = self.st.phase or "IDLE"
  self.warned = {}
  return self
end

function L:save() if self.d.save then self.d.save(self.st) end end

function L:go(phase)
  if self.st.phase ~= phase then
    self.st.phase = phase
    self.st.since = self.d.now()
    self:save()
  end
end

function L:fault(code, msg, action)
  self.st.err = {code = code, msg = msg, action = action}
  self.log:err(msg .. (action and (" → " .. action) or ""), code)
  self.st.faultFrom = self.st.phase ~= "FAULT" and self.st.phase or self.st.faultFrom
  self:go("FAULT")
  return false
end

-- Предупреждение один раз на ключ (за партию)
function L:warnOnce(key, code, msg)
  if self.warned[key] then return end
  self.warned[key] = true
  self.log:warn(msg, code)
end

-- ---------- старт программы ----------
function L:init()
  local r = probe.run(self.d.component, {layout = self.d.layout, dummy = self.cfg.dummy})
  self.m = r
  if not r.ok then
    local e = r.errors[1]
    return self:fault(e.code, e.msg, e.action)
  end
  if self.d.saveLayout then self.d.saveLayout(r.layout) end
  -- инварианты: Поле и затвор включены
  if not r.storage:allowed() then r.storage:setAllowed(true); self.log:warn("Поле было выключено — включено", "E-FIELD-OFF") end
  if not r.diode:allowed() then r.diode:setAllowed(true); self.log:warn("затвор был выключен — включён", "E-GATE-OFF") end
  -- узлы: занятые — продолжаем партию, свободные — выключить, чтобы не хватали предметы сами
  local busy = {}
  for i, n in ipairs(r.node) do
    if n:hasWork() then busy[#busy + 1] = {i = i, P = select(2, n:limits()) or 1}
    else n:setAllowed(false) end
  end
  -- рабочая ячейка извлечения нанитов на месте
  local ok, e = self.nan:recover(self.d.sleep, self.d.now, self.cfg.cellMoveTimeout)
  if not ok then return self:fault("E-NANITE-CELL", e, "проверить ячейку и метку в IO Port подсети нанитов") end
  if #busy > 0 then
    self.log:warn("продолжаю партию после перезапуска: узлов в работе — " .. #busy)
    self.st.assign = busy
    self.st.batch = self.st.batch or {name = "?", copies = 0}
    self.st.unknownNanites = true
    local types = {}
    for _, a in ipairs(busy) do for t in pairs(r.node[a.i]:required() or {}) do types[t] = true end end
    local list = {}
    for t in pairs(types) do list[#list + 1] = t end
    r.diode:route(list)
    self:afterStart()
    self:go("RUN")
  else
    if not r.diode:hasDummy() then r.diode:close() end
    if self.st.phase ~= "IDLE" and self.st.phase ~= "FAULT" then
      self.log:warn("после перезапуска узлы свободны — фаза " .. self.st.phase .. " сброшена")
    end
    if self.st.phase ~= "FAULT" then self:go("IDLE") end
  end
  return true
end

function L:reset()
  self.st.err = nil
  self.warned = {}
  self.st.phase = "IDLE"
  self.ae.patterns = nil
  self.ae.craft = {}
  return self:init()
end

-- ---------- шаги ----------
function L:tick()
  local ph = self.st.phase
  local f = self["p_" .. ph]
  if f then return f(self) end
end

function L:p_FAULT() end

function L:p_IDLE()
  if self.st.paused then return end
  local stock, total = self.ae:input()
  if not stock then return self:fault("E-AE", total, "проверить адаптер ME Interface сети Input") end
  if total > 0 then
    self.d.sleep(self.cfg.settle)
    self:go("IDENTIFY")
  end
end

function L:p_IDENTIFY()
  local stock = self.ae:input()
  local b, err = self.ae:identify(stock or {})
  if not b then return self:fault("E-BATCH", err, "убрать лишнее из Input или добавить паттерн-копию") end
  self.st.batch = b
  self.st.t0 = self.d.now()
  self.warned = {}
  self.log:info(string.format("партия: %s ×%d (конденсат: %s)", b.name, b.copies, b.src or "паттерн"))
  self:go("PLAN")
end

function L:p_PLAN()
  local b, nodes = self.st.batch, self.m.node
  local Ps = strategy.spread(b.copies, #nodes, math.huge)
  local assign = {}
  for i, P in ipairs(Ps) do assign[#assign + 1] = {i = i, P = P} end
  self.st.assign = assign
  local need, total = {}, 0
  for t, a in pairs(b.fluids) do need[t] = a * b.copies; total = total + need[t] end
  self.st.need = need
  local s = self.m.storage:strength() or 0
  if total > s then
    if self.cfg.fieldAuto then
      local n = math.ceil(total * self.cfg.fieldMargin)
      local ok, e = self.m.storage:setStrength(n)
      if ok then self.log:info("напряжённость поля " .. s .. " → " .. n)
      else self:warnOnce("field", "W-FIELD", "напряжённость не поднята: " .. tostring(e)) end
    else
      self:warnOnce("field", "W-FIELD", string.format("партии нужно %d L, напряжённость %d — начнётся распад", total, s))
    end
  end
  local parts = {}
  for _, a in ipairs(assign) do parts[#parts + 1] = "узел " .. a.i .. "×" .. a.P end
  self.log:info("раскладка: " .. table.concat(parts, ", "))
  self:go("WAIT_COND")
end

function L:missingCond()
  local have = self.m.storage:stored() or {}
  local miss = {}
  for t, a in pairs(self.st.need or {}) do
    if (have[t] or 0) < a then miss[t] = a - (have[t] or 0) end
  end
  return miss
end

function L:p_WAIT_COND()
  local miss = self:missingCond()
  if not next(miss) then return self:go("ROUTE") end
  local _, cap = self.m.storage:eu()
  if not self.m.storage:active() then self:warnOnce("fieldpwr", "E-FIELD-PWR", "Поле не работает — запас под угрозой") end
  if not self.m.entangler:hasWork() and (self.d.now() - (self.st.since or 0)) > 10 then
    self:warnOnce("entidle", "E-ENT-IDLE", "конденсата не хватает, а энтанглер стоит — проверить подсеть энтанглера")
  end
end

function L:p_ROUTE()
  local list = {}
  for t in pairs(self.st.need or {}) do list[#list + 1] = t end
  self.st.route = list
  local d = self.m.diode
  if not d:allowed() then d:setAllowed(true) end
  local ok, e = d:route(list)
  if not ok then return self:fault("E-ROUTE", e, "проверить затвор и типы конденсата") end
  for _ = 1, 20 do
    self.d.sleep(0.1)
    if d:check(list) then return self:go("START") end
  end
  return self:fault("E-ROUTE", "фильтры затвора не применились", "проверить затвор: getCondensateFilters")
end

function L:p_START()
  local nodes = self.m.node
  for _, a in ipairs(self.st.assign) do
    local n = nodes[a.i]
    n:setParallel(a.P)
    n:setAllowed(true)
  end
  local pending = {}
  for _, a in ipairs(self.st.assign) do pending[a.i] = true end
  local t0 = self.d.now()
  while next(pending) do
    for i in pairs(pending) do
      if nodes[i]:hasWork() then nodes[i]:setAllowed(false); pending[i] = nil end
    end
    if not next(pending) then break end
    if self.d.now() - t0 > self.cfg.nodeStartTimeout then
      local l = {}
      for i in pairs(pending) do nodes[i]:setAllowed(false); l[#l + 1] = tostring(i) end
      return self:fault("E-START", "узлы не взяли рецепт: " .. table.concat(l, ", "),
        "проверить Advanced Stocking Input Bus, питание Матрицы и минимум параллелей")
    end
    self.d.sleep(0.25)
  end
  self:afterStart()
  self:go("RUN")
end

-- После старта: шаги рецепта и фактические P с узлов, выбор стратегии нанитов
function L:afterStart()
  local nodes = self.m.node
  local steps, Ps = nil, {}
  for _, a in ipairs(self.st.assign) do
    local n = nodes[a.i]
    steps = steps or n:steps()
    local p = n:parallels()
    Ps[#Ps + 1] = (p and p > 0) and p or a.P
    a.P = Ps[#Ps]
  end
  if not steps or #steps == 0 then
    self.st.strategy, self.st.maxTier = "swap", nil
    return
  end
  local tiers, maxT = {}, 0
  for i, s in ipairs(steps) do tiers[i] = s.tier; if s.tier > maxT then maxT = s.tier end end
  self.st.steps, self.st.maxTier = tiers, maxT
  local stock = self.ae:naniteStock()
  self.st.naniteStock = stock
  local r = {tiers = tiers, dur = steps[#steps].stop}
  local load = strategy.naniteLoad(maxT, stock, self.cfg.naniteFill)
  local N = load and load.N or 1
  local c = timing.line({recipe = r, Ps = Ps, N = N, strategy = "const"})
  local s = timing.line({recipe = r, Ps = Ps, N = N, strategy = "swap", swapTicks = self.cfg.swapTicks})
  if not load then
    self.st.strategy = "swap" -- старшего тира нет: только по шагам
  elseif c and (not s or c.ticks <= s.ticks) then
    self.st.strategy = "const"
  else
    self.st.strategy = "swap"
  end
  self.st.eta = (self.st.strategy == "const" and c or s or c or {}).ticks
  self.st.runT0 = self.d.now()
  self.log:info(string.format("наниты: %s, оценка %s тиков", self.st.strategy, tostring(self.st.eta)))
end

-- Сменить тир Матрицы на T: вынуть всё, заказать T (+ старшие)
function L:supply(T)
  -- Матрица уже даёт тир T (после перезапуска, ручной подачи, прошлого заказа) — ничего не трогаем
  for _, a in ipairs(self.st.assign or {}) do
    local n = self.m.node[a.i]
    local pt, N = n and n:providedTier(), n and n:nanites() or 0
    if pt == T and N > 0 then
      self.st.provided, self.st.N, self.st.unknownNanites = T, N, nil
      self:save()
      return true
    end
  end
  if self.st.provided or self.st.unknownNanites then
    local ok, e = self.nan:extract(self.d.sleep, self.d.now, self.cfg.cellMoveTimeout)
    if not ok then return nil, "извлечение: " .. e end
    self.st.provided, self.st.unknownNanites, self.st.N = nil, nil, nil
  end
  local stock, why = self.ae:naniteStock()
  local load, e = strategy.naniteLoad(T, stock, self.cfg.naniteFill)
  if not load then
    -- паттерн или запас могли появиться после старта: перечитать и попробовать ещё раз
    self.ae.craft = {}
    stock, why = self.ae:naniteStock()
    load, e = strategy.naniteLoad(T, stock, self.cfg.naniteFill)
    if not load then
      return nil, e .. (why[T] and (" (" .. why[T] .. ")") or " (в подсети нанитов нет паттерна для этого тира)")
    end
  end
  local jobs = {}
  for _, o in ipairs(load.order) do
    local j, err = self.ae:requestNanites(o[1], o[2])
    if not j then return nil, err end
    for _, x in ipairs(j) do jobs[#jobs + 1] = x end
  end
  local t0 = self.d.now()
  while true do
    local done = true
    for _, j in ipairs(jobs) do
      local s, why = AE.jobState(j)
      if s == "fail" then return nil, "крафт нанитов: " .. why end
      if s == "wait" then done = false end
    end
    if done then break end
    if self.d.now() - t0 > self.cfg.naniteTimeout then return nil, "крафт нанитов не завершился за " .. self.cfg.naniteTimeout .. " с" end
    self.d.sleep(0.1)
  end
  self.st.provided, self.st.N, self.st.load = T, load.N, load.order
  self:save()
  return true
end

function L:p_RUN()
  local nodes, active = self.m.node, {}
  for _, a in ipairs(self.st.assign) do
    if nodes[a.i]:hasWork() then active[#active + 1] = a end
  end
  if #active == 0 then return self:go("DRAIN") end
  -- нужный тир
  local T
  if self.st.strategy == "const" and self.st.maxTier then
    T = self.st.maxTier
  else
    for _, a in ipairs(active) do
      local rt = nodes[a.i]:requiredTier()
      if rt and (not T or rt > T) then T = rt end
    end
  end
  if T and T ~= self.st.provided then
    local ok, e = self:supply(T)
    if ok then
      self.log:info(string.format("наниты: тир %d, %d шт.", T, self.st.N))
      self.st.swapFail = nil
    else
      self.st.swapFail = self.st.swapFail or self.d.now()
      self:warnOnce("swap" .. T, "E-TIER", "наниты тира " .. T .. ": " .. e)
      if self.d.now() - self.st.swapFail > 30 then
        return self:fault("E-TIER", "наниты тира " .. T .. " не поданы 30 с: " .. e, "проверить подсеть нанитов и паттерны «" .. T .. "»")
      end
    end
  end
  -- здоровье
  for _, a in ipairs(active) do
    local n = nodes[a.i]
    local sl = n:slowdowns()
    if sl > 0 then self:warnOnce("slow" .. a.i, "E-SLOW", string.format("узел %d: загрязнителей %d — проверить фильтры затвора", a.i, sl)) end
  end
  if not self.m.storage:active() then self:warnOnce("fieldpwr", "E-FIELD-PWR", "Поле не работает — запас под угрозой") end
  if not self.m.diode:active() then
    self.m.diode:setAllowed(true)
    self:warnOnce("gate", "E-GATE-OFF", "затвор не работает — включаю; проверить питание UIV")
  end
end

function L:p_DRAIN()
  if self.st.provided or self.st.unknownNanites then
    local ok, e = self.nan:extract(self.d.sleep, self.d.now, self.cfg.cellMoveTimeout)
    if not ok then return self:fault("E-NANITE-CELL", "извлечение нанитов: " .. e, "проверить Transposer и IO Port подсети нанитов") end
    self.st.provided, self.st.unknownNanites, self.st.N = nil, nil, nil
  end
  self.m.diode:close()
  self:go("RETURN")
end

function L:p_RETURN()
  local stock, total = self.ae:input()
  if not stock then return self:fault("E-AE", total, "проверить адаптер ME Interface сети Input") end
  if total > 0 then
    self.log:info("в Input ещё " .. total .. " шт. — следующая волна")
    return self:go("IDENTIFY")
  end
  local ok, e = self.sh:pulse(self.d.sleep, self.cfg.pulse)
  if not ok then return self:fault("E-SHUTTLE", e, "проверить Redstone I/O челнока") end
  local b = self.st.batch or {}
  self.log:info(string.format("готово: %s ×%s за %d с", tostring(b.name), tostring(b.copies), math.floor(self.d.now() - (self.st.t0 or self.d.now()))))
  self.st.batch, self.st.assign, self.st.need, self.st.route, self.st.steps = nil, nil, nil, nil, nil
  self:go("IDLE")
end

-- ---------- ручное управление Полем ----------
-- Поднимать — всегда; опускать — только без партии (IDLE/FAULT) и не ниже текущего объёма (иначе распад).
function L:setField(n)
  if math.type(n) ~= "integer" or n < 1 then return nil, "напряжённость — целое число ≥ 1" end
  local st = self.m and self.m.storage
  if not st then return nil, "Поле не найдено" end
  local cur = st:strength() or 0
  if n < cur and self.st.phase ~= "IDLE" and self.st.phase ~= "FAULT" then
    return nil, "опускать напряжённость можно только без партии"
  end
  local ok, e = st:setStrength(n)
  if not ok then return nil, e end
  self.log:info(string.format("напряжённость поля %d → %d (вручную)", cur, n))
  return true
end

function L:setFieldAuto(on)
  self.cfg.fieldAuto = on and true or false
  self.log:info("авторегулировка поля: " .. (on and "вкл" or "выкл"))
end

-- ---------- снимок для экрана ----------
function L:view()
  local st, m = self.st, self.m or {}
  local v = {phase = st.phase, phaseRu = L.RU[st.phase] or st.phase, batch = st.batch, strategy = st.strategy,
    tier = st.provided, N = st.N, load = st.load, steps = st.steps, eta = st.eta, paused = st.paused, err = st.err,
    elapsed = st.t0 and (self.d.now() - st.t0) or nil, route = st.route, log = self.log.lines, nodes = {}}
  local function safe(f, ...) local ok, a, b, c = pcall(f, ...); if ok then return a, b, c end end
  if m.entangler then
    local cur, max = safe(m.entangler.progress, m.entangler)
    local eu, cap = safe(m.entangler.eu, m.entangler)
    v.ent = {active = safe(m.entangler.active, m.entangler), cur = cur or 0, max = max or 0, eu = eu or 0, cap = cap or 0}
  end
  if m.storage then
    local eu, cap = safe(m.storage.eu, m.storage)
    v.field = {stored = safe(m.storage.stored, m.storage) or {}, strength = safe(m.storage.strength, m.storage) or 0,
      active = safe(m.storage.active, m.storage), eu = eu or 0, cap = cap or 0, need = st.need, auto = self.cfg.fieldAuto}
  end
  if m.diode then v.gate = {active = safe(m.diode.active, m.diode), filters = safe(m.diode.filters, m.diode) or {}} end
  if m.array then v.array = {active = safe(m.array.active, m.array)} end
  local P = {}
  for _, a in ipairs(st.assign or {}) do P[a.i] = a.P end
  for i, n in ipairs(m.node or {}) do
    local cur, max = safe(n.progress, n)
    v.nodes[i] = {i = i, state = safe(n.state, n) or "?", cur = cur or 0, max = max or 0, tier = safe(n.requiredTier, n),
      P = P[i], slow = safe(n.slowdowns, n) or 0}
  end
  return v
end

return L

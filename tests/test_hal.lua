local T = require("tests.t")
local World = require("sim.world")
local Fake = require("tests.fake_oc")
local METHODS = require("tests.oc_methods")
local G = require("hal.gtbase")
local Node = require("hal.node")
local Diode = require("hal.diode")
local Storage = require("hal.storage")
local probe = require("hal.probe")
local recipe = require("model.recipe")

local S = {}
local BIG = 1 << 40

local function line(nodes, o)
  local w = World.new({fieldStrength = BIG, assemblerEu = BIG, entanglerEu = BIG, nodes = nodes or 2})
  w.storage:tick()
  local f = Fake.new(w):line(o)
  return f, w
end

S["HAL вызывает только методы из дампа игры"] = function()
  for _, ctype in ipairs({"gt_machine", "bec_diode", "bec_storage", "bec_io_node"}) do
    for _, m in ipairs(G.USES) do T.ok(METHODS[ctype][m], ctype .. ": нет " .. m) end
  end
  for _, m in ipairs(Node.USES) do T.ok(METHODS.bec_io_node[m], "bec_io_node: нет " .. m) end
  for _, m in ipairs(Diode.USES) do T.ok(METHODS.bec_diode[m], "bec_diode: нет " .. m) end
  for _, m in ipairs(Storage.USES) do T.ok(METHODS.bec_storage[m], "bec_storage: нет " .. m) end
end

S["probe: полная линия, нет фиктивного фильтра → W-DUMMY, --fix чинит"] = function()
  local f = line(3)
  local r = probe.run(f:api())
  T.ok(r.ok, r.errors[1] and r.errors[1].msg)
  T.eq(#r.node, 3)
  T.ok(r.entangler and r.array and r.diode and r.storage)
  T.eq(r.warnings[1].code, "W-DUMMY")
  probe.fix(r)
  T.ok(not r.diode:hasDummy(), "до тика фильтр ещё не стоит")
  f:tick()
  T.ok(r.diode:hasDummy())
  T.eq(#probe.run(f:api()).warnings, 0)
end

S["probe: не собрано, нет Поля, лишний затвор, чужая GT-машина"] = function()
  local f = line(1, {formed = {array = false}})
  f:add("bec_diode", "multi.bec.diode", {99, 0, 0}, {getCondensateFilterCount = function() return 19 end})
  f:add("gt_machine", "multi.machine.ebf", {50, 0, 0}, {})
  for a, p in pairs(f.comps) do if p.type == "bec_storage" then f:remove(a) end end
  local r = probe.run(f:api())
  local codes = {}
  for _, e in ipairs(r.errors) do codes[e.code] = (codes[e.code] or 0) + 1 end
  T.eq(codes["E-FORM"], 1)
  T.eq(codes["E-MISSING"], 1)
  T.eq(codes["E-DUP"], 1)
  T.eq(#r.other, 1)
  T.ok(not r.ok)
end

S["probe: номера узлов держатся за координаты"] = function()
  local f = line(3, {nodeCoords = {{30, 2, 8}, {10, 2, 8}, {20, 2, 8}}})
  local r1 = probe.run(f:api())
  T.list({r1.layout.nodes[1][1], r1.layout.nodes[2][1], r1.layout.nodes[3][1]}, {10, 20, 30})
  -- прошлая раскладка в другом порядке: номера сохраняются
  local prev = {nodes = {{20, 2, 8}, {30, 2, 8}, {10, 2, 8}}}
  local r2 = probe.run(f:api(), {layout = prev})
  T.list({r2.node[1].coordsT[1], r2.node[2].coordsT[1], r2.node[3].coordsT[1]}, {20, 30, 10})
  -- узел пропал
  for a, p in pairs(f.comps) do if p.type == "bec_io_node" and select(1, p.getCoordinates()) == 30 then f:remove(a) end end
  local r3 = probe.run(f:api(), {layout = prev})
  T.eq(r3.errors[1].code, "E-NODE-LOST")
  T.eq(#r3.node, 2)
end

S["затвор: маршрут со следующего тика, слот 1 — фиктивный"] = function()
  local f, w = line(1)
  local r = probe.run(f:api())
  local d = r.diode
  T.ok(d:route({"Neutronium", "Infinity"}))
  T.ok(not d:check({"Neutronium", "Infinity"}))
  f:tick()
  T.ok(d:check({"Neutronium", "Infinity"}))
  local fl = d:filters()
  T.eq(fl[1], "water")
  T.eq(fl[2], "Infinity")
  T.eq(fl[3], "Neutronium")
  T.ok(w.diode:allows("Neutronium") and not w.diode:allows("Hypogen"))
  local ok, err = d:route({"Нет такого"})
  T.eq(ok, nil)
  T.ok(err:find("неизвестный"))
  local many = {}
  for t in pairs(recipe.condensates) do many[#many + 1] = t end
  T.eq((d:route(many)), nil) -- 19 типов + фиктивный не влезают в 19 слотов
  d:close()
  f:tick()
  T.ok(d:check({}))
  T.ok(not w.diode:allows("Neutronium"))
end

S["Поле: выключить нельзя, напряжённость не ниже объёма"] = function()
  local f, w = line(1)
  local s = probe.run(f:api()).storage
  T.ok(not pcall(s.setAllowed, s, false))
  w.storage:add("Neutronium", 5000)
  T.eq(s:stored().Neutronium, 5000)
  T.eq((s:setStrength(4000)), nil)
  T.ok(s:setStrength(6000))
  f:tick()
  T.eq(s:strength(), 6000)
end

S["узел: P, шаги и конденсат в типах модели"] = function()
  local f, w = line(1)
  w.asm:setNanites({{kind = "Transcendent", count = 64}})
  w.storage:add("ChromaticGlass", 10000)
  local n = probe.run(f:api()).node[1]
  T.ok(n:setParallel(2))
  f:tick()
  T.list({n:limits()}, {2, 2})
  local r = recipe.byName("Meta Material Sensor Array 1")
  T.eq(w.nodes[1]:start(r, 2), 2)
  T.eq(n:state(), "crafting")
  local st, ms = n:steps(), recipe.steps(r)
  for i = 1, #ms do
    T.eq(st[i].tier, ms[i].tier); T.eq(st[i].start, ms[i].start); T.eq(st[i].stop, ms[i].stop); T.eq(st[i].index, i)
  end
  T.eq(n:required().ChromaticGlass, 2304)
  T.eq(n:providedTier(), 4)
  T.eq(n:requiredTier(), 4)
  f:tick()
  T.eq(n:consumed().ChromaticGlass, 2304)
  T.eq(n:missing().Infinity, 1152)
  T.eq(n:missing().ChromaticGlass, nil)
end

S["вызов пропавшего метода не роняет программу"] = function()
  local v, err = G.call({}, "getName")
  T.eq(v, nil)
  T.ok(err:find("нет метода"))
  local v2, err2 = G.call({boom = function() error("adapter gone") end}, "boom")
  T.eq(v2, nil)
  T.ok(err2:find("adapter gone"))
end

S["install.lua ставит все модули bec/"] = function()
  local src = io.open("bec/install.lua"):read("a")
  local listed = {}
  for f in src:match("FILES = (%b{})"):gmatch('"([^"]+%.lua)"') do listed[f] = true end
  local p = io.popen("cd bec && find . -name '*.lua' | sed 's#^./##'")
  for f in p:lines() do
    if f ~= "install.lua" then T.ok(listed[f], "install.lua не ставит " .. f) end
  end
  p:close()
end

return S

-- Автомат линии против sim/ через фейковые компоненты: партия проходит от Input до возврата ячейки
local T = require("tests.t")
local World = require("sim.world")
local Fake = require("tests.fake_oc")
local Line = require("line")
local Log = require("log")
local config = require("config")
local recipe = require("model.recipe")

local S = {}

local SENSOR = {
  recipe = recipe.byName("Meta Material Sensor Array 1"),
  outLabel = "Rough Sensor Array",
  items = {{name = "gregtech:gt.metaitem.01", damage = 32693, label = "Sensor (UHV)", size = 2},
           {name = "bartworks:gt.bwMetaGeneratedplate", damage = 11, label = "Tairitsu Plate", size = 2},
           {name = "gregtech:gt.metaitem.03", damage = 4, label = "Churitsu Casing", size = 1},
           {name = "gregtech:gt.metaitem.01", damage = 1, label = "Shijima Bolt", size = 16}},
  fluids = {{name = "molten.chromaticglass", amount = 1152}, {name = "molten.infinity", amount = 576},
            {name = "molten.transcendentmetal", amount = 288}},
  nanites = {[1] = 30720, [4] = 64, [10] = 30720},
}

local function setup(nodes, field, pat)
  local w = World.new({fieldStrength = field or 1000, assemblerEu = 1 << 40, entanglerEu = 1 << 40, nodes = nodes})
  w.storage:tick()
  local f = Fake.new(w):line():ae(pat or SENSOR)
  local saved
  local d = {component = f:api(), cfg = config.load(), layout = nil,
    sleep = function(s) f:run(math.max(1, math.floor(s * 20 + 0.5))) end,
    now = function() return w.t / 20 end,
    save = function(t) saved = t end, load = function() return nil end}
  d.log = Log.new({now = function() return string.format("%6.1f", w.t / 20) end})
  return w, f, d
end

local function fill(w, k)
  for _, fl in ipairs(SENSOR.fluids) do
    local t = require("hal.ae").SOURCE[fl.name]
    w.storage:add(t, fl.amount * k)
  end
end

local function runUntil(line, f, cond, limit)
  for _ = 1, limit or 4000 do
    line:tick()
    if cond() then return true end
    f:run(10)
  end
  return false
end

local function logText(d)
  local l = {}
  for _, x in ipairs(d.log.lines) do l[#l + 1] = (x.code or "") .. " " .. x.msg end
  return table.concat(l, "\n")
end

S["партия ×4 на 2 узлах: конденсат, маршрут, наниты, сборка, возврат"] = function()
  local w, f, d = setup(2)
  local line = Line.new(d)
  T.ok(line:init(), logText(d))
  T.eq(line.st.phase, "IDLE")
  for _, n in ipairs(w.nodes) do T.ok(not n:crafting()) end
  f:batch(SENSOR, 4)
  local filled = false
  local ok = runUntil(line, f, function()
    if line.st.phase == "WAIT_COND" and not filled then fill(w, 4); filled = true end
    return f.pulses > 0 and line.st.phase == "IDLE"
  end)
  T.ok(ok, "не дошли до конца: фаза " .. line.st.phase .. "\n" .. logText(d))
  T.eq(w.nodes[1].completed + w.nodes[2].completed, 4)
  T.eq(w.nodes[1].completed, 2)
  for _, it in ipairs(f.input) do T.eq(it.size, 0) end
  T.eq(f.pulses, 1)
  T.eq(w.asm:available(), 0, "наниты вынуты")
  T.ok(f.extracted >= 1)
  T.ok(w.diode:allows("ChromaticGlass") == false, "маршрут закрыт")
  T.ok(w.storage.strength >= 4 * (1152 + 576 + 288), "напряжённость поднята")
  T.ok(w.nodes[1].failed == nil and w.nodes[2].failed == nil)
  T.ok(logText(d):find("готово: Rough Sensor Array ×4"), logText(d))
  T.ok(logText(d):find("наниты: тир 4, 30720"), logText(d))
end

S["узлы не хватают предметы, пока программа не разрешит"] = function()
  local w, f, d = setup(2)
  local line = Line.new(d)
  line:init()
  f:batch(SENSOR, 2)
  f:run(40)
  for _, n in ipairs(w.nodes) do T.ok(not n:crafting(), "узел начал сам") end
end

S["чужая партия — E-BATCH, автомат стоит"] = function()
  local w, f, d = setup(1)
  local line = Line.new(d)
  line:init()
  f.input[1] = {name = "minecraft:dirt", damage = 0, label = "Dirt", size = 5}
  runUntil(line, f, function() return line.st.phase == "FAULT" end, 50)
  T.eq(line.st.phase, "FAULT")
  T.eq(line.st.err.code, "E-BATCH")
end

S["перезапуск посреди сборки: продолжает и доводит до конца"] = function()
  local w, f, d = setup(1)
  local line = Line.new(d)
  line:init()
  f:batch(SENSOR, 1)
  local filled = false
  runUntil(line, f, function()
    if line.st.phase == "WAIT_COND" and not filled then fill(w, 1); filled = true end
    return line.st.phase == "RUN"
  end)
  T.eq(line.st.phase, "RUN")
  -- «перезагрузка»: новый автомат без сохранённого состояния, узел в работе
  local line2 = Line.new(d)
  T.ok(line2:init(), logText(d))
  T.eq(line2.st.phase, "RUN")
  T.ok(runUntil(line2, f, function() return f.pulses > 0 and line2.st.phase == "IDLE" end), logText(d))
  T.eq(w.nodes[1].completed, 1)
end

-- фейковый GPU 160×50: запоминает текст по координатам
local function fakeGpu()
  local g = {cells = {}, calls = 0}
  g.maxResolution = function() return 160, 50 end
  g.setResolution = function() end
  g.setBackground = function() g.calls = g.calls + 1 end
  g.setForeground = function() g.calls = g.calls + 1 end
  g.fill = function() g.calls = g.calls + 1 end
  g.set = function(x, y, s) assert(type(s) == "string"); g.cells[y] = (g.cells[y] or "") .. s; g.calls = g.calls + 1 end
  g.text = function() local t = {}; for y = 1, 50 do t[#t + 1] = g.cells[y] or "" end; return table.concat(t, "\n") end
  return g
end

S["экран рисуется во всех фазах, кнопки находятся по клику"] = function()
  local w, f, d = setup(2)
  local UI = require("ui")
  local line = Line.new(d)
  line:init()
  f:batch(SENSOR, 2)
  local seen, filled = {}, false
  runUntil(line, f, function()
    if line.st.phase == "WAIT_COND" and not filled then fill(w, 2); filled = true end
    if not seen[line.st.phase] then
      seen[line.st.phase] = true
      local g = fakeGpu()
      local ui = UI.new(g)
      ui:draw(line:view())
      T.ok(g.text():find("BEC"), "нет заголовка в " .. line.st.phase)
    end
    return f.pulses > 0 and line.st.phase == "IDLE"
  end)
  T.ok(seen.RUN and seen.WAIT_COND)
  local g = fakeGpu()
  local ui = UI.new(g)
  ui:draw(line:view())
  local b = ui.buttons[1]
  T.eq(ui:hit(b.x + 1, b.y), "pause")
  T.eq(ui:hit(1, 49), nil)
  T.ok(g.text():find("IO Node %(2%)"))
  -- FAULT тоже рисуется, с кодом
  line:fault("E-TEST", "проверка", "ничего")
  local g2 = fakeGpu()
  UI.new(g2):draw(line:view())
  T.ok(g2.text():find("E%-TEST"))
end

S["поле вручную: поднять всегда, опустить только без партии и не ниже объёма"] = function()
  local w, f, d = setup(1, 1000)
  local line = Line.new(d)
  line:init()
  T.ok(line:setField(5000))
  f:run(2)
  T.eq(w.storage.strength, 5000)
  T.ok(line:setField(2000), "в IDLE опускать можно")
  f:run(2)
  w.storage:add("ChromaticGlass", 1500)
  T.ok(not line:setField(1000), "ниже объёма нельзя")
  T.ok(not line:setField(0))
  line.st.phase = "RUN"
  T.ok(not line:setField(1800), "во время партии опускать нельзя")
  T.ok(line:setField(3000), "поднимать можно всегда")
  line:setFieldAuto(false)
  T.eq(d.cfg.fieldAuto, false)
  -- ввод числа на экране
  local UI = require("ui")
  local ui = UI.new(fakeGpu())
  ui:openInput(3000)
  ui:key(nil, 14); ui:key(string.byte("5"), 0)
  local r, n = ui:key(13, 28)
  T.eq(r, "apply"); T.eq(n, 3005)
  local g = fakeGpu(); ui.g = g
  ui:draw(line:view())
  T.ok(g.text():find("Напряжённость поля, L"))
  T.ok(ui:key(nil, 1) == "cancel" and ui.input == nil)
end

S["копия без жидкостей: конденсат из таблицы рецептов, запас в Поле заранее"] = function()
  local dry = {}
  for k, v in pairs(SENSOR) do dry[k] = v end
  dry.fluids = {}
  local w, f, d = setup(1, 10000, dry)
  fill(w, 1) -- запас лежит до заказа
  local line = Line.new(d)
  line:init()
  f:batch(dry, 1)
  T.ok(runUntil(line, f, function() return f.pulses > 0 and line.st.phase == "IDLE" end), logText(d))
  T.eq(w.nodes[1].completed, 1)
  T.ok(logText(d):find("таблица: Meta Material Sensor Array 1"), logText(d))
end

S["копия без жидкостей и чужие предметы — E-BATCH с причиной"] = function()
  local odd = {}
  for k, v in pairs(SENSOR) do odd[k] = v end
  odd.fluids = {}
  odd.items = {{name = "minecraft:stone", damage = 0, label = "Stone", size = 3}}
  local w, f, d = setup(1, 1000, odd)
  local line = Line.new(d)
  line:init()
  f:batch(odd, 1)
  runUntil(line, f, function() return line.st.phase == "FAULT" end, 50)
  T.eq(line.st.err.code, "E-BATCH")
  T.ok(line.st.err.msg:find("нет жидкостей"), line.st.err.msg)
end

S["паттерн нанитов есть, запаса нет — E-TIER с причиной"] = function()
  local w, f, d = setup(1)
  f.naniteStore["Transcendent Nanites"] = 0
  local line = Line.new(d)
  line:init()
  f:batch(SENSOR, 1)
  local filled = false
  runUntil(line, f, function()
    if line.st.phase == "WAIT_COND" and not filled then fill(w, 1); filled = true end
    return line.st.phase == "FAULT"
  end, 2000)
  T.eq(line.st.phase, "FAULT")
  T.ok(logText(d):find("тир 4: в подсети 0, паттерн на 64"), logText(d))
end

S["после перезапуска наниты уже в Матрице — не извлекать и не заказывать заново"] = function()
  -- по 64 нанита тиров 1, 2, 4 (как в игре): сборка долгая, перезапуск попадает в середину
  local few = {}
  for k, v in pairs(SENSOR) do few[k] = v end
  few.nanites = {[1] = 64, [2] = 64, [4] = 64}
  local w, f, d = setup(1, nil, few)
  local line = Line.new(d)
  line:init()
  f:batch(few, 1)
  local filled = false
  runUntil(line, f, function()
    if line.st.phase == "WAIT_COND" and not filled then fill(w, 1); filled = true end
    return line.st.phase == "RUN" and line.st.provided
  end)
  local ext = f.extracted or 0
  local line2 = Line.new(d)
  T.ok(line2:init())
  line2:tick()
  T.eq(f.extracted or 0, ext, "лишнее извлечение")
  T.ok(line2.st.provided)
  T.ok(runUntil(line2, f, function() return f.pulses > 0 and line2.st.phase == "IDLE" end), logText(d))
end

S["Матрица выключена — программа включает её при старте"] = function()
  local w, f, d = setup(1)
  for _, p in pairs(f.comps) do
    if p.getName and p.getName() == "multi.bec.assembler" then p.setWorkAllowed(false) end
  end
  f:run(2)
  local line = Line.new(d)
  T.ok(line:init(), logText(d))
  f:run(2)
  T.ok(line.m.array:allowed(), "Матрица не включена")
  T.ok(logText(d):find("E%-ARRAY%-OFF") or logText(d):find("Матрица была выключена"), logText(d))
  local g = fakeGpu()
  require("ui").new(g):draw(line:view())
end

return S

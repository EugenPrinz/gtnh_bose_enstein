-- Поиск и проверка машин линии (becctl probe). Без OC-библиотек: component передаётся параметром
-- ({list = function(filter) → итератор addr, type; proxy = function(addr) → прокси}).
-- Адреса в конфиге не хранятся: они принадлежат адаптерам. Машины узнаются по getName,
-- узлы нумеруются по координатам контроллера (layout), чтобы номера не прыгали.
local G = require("hal.gtbase")
local Node = require("hal.node")
local Diode = require("hal.diode")
local Storage = require("hal.storage")
local Machine = require("hal.machine")
local recipe = require("model.recipe")

local P = {}

local TYPES = {bec_io_node = Node, bec_diode = Diode, bec_storage = Storage, gt_machine = Machine}
local SINGLE = {"diode", "storage", "entangler", "array"}
local RU = {node = "IO Node", diode = "Затвор Максвелла", storage = "Поле удержания",
  entangler = "Энтанглер", array = "Матрица наблюдения"}
P.RU = RU

local function key(c) return c and (c[1] .. "," .. c[2] .. "," .. c[3]) or "?" end

local function add(list, code, msg, action) list[#list + 1] = {code = code, msg = msg, action = action} end

-- opts = {layout = прошлый layout {nodes = {{x,y,z}, ...}}, dummy = "water", maxNodes = 16}
function P.run(component, opts)
  opts = opts or {}
  local r = {node = {}, other = {}, errors = {}, warnings = {}}
  local found = {}
  for _, ctype in pairs({"bec_io_node", "bec_diode", "bec_storage", "gt_machine"}) do
    for addr in component.list(ctype, true) do
      local cls = TYPES[ctype]
      local proxy = component.proxy(addr)
      local m = cls == Diode and Diode.wrap(proxy, opts.dummy) or cls.wrap(proxy)
      local kind, name = m:kind()
      if not name then
        add(r.errors, "E-COMP", ctype .. " " .. addr:sub(1, 8) .. ": getName не отвечает", "проверить адаптер")
      elseif not kind then
        r.other[#r.other + 1] = {addr = addr, name = name} -- чужая GT-машина в сети OC
      else
        m.kindName, m.coordsT = kind, m:coords()
        found[kind] = found[kind] or {}
        table.insert(found[kind], m)
      end
    end
  end

  for _, k in ipairs(SINGLE) do
    local l = found[k] or {}
    if #l == 0 then
      add(r.errors, "E-MISSING", RU[k] .. " не найден(а) в сети OC", "поставить адаптер к контроллеру и кабель/P2P")
    elseif #l > 1 then
      add(r.errors, "E-DUP", RU[k] .. ": найдено " .. #l .. ", нужен один", "линия одна — убрать лишний адаптер")
    else
      r[k] = l[1]
    end
  end

  -- узлы: сначала по прошлому layout, новые — в конец, по координатам
  local nodes = found.node or {}
  local byKey = {}
  for _, n in ipairs(nodes) do byKey[key(n.coordsT)] = n end
  local used, gone = {}, {}
  for i, c in ipairs((opts.layout and opts.layout.nodes) or {}) do
    local n = byKey[key(c)]
    if n then r.node[#r.node + 1] = n; used[n] = true else gone[#gone + 1] = i end
  end
  local fresh = {}
  for _, n in ipairs(nodes) do if not used[n] then fresh[#fresh + 1] = n end end
  table.sort(fresh, function(a, b)
    local ca, cb = a.coordsT or {0, 0, 0}, b.coordsT or {0, 0, 0}
    for i = 1, 3 do if ca[i] ~= cb[i] then return ca[i] < cb[i] end end
    return a.addr < b.addr
  end)
  for _, n in ipairs(fresh) do r.node[#r.node + 1] = n end
  for _, i in ipairs(gone) do
    add(r.errors, "E-NODE-LOST", "узел " .. i .. " из прошлой раскладки не найден", "адаптер, чанк или узел разобран; если убран навсегда — becctl probe --reset")
  end
  if #r.node == 0 then
    add(r.errors, "E-MISSING", "ни одного IO Node", "поставить адаптер к контроллеру узла")
  elseif #r.node > (opts.maxNodes or 16) then
    add(r.errors, "E-DUP", "узлов " .. #r.node .. ", у одной Матрицы не больше " .. (opts.maxNodes or 16), "лишние адаптеры от другой линии?")
  end

  -- собранность: только у машин с энергохетчами. У IO Node их нет (питание — от Матрицы через LoS),
  -- его getEUMaxStored всегда 0, поэтому узлы так не проверяются.
  local all = {}
  for _, k in ipairs(SINGLE) do if r[k] then all[#all + 1] = {k, r[k]} end end
  for _, e in ipairs(all) do
    if not e[2]:formed() then
      add(r.errors, "E-FORM", RU[e[1]] .. (e[3] and (" " .. e[3]) or "") .. ": не собран или нет энергохетча (getEUMaxStored = 0)",
        "проверить структуру сканером GT и питание")
    end
  end

  -- затвор
  if r.diode then
    local n, types = r.diode:count(), 0
    for _ in pairs(recipe.condensates) do types = types + 1 end
    if n ~= types then
      add(r.warnings, "W-FILTERS", string.format("слотов фильтра %d, типов конденсата в модели %d", n, types),
        "обновился пак? пересобрать bec/model/data.lua")
    end
    if not r.diode:hasDummy() then
      add(r.warnings, "W-DUMMY", "нет фиктивного фильтра (" .. r.diode.dummy .. ") в слоте 1: пустые фильтры пропускают всё",
        "becctl probe --fix")
    end
  end

  -- Поле
  if r.storage then
    local s, a = r.storage:strength(), r.storage:amount()
    if s and a > s then
      add(r.warnings, "W-FIELD", string.format("объём %d L > напряжённости %d: идёт распад", a, s), "поднять напряжённость поля")
    end
    if not r.storage:allowed() then
      add(r.errors, "E-FIELD-OFF", "Поле выключено", "becctl probe --fix включит; запас мог стереться")
    end
  end

  r.layout = {nodes = {}}
  for i, n in ipairs(r.node) do r.layout.nodes[i] = n.coordsT end
  r.ok = #r.errors == 0
  return r
end

-- Безопасные исправления: фиктивный фильтр (закрыть маршрут) и включить Поле
function P.fix(r)
  local done = {}
  local busy = false
  for _, n in ipairs(r.node) do
    local st = n:state()
    if st and st ~= "idle" then busy = true end
  end
  if r.diode and not r.diode:hasDummy() and busy then
    done[#done + 1] = "затвор не тронут: узлы заняты рецептом (закрыть маршрут сейчас = провал партии)"
  elseif r.diode and not r.diode:hasDummy() then
    local ok, e = r.diode:close()
    done[#done + 1] = ok and "затвор: маршрут закрыт, фиктивный фильтр в слоте 1" or ("затвор: " .. tostring(e))
  end
  if r.storage and not r.storage:allowed() then
    r.storage:setAllowed(true)
    done[#done + 1] = "Поле включено"
  end
  return done
end

return P

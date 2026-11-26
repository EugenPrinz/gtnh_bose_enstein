-- main — управление линией BEC с экраном. Запуск: cd /home/bec && main   (выход: Q или Ctrl+C)
-- Поле: [Изменить] → число с клавиатуры, Enter/Esc; [Авто] — авторегулировка под партию (сохраняется в bec.cfg)
local dir = (debug.getinfo(1, "S").source:match("^@(.*/)") or "./")
package.path = dir .. "?.lua;" .. package.path
for name in pairs(package.loaded) do
  if name:match("^hal%.") or name:match("^model%.") or name == "line" or name == "ui" or name == "log" or name == "config" then
    package.loaded[name] = nil
  end
end

local component = require("component")
local computer = require("computer")
local event = require("event")
local serialization = require("serialization")
local filesystem = require("filesystem")
local shell = require("shell")
local term = require("term")
local Line = require("line")
local UI = require("ui")
local Log = require("log")
local config = require("config")

local function read(path)
  local f = io.open(path, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end
local function write(path, s)
  filesystem.makeDirectory(filesystem.path(path))
  local f = io.open(path, "w")
  if not f then return false end
  f:write(s)
  f:close()
  return true
end

local CFG = "/etc/bec/bec.cfg"
local cfg = config.load(read, serialization.unserialize, CFG)
-- записать одну настройку в bec.cfg, не трогая остальные
local function saveCfg(k, v)
  local t = {}
  local s = read(CFG)
  if s then local ok, x = pcall(serialization.unserialize, s); if ok and type(x) == "table" then t = x end end
  t[k] = v
  write(CFG, serialization.serialize(t))
end
local LAYOUT = "/etc/bec/layout.cfg"

local log = Log.new({
  now = function() return os.date("%H:%M:%S") end,
  append = function(p, line) local f = io.open(p, "a"); if f then f:write(line .. "\n"); f:close() end end,
  size = function(p) return filesystem.size(p) end,
  rotate = function(p) filesystem.remove(p .. ".old"); filesystem.rename(p, p .. ".old") end,
}, cfg.logPath, cfg.logMax)

local d = {
  component = component, cfg = cfg, log = log,
  sleep = os.sleep, now = computer.uptime,
  save = function(t) write(cfg.statePath, serialization.serialize(t)) end,
  load = function()
    local s = read(cfg.statePath)
    local ok, t = pcall(serialization.unserialize, s or "")
    if not ok or type(t) ~= "table" then return nil end
    t.since, t.t0 = nil, nil -- uptime обнулился вместе с компьютером
    return t
  end,
  layout = (function() local s = read(LAYOUT); return s and serialization.unserialize(s) end)(),
  saveLayout = function(l) write(LAYOUT, serialization.serialize(l)) end,
}

local gpu = component.gpu
local ui = UI.new(gpu)
local line = Line.new(d)

-- события — через слушатели: os.sleep внутри шагов автомата их не теряет
local pending = {}
local WAKE = "bec_wake"
local function wake() computer.pushSignal(WAKE) end
local function onTouch(_, _, x, y)
  local id = ui:hit(x, y)
  if id then pending[#pending + 1] = id; wake() end
end
local function onRedstone() wake() end
local function onKey(_, _, ch, code)
  pending[#pending + 1] = {key = ch, code = code}
  wake()
end
event.listen("touch", onTouch)
event.listen("redstone_changed", onRedstone)
event.listen("key_down", onKey)

local function cleanup()
  event.ignore("touch", onTouch)
  event.ignore("redstone_changed", onRedstone)
  event.ignore("key_down", onKey)
  ui:close()
  term.clear()
end

local function guard(f, ...)
  local ok, e = xpcall(f, debug.traceback, ...)
  if not ok then
    local h = io.open(cfg.logPath, "a")
    if h then h:write(tostring(e) .. "\n"); h:close() end
    pcall(line.fault, line, "E-INTERNAL", tostring(e):match("[^\n]*"), "смотреть " .. cfg.logPath .. ", затем [Сброс]")
  end
  return ok
end

local function draw() pcall(ui.draw, ui, line:view()) end

local nLayout = 0
for _ in pairs(d.layout or {}) do nLayout = nLayout + 1 end
log:info("старт BEC, раскладка узлов: " .. nLayout)
guard(line.init, line)
draw()

local running = true
while running do
  local acts = pending
  pending = {}
  for _, a in ipairs(acts) do
    if type(a) == "table" then
      if ui.input then
        local r, n = ui:key(a.key, a.code)
        if r == "apply" then
          local ok, e = line:setField(n)
          if ok then ui.input = nil else ui.input.err = tostring(e) end
        end
      elseif a.code == 16 or a.key == string.byte("q") or a.key == string.byte("Q") then running = false -- клавиша Q в любой раскладке
      end
    elseif a == "field" then
      if ui.input then ui.input = nil else
        local cur = line.m and line.m.storage and line.m.storage:strength()
        ui:openInput(cur)
      end
    elseif a == "fieldauto" then
      line:setFieldAuto(not cfg.fieldAuto)
      saveCfg("fieldAuto", cfg.fieldAuto)
    elseif a == "quit" then running = false
    elseif a == "pause" then
      line.st.paused = not line.st.paused
      log:info(line.st.paused and "пауза: новые партии не берутся" or "пауза снята")
      line:save()
    elseif a == "reset" then
      log:info("сброс")
      guard(line.reset, line)
    elseif a == "diag" then
      cleanup()
      shell.execute(dir .. "becctl.lua", nil, "diag")
      ui = UI.new(gpu)
      event.listen("touch", onTouch); event.listen("redstone_changed", onRedstone); event.listen("key_down", onKey)
      log:info("снимок: /home/bec-diag.txt")
    end
  end
  if not running then break end
  guard(line.tick, line)
  draw()
  local ok, err = pcall(event.pull, cfg.poll, WAKE)
  if not ok then running = false end -- Ctrl+C
end
cleanup()
print("BEC остановлен. Узлы остались в текущем состоянии; повторный запуск продолжит партию.")

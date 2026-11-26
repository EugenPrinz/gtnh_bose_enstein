-- becctl — служебные команды линии BEC (OpenOS).
--   becctl probe [--fix] [--reset]   найти машины, проверить, сохранить раскладку узлов
--   becctl diag [файл]               снимок всех машин в файл (по умолчанию /home/bec-diag.txt)
local dir = (debug.getinfo(1, "S").source:match("^@(.*/)") or "./")
package.path = dir .. "?.lua;" .. package.path
-- OpenOS держит модули require в памяти до перезагрузки: после install-bec выгружаем свои, чтобы взять новые
for name in pairs(package.loaded) do
  if name:match("^hal%.") or name:match("^model%.") then package.loaded[name] = nil end
end

local component = require("component")
local serialization = require("serialization")
local filesystem = require("filesystem")
local shell = require("shell")
local probe = require("hal.probe")

local LAYOUT = "/etc/bec/layout.cfg"
local args, opts = shell.parse(...)

local function readLayout()
  local f = io.open(LAYOUT, "r")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return serialization.unserialize(s)
end

local function writeLayout(l)
  filesystem.makeDirectory("/etc/bec")
  local f = assert(io.open(LAYOUT, "w"))
  f:write(serialization.serialize(l))
  f:close()
end

local ulen = (utf8 and utf8.len) or function(x) return #x end
local function pad(x, n) return x .. string.rep(" ", math.max(1, n - (ulen(x) or #x))) end

local function c3(c) return c and string.format("%d %d %d", c[1], c[2], c[3]) or "?" end

local function cmdProbe()
  local prev = not opts.reset and readLayout() or nil
  local r = probe.run(component, {layout = prev})
  for _, k in ipairs({"entangler", "storage", "diode", "array"}) do
    local m = r[k]
    print(pad(probe.RU[k], 20) .. (m and (m.addr:sub(1, 8) .. "  @ " .. c3(m.coordsT)) or "—"))
  end
  for i, n in ipairs(r.node) do
    print(pad("IO Node " .. i, 20) .. n.addr:sub(1, 8) .. "  @ " .. c3(n.coordsT) .. "  " .. (n:state() or "?"))
  end
  for _, o in ipairs(r.other) do print("  (не BEC) " .. o.name .. " " .. o.addr:sub(1, 8)) end
  for _, e in ipairs(r.errors) do print("✗ " .. e.code .. ": " .. e.msg .. "\n    → " .. e.action) end
  for _, w in ipairs(r.warnings) do print("! " .. w.code .. ": " .. w.msg .. "\n    → " .. w.action) end
  if opts.fix then
    for _, d in ipairs(probe.fix(r)) do print("fix: " .. d) end
  end
  if #r.node > 0 then
    writeLayout(r.layout)
    print("раскладка узлов: " .. LAYOUT .. " (" .. #r.node .. ")")
  end
  print(r.ok and "OK" or ("ошибок: " .. #r.errors))
end

local function dump(f, t, ind)
  ind = ind or ""
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
  for _, k in ipairs(keys) do
    local v = t[k]
    if type(v) == "table" then
      f:write(ind, tostring(k), ":\n")
      dump(f, v, ind .. "  ")
    else
      f:write(ind, tostring(k), " = ", tostring(v), "\n")
    end
  end
end

local function cmdDiag()
  local path = args[2] or "/home/bec-diag.txt"
  local r = probe.run(component, {layout = readLayout()})
  local f = assert(io.open(path, "w"))
  f:write("BEC diag ", os.date(), "\n")
  local function one(title, m)
    f:write("\n== ", title, "\n")
    dump(f, m:snapshot(), "  ")
    f:write("  sensor:\n")
    for _, l in ipairs(m:info()) do f:write("    ", tostring(l), "\n") end
  end
  for _, k in ipairs({"entangler", "storage", "diode", "array"}) do if r[k] then one(probe.RU[k], r[k]) end end
  for i, n in ipairs(r.node) do one("IO Node " .. i, n) end
  f:write("\n== probe\n")
  for _, e in ipairs(r.errors) do f:write("  ✗ ", e.code, ": ", e.msg, "\n") end
  for _, w in ipairs(r.warnings) do f:write("  ! ", w.code, ": ", w.msg, "\n") end
  f:close()
  print("снимок: " .. path)
end

local cmd = args[1]
if cmd == "probe" then cmdProbe()
elseif cmd == "diag" then cmdDiag()
else
  print("becctl probe [--fix] [--reset] — найти машины, проверить, сохранить раскладку узлов")
  print("  --fix  — фиктивный фильтр затвора и включение Поля (только между партиями)")
  print("becctl diag [файл] — снимок всех машин для разбора проблем")
end

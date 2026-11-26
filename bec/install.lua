-- Установка/обновление BEC в /home/bec (нужна Internet Card).
--   wget -f https://raw.githubusercontent.com/EugenPrinz/gtnh_bose_enstein/main/bec/install.lua /home/install-bec.lua
--   install-bec                    — обновить до последней версии (ветка main), если она новее установленной
--   install-bec --force            — переустановить, даже если версия та же
--   install-bec --branch=<ветка>   — другая ветка
-- Сначала качается манифест version.lua (номер версии + файлы с размерами), затем все файлы во временные.
-- Размер не совпал — GitHub отдал старую копию из кеша: ничего не ставится, установленная версия цела.
-- Файлы заменяются только когда скачаны все — смеси старых и новых не бывает.
local shell = require("shell")
local filesystem = require("filesystem")
local internet = require("internet")

local _, opts = shell.parse(...)
local branch = type(opts.branch) == "string" and opts.branch or "main"
local BASE = "https://raw.githubusercontent.com/EugenPrinz/gtnh_bose_enstein/" .. branch .. "/bec/"
local DEST = "/home/bec/"

-- Скачать url целиком; nil, ошибка — при любом сбое (HTTP-код ≠ 200, обрыв, пустой ответ)
local function fetch(url)
  local ok, res = pcall(function()
    local req = internet.request(url, nil, {["Cache-Control"] = "no-cache"})
    local parts = {}
    for chunk in req do parts[#parts + 1] = chunk end
    local mt = getmetatable(req)
    local code = mt and mt.__index and mt.__index.response and select(1, mt.__index.response())
    if code and code ~= 200 then error("HTTP " .. tostring(code)) end
    return table.concat(parts)
  end)
  if not ok then return nil, tostring(res) end
  if #res == 0 then return nil, "пустой ответ" end
  if res:match("^404: Not Found") then return nil, "404" end
  return res
end

-- Манифест: таблица {version, date, files = {{путь, размер}}}
local function manifest(src)
  local f = src and load(src, "=version.lua", "t", {})
  local ok, t = pcall(f or error)
  if ok and type(t) == "table" and type(t.version) == "string" and type(t.files) == "table" then return t end
end

local function installed()
  local h = io.open(DEST .. "version.lua", "r")
  if not h then return nil end
  local s = h:read("*a")
  h:close()
  return manifest(s)
end

local function selfUpdate()
  local b = fetch(BASE .. "install.lua")
  if b then
    local h = io.open("/home/install-bec.lua", "w")
    if h then h:write(b); h:close() end
  end
end

print("ветка: " .. branch)
local src, err = fetch(BASE .. "version.lua")
local new = manifest(src)
if not new then
  print("✗ манифест version.lua не получен: " .. tostring(err or "не читается"))
  return
end
local old = installed()
local oldV = old and old.version or "не установлено"
if old and old.version == new.version and not opts.force then
  print("обновлений нет: " .. new.version .. " (" .. tostring(new.date) .. ")  · переустановить: install-bec --force")
  selfUpdate()
  return
end
print(string.format("версия: %s → %s (%s)", oldV, new.version, tostring(new.date)))

-- 1. всё во временные файлы, со сверкой размера
local staged, bad = {}, 0
for _, e in ipairs(new.files) do
  local f, size = e[1], e[2]
  filesystem.makeDirectory(filesystem.path(DEST .. f))
  local body, ferr = fetch(BASE .. f)
  if not body then
    bad = bad + 1
    print("✗ " .. f .. " — " .. ferr)
  elseif #body ~= size then
    bad = bad + 1
    print(string.format("✗ %-22s %6d байт, ждали %d — старая копия из кеша GitHub", f, #body, size))
  else
    local h = assert(io.open(DEST .. f .. ".new", "w"))
    h:write(body)
    h:close()
    staged[#staged + 1] = f
    print(string.format("✓ %-22s %6d байт", f, #body))
  end
end
if bad > 0 then
  for _, f in ipairs(staged) do filesystem.remove(DEST .. f .. ".new") end
  print(string.format("не установлено: %d файлов не сошлись, осталась версия %s. Повторить через 2–5 минут.", bad, oldV))
  return
end

-- 2. всё скачано — заменить разом, манифест последним
for _, f in ipairs(staged) do
  filesystem.remove(DEST .. f)
  filesystem.rename(DEST .. f .. ".new", DEST .. f)
end
local h = assert(io.open(DEST .. "version.lua", "w"))
h:write(src)
h:close()
selfUpdate()
print("готово: BEC " .. new.version .. " в " .. DEST .. " — проверка: cd /home/bec && becctl probe; запуск: main")

-- Установка/обновление BEC в /home/bec (нужна Internet Card).
--   wget -f https://raw.githubusercontent.com/EugenPrinz/gtnh_bose_enstein/main/bec/install.lua /home/install-bec.lua
--   install-bec                    — установить или обновить (ветка main)
--   install-bec --branch=<ветка>   — другая ветка
-- Каждый файл качается во временный и заменяет старый только при успехе: сбой не портит установленную версию.
local shell = require("shell")
local filesystem = require("filesystem")
local internet = require("internet")

local _, opts = shell.parse(...)
local branch = type(opts.branch) == "string" and opts.branch or "main"
local BASE = "https://raw.githubusercontent.com/EugenPrinz/gtnh_bose_enstein/" .. branch .. "/bec/"
local DEST = "/home/bec/"
local FILES = {
  "becctl.lua", "main.lua", "line.lua", "ui.lua", "log.lua", "config.lua",
  "hal/ae.lua", "hal/shuttle.lua", "hal/nanites.lua",
  "hal/gtbase.lua", "hal/node.lua", "hal/diode.lua", "hal/storage.lua", "hal/machine.lua", "hal/probe.lua",
  "model/data.lua", "model/recipe.lua", "model/timing.lua", "model/entangler.lua", "model/strategy.lua",
}

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

print("ветка: " .. branch)
for _, d in ipairs({"", "hal", "model"}) do filesystem.makeDirectory(DEST .. d) end
local failed = 0
for _, f in ipairs(FILES) do
  local body, err = fetch(BASE .. f)
  if body then
    local tmp = DEST .. f .. ".new"
    local h = assert(io.open(tmp, "w"))
    h:write(body)
    h:close()
    filesystem.remove(DEST .. f)
    filesystem.rename(tmp, DEST .. f)
    print(string.format("✓ %-22s %6d байт", f, #body))
  else
    failed = failed + 1
    print("✗ " .. f .. " — " .. err)
  end
end
-- сам установщик тоже обновляется: новые файлы в списке подхватятся при следующем запуске
local self_body = fetch(BASE .. "install.lua")
if self_body then
  local h = io.open("/home/install-bec.lua", "w")
  if h then h:write(self_body); h:close(); print("✓ install-bec обновлён") end
end
if failed > 0 then
  print("не скачано: " .. failed .. " — старые версии этих файлов не тронуты")
else
  print("готово: " .. DEST .. " — проверка: cd /home/bec && becctl probe; запуск: main")
end

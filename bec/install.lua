-- Установка/обновление BEC в /home/bec (нужна Internet Card).
--   wget -f https://raw.githubusercontent.com/EugenPrinz/gtnh_bose_enstein/main/bec/install.lua /home/install-bec.lua
--   install-bec [ветка]
local shell = require("shell")
local filesystem = require("filesystem")

local args = shell.parse(...)
local branch = args[1] or "main"
local BASE = "https://raw.githubusercontent.com/EugenPrinz/gtnh_bose_enstein/" .. branch .. "/bec/"
local DEST = "/home/bec/"
local FILES = {
  "becctl.lua",
  "hal/gtbase.lua", "hal/node.lua", "hal/diode.lua", "hal/storage.lua", "hal/machine.lua", "hal/probe.lua",
  "model/data.lua", "model/recipe.lua", "model/timing.lua", "model/entangler.lua", "model/strategy.lua",
}

for _, d in ipairs({"", "hal", "model"}) do filesystem.makeDirectory(DEST .. d) end
local failed = 0
for _, f in ipairs(FILES) do
  local ok = shell.execute("wget -fq " .. BASE .. f .. " " .. DEST .. f)
  print((ok and "✓ " or "✗ ") .. f)
  if not ok then failed = failed + 1 end
end
if failed > 0 then
  print("не скачано: " .. failed)
else
  print("готово: " .. DEST .. "  — запуск: cd /home/bec && becctl probe")
end

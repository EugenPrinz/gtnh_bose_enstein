-- Запуск: lua5.3 tests/run.lua [фильтр]   (из корня репозитория)
package.path = "./bec/?.lua;./?.lua;" .. package.path

local T = require("tests.t")
local files = {"tests.test_recipe", "tests.test_entangler", "tests.test_sim", "tests.test_timing", "tests.test_strategy", "tests.test_hal", "tests.test_line"}
local filter = arg[1]
local pass, fail = 0, 0
for _, f in ipairs(files) do
  local suite = require(f)
  local names = {}
  for name in pairs(suite) do names[#names + 1] = name end
  table.sort(names)
  for _, name in ipairs(names) do
    if not filter or name:find(filter, 1, true) then
      local ok, err = pcall(suite[name])
      if ok then
        pass = pass + 1
      else
        fail = fail + 1
        print("✗ " .. f .. " · " .. name .. "\n    " .. tostring(err))
      end
    end
  end
end
print(string.format("%d ✓, %d ✗", pass, fail))
os.exit(fail == 0 and 0 or 1)

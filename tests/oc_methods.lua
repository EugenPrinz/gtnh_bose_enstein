-- Методы компонентов из дампа component.methods в игре (GTNH 2.9.1, 2026-11-25).
-- HAL обязан вызывать только их: tests/test_hal.lua сверяет.
local common = {"getAverageElectricInput", "getAverageElectricOutput", "getCoordinates", "getEUCapacity",
  "getEUCapacityString", "getEUInputAverage", "getEUMaxStored", "getEUOutputAverage", "getEUStored",
  "getInputVoltage", "getName", "getOutputAmperage", "getOutputVoltage", "getOwnerName", "getSensorInformation",
  "getSteamCapacity", "getSteamMaxStored", "getSteamStored", "getStoredEU", "getStoredEUString", "getStoredSteam",
  "getWorkMaxProgress", "getWorkProgress", "hasWork", "isMachineActive", "isWorkAllowed", "setWorkAllowed"}

local extra = {
  gt_machine = {},
  bec_diode = {"getCondensateFilterAt", "getCondensateFilterCount", "getCondensateFilters", "getParameters",
    "setCondensateFilterAt", "setCondensateFilters", "setParameter"},
  bec_storage = {"getFieldStrength", "getParameters", "getStoredCondensate", "setFieldStrength", "setParameter"},
  bec_io_node = {"getAvailableNanites", "getConsumedCondensate", "getManualSlowdown", "getMaxParallel",
    "getMinParallel", "getParallelRecipesInProgress", "getParameters", "getProvidedTier", "getRecipeSteps",
    "getRequiredCondensate", "getRequiredTier", "getSlowdowns", "getState", "setMaxParallel", "setMinParallel",
    "setParameter", "setSpeedDivisor"},
}

-- AE2/OC-компоненты, которыми пользуется программа (методы, которые она вызывает; сверено с программой Armisael5,
-- работающей в игре): копии паттернов, Input, подсеть нанитов, Redstone I/O, Transposer
extra.fluid_interface = {"getInterfacePattern"}
extra.me_interface = {"getItemsInNetwork"}
extra.me_controller = {"getCraftables", "getItemsInNetwork"}
extra.redstone = {"setOutput", "getInput", "getOutput"}
extra.transposer = {"getInventorySize", "getStackInSlot", "transferItem"}
local NOGT = {fluid_interface = true, me_interface = true, me_controller = true, redstone = true, transposer = true}

local M = {}
for t, l in pairs(extra) do
  local set = {}
  if not NOGT[t] then for _, m in ipairs(common) do set[m] = true end end
  for _, m in ipairs(l) do set[m] = true end
  M[t] = set
end
return M

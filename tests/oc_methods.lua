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

local M = {}
for t, l in pairs(extra) do
  local set = {}
  for _, m in ipairs(common) do set[m] = true end
  for _, m in ipairs(l) do set[m] = true end
  M[t] = set
end
return M

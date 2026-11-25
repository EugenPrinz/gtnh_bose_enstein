-- Сгенерировано tools/build3d/luadata.py из GT5U 5.09.54.275. Не править руками.
local M = {}

-- энтанглер: вход unit L исходной жидкости → unit L конденсата за параллель, dur тиков, eut EU/t
M.condensates = {
  Neutronium = {id = "neutronium", unit = 144, dur = 800, eut = 1966080},
  CosmicNeutronium = {id = "cosmicneutronium", unit = 144, dur = 800, eut = 1966080},
  Bedrockium = {id = "bedrockium", unit = 144, dur = 800, eut = 1966080},
  ChromaticGlass = {id = "chromaticglass", unit = 144, dur = 800, eut = 7864320},
  CelestialTungsten = {id = "celestialtungsten", unit = 144, dur = 800, eut = 7864320},
  Infinity = {id = "infinity", unit = 144, dur = 800, eut = 31457280},
  Hypogen = {id = "hypogen", unit = 144, dur = 1600, eut = 125829120},
  TranscendentMetal = {id = "transcendentmetal", unit = 144, dur = 1600, eut = 125829120},
  DimensionallyShiftedSuperfluid = {id = "dimshiftedsuperfluid", unit = 1000, dur = 1600, eut = 31457280},
  PhononMedium = {id = "phononmedium", unit = 1000, dur = 2400, eut = 31457280},
  QuarkGluonPlasma = {id = "quarkgluonplasma", unit = 1000, dur = 3200, eut = 31457280},
  SpaceTime = {id = "spacetime", unit = 144, dur = 3200, eut = 125829120},
  Time = {id = "time", unit = 144, dur = 3200, eut = 125829120},
  Space = {id = "space", unit = 144, dur = 3200, eut = 125829120},
  BoundlessCosmicSolder = {id = "cosmicsolder", unit = 1000, dur = 3200, eut = 125829120},
  MHDCSM = {id = "mhdcsm", unit = 144, dur = 4800, eut = 503316480},
  MagMatter = {id = "magmatter", unit = 144, dur = 4800, eut = 503316480},
  Universium = {id = "universium", unit = 144, dur = 4800, eut = 503316480},
  Eternity = {id = "eternity", unit = 144, dur = 4800, eut = 503316480},
}

-- рецепты IO Node: tiers — тиры нанитов по шагам (1..10), cond — L конденсата на 1 параллель
M.recipes = {
  {name = "Meta Material Sensor Array 1", tiers = {4, 1, 2, 1}, cond = {ChromaticGlass = 1152, Infinity = 576, TranscendentMetal = 288}, dur = 6000, eut = 7864320, tier = "UEV", out = 1},
  {name = "Condensate Guidance Coil", tiers = {3, 1, 1, 1, 4, 2, 1, 1}, cond = {ChromaticGlass = 36864, Infinity = 2304, CelestialTungsten = 2304}, dur = 3000, eut = 31457280, tier = "UIV", out = 1},
  {name = "Electromagnetic Waveguide", tiers = {3, 4, 1, 1}, cond = {ChromaticGlass = 73728, Infinity = 1152, CelestialTungsten = 1152}, dur = 4800, eut = 31457280, tier = "UIV", out = 8},
  {name = "Structure Casing", tiers = {1, 1, 1, 1, 2, 2, 4, 3}, cond = {Hypogen = 576, Neutronium = 4608}, dur = 6000, eut = 31457280, tier = "UIV", out = 2},
  {name = "Guidance Casing", tiers = {1, 2, 2, 4, 3, 1, 1, 1}, cond = {Hypogen = 576, CosmicNeutronium = 4608}, dur = 6000, eut = 31457280, tier = "UIV", out = 2},
  {name = "Gravitational Lens", tiers = {3, 3, 2, 4, 1, 1, 1, 1, 1, 1, 1, 1, 2}, cond = {ChromaticGlass = 34992}, dur = 6000, eut = 31457280, tier = "UIV", out = 1},
  {name = "Condensate Transformative Coil", tiers = {2, 1, 2, 1, 3, 3, 4}, cond = {ChromaticGlass = 36864, Infinity = 2304, CelestialTungsten = 2304}, dur = 6000, eut = 31457280, tier = "UIV", out = 1},
  {name = "Meta Material Shielding 1", tiers = {4, 1, 1, 3, 1}, cond = {ChromaticGlass = 288, TranscendentMetal = 288}, dur = 6000, eut = 31457280, tier = "UIV", out = 1},
  {name = "Graviton Modulator 1", tiers = {1, 2, 1, 1, 1, 1, 3, 4, 2, 3}, cond = {ChromaticGlass = 4608, Infinity = 4608}, dur = 9000, eut = 31457280, tier = "UIV", out = 3},
  {name = "Fine-structure Constant Manipulator", tiers = {3, 4, 1, 1, 3, 2, 1, 1}, cond = {ChromaticGlass = 36864, Infinity = 4608, CelestialTungsten = 4608}, dur = 12000, eut = 31457280, tier = "UIV", out = 8},
  {name = "Electromagnetically-isolated Casing", tiers = {4, 1, 1, 1, 3, 2, 1, 1}, cond = {ChromaticGlass = 36864, Infinity = 4608, CelestialTungsten = 4608}, dur = 24000, eut = 31457280, tier = "UIV", out = 16},
  {name = "Coherence-preserving Plasma Conduit", tiers = {4, 1, 1, 2, 1, 3, 1, 1}, cond = {ChromaticGlass = 36864, Infinity = 4608, CelestialTungsten = 4608}, dur = 24000, eut = 31457280, tier = "UIV", out = 8},
  {name = "Magnetic Confinement Casing", tiers = {1, 2, 1, 1, 1, 1, 2, 3, 4}, cond = {Hypogen = 576, CelestialTungsten = 4608}, dur = 36000, eut = 31457280, tier = "UIV", out = 12},
  {name = "Graviton Modulator 2", tiers = {1, 1, 1, 1, 1, 2, 3, 3, 3, 2, 2, 4}, cond = {ChromaticGlass = 9216, Infinity = 4608, TranscendentMetal = 4608}, dur = 6000, eut = 125829120, tier = "UMV", out = 1},
  {name = "Transdimensional Alignment Matrix (Convergence)", tiers = {1, 2, 4, 4, 4, 3, 2, 4, 1, 1, 2, 3}, cond = {SpaceTime = 27648, DimensionallyShiftedSuperfluid = 10000, Space = 4608}, dur = 12000, eut = 125829120, tier = "UMV", out = 1},
  {name = "UMV Component Assembly Line Casing (UMV CoAL)", tiers = {1, 1, 3, 3, 3, 2, 2, 1, 4, 4, 2, 2}, cond = {Space = 3456, SpaceTime = 1728, DimensionallyShiftedSuperfluid = 10000}, dur = 12000, eut = 125829120, tier = "UMV", out = 1},
  {name = "Reinforced Temporal Structure Casing", tiers = {4, 1, 1, 2, 1, 1, 4, 1, 1, 1, 1, 2}, cond = {Neutronium = 73728, CosmicNeutronium = 73728, Bedrockium = 36864, Time = 1440}, dur = 800000, eut = 125829120, tier = "UMV", out = 4},
  {name = "Reinforced Spatial Structure Casing", tiers = {4, 1, 1, 2, 1, 1, 4, 1, 1, 1, 1, 2}, cond = {Neutronium = 73728, CosmicNeutronium = 73728, Bedrockium = 36864, Space = 1440}, dur = 800000, eut = 125829120, tier = "UMV", out = 4},
  {name = "Infinite Spacetime Boundary Casing", tiers = {4, 1, 2, 1, 1, 3, 4, 3, 1, 1, 1, 1, 1, 1, 1, 1}, cond = {Neutronium = 147456, CosmicNeutronium = 147456, Bedrockium = 36864, SpaceTime = 18432}, dur = 800000, eut = 125829120, tier = "UMV", out = 1},
  {name = "Phonon Transmission Conduit", tiers = {1, 1, 2, 3, 4, 3, 2, 1}, cond = {Hypogen = 4608, PhononMedium = 2000, CelestialTungsten = 2304}, dur = 6000, eut = 503316480, tier = "UXV", out = 2},
  {name = "Meta Material Sensor Array 2", tiers = {5, 2, 3, 2}, cond = {ChromaticGlass = 1728, Infinity = 864, BoundlessCosmicSolder = 2000}, dur = 6000, eut = 31457280, tier = "UIV", out = 1},
  {name = "Meta Material Shielding 2", tiers = {6, 3, 3, 5, 3}, cond = {ChromaticGlass = 576, TranscendentMetal = 576}, dur = 6000, eut = 125829120, tier = "UMV", out = 1},
  {name = "Meta Material Sensor Array 3", tiers = {6, 3, 4, 3}, cond = {ChromaticGlass = 2304, Infinity = 1152, BoundlessCosmicSolder = 3000}, dur = 6000, eut = 125829120, tier = "UMV", out = 1},
  {name = "Meta Material Sensor Array 4", tiers = {7, 4, 5, 4}, cond = {ChromaticGlass = 3456, Infinity = 1728, BoundlessCosmicSolder = 4000}, dur = 6000, eut = 503316480, tier = "UXV", out = 1},
  {name = "Meta Material Shielding 3", tiers = {8, 5, 5, 7, 5}, cond = {ChromaticGlass = 1152, TranscendentMetal = 1152}, dur = 6000, eut = 503316480, tier = "UXV", out = 1},
  {name = "UXV Component Assembly Line Casing (UXV CoAL)", tiers = {1, 3, 3, 7, 6, 6, 5, 5, 4, 4, 2, 5, 5, 6, 8, 9}, cond = {BoundlessCosmicSolder = 5000, MHDCSM = 1152, Eternity = 1872, DimensionallyShiftedSuperfluid = 11000}, dur = 12000, eut = 125829120, tier = "UMV", out = 1},
  {name = "Graviton Modulator 3", tiers = {1, 3, 2, 2, 4, 2, 1, 7, 8, 6, 6, 9, 2, 3, 5, 8}, cond = {ChromaticGlass = 36864, Infinity = 4608, BoundlessCosmicSolder = 20000, Eternity = 18432}, dur = 6000, eut = 503316480, tier = "UXV", out = 1},
  {name = "Astral Array Fabricator", tiers = {6, 6, 6, 8, 6, 6, 6, 3, 1, 1, 2, 9, 10, 4, 5, 7}, cond = {BoundlessCosmicSolder = 1024000, Space = 524160, SpaceTime = 524160, Eternity = 262080}, dur = 144000, eut = 503316480, tier = "UXV", out = 1},
}

return M

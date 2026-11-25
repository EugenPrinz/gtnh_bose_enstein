# Сборка docs/build.html

3D-схема постройки линии BEC и модель её работы (three.js r128).

1. Исходники из GT5-Unofficial, тег `5.09.54.275` (GTNH 2.9.1): `BECStructureDefinitions.java`,
   `CondensateType.java`, `BECRecipes.java`, `BECMetaMaterialRecipes.java`. При обновлении пака заменить файлы и пересобрать.
2. `python3 parse.py` — формы 5 мультиблоков → `structs.json` (W×H×D, позиция контроллера, счётчики блоков).
3. `python3 specials.py` — контроллеры, шлюзы конденсата, люки LoS и выбранные места шлюзов (энергия, шина нанитов,
   входы/выходы узла) → `specials.json`. Сторона шлюза — открытая грань по лучу до края структуры.
4. `python3 condensates.py` — `CondensateType.java` → `condensates.json` (единица, длительность, EU/t энтанглера; в 2.9.1 — 19 типов).
5. `python3 recipes.py` — `BECRecipes.java` + правила `BECMetaMaterialRecipes.java` → `recipes_all.json` (28 рецептов).
6. `python3 build.py` — встраивает структуры, текстуры (`tex/*.png` + `.mcmeta`) в `template.html`
   → `../../docs/build.html` (путь можно задать через `OUT=`).

Текстуры: `tex/BEC_*`, `OVERLAY_*`, `EM_*` — из `GT5-Unofficial` (`assets/gregtech/textures/blocks/iconsets`, тег 5.09.54.275),
`tex/OC_*` — из `GTNewHorizons/OpenComputers` (`assets/opencomputers/textures/blocks`),
`tex/AE_*` — `GTNewHorizons/Applied-Energistics-2-Unofficial`, `tex/WL_*` — `GTNewHorizons/AE2Stuff` (wireless/side_onN: 1–16 коннектор по цвету, 18–33 хаб),
`tex/FC_*` — `GTNewHorizons/AE2FluidCraft-Rework`, `tex/GT_*` — GT5U. Принадлежат их авторам.

AE2-часть схемы повторяет `Armisael5/gtnh-bec-controller` (README, раздел 2).

Соответствие символов структуры корпусам — `StructureWrapper.addCasing` в `MTEBEC*.java`;
текстуры корпусов — `BlockCasingsBEC.getIcon` и `BlockGlass1` (мета 9).
Ось структуры: строка = y сверху вниз, символ = x слева направо (вид на контроллер), срез = z вглубь.

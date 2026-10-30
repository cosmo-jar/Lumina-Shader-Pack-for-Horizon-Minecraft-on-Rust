# Lumina Shader Pack for Horizon (Minecraft 26.3)

> **Early Preview / Work in Progress**  
> *Lumina is an active project and this is not a final release. Visual balance, features, and optimizations are continuously evolving.*

Lumina is a native WGSL shader pack built from scratch for the modern **Horizon** Rust/WGPU game engine. It is designed to be **lightweight in performance** while delivering **balanced, rich atmospheric visuals** without relying on heavy post-processing hacks or preprocessor overhead.

---

<img width="1920" height="1057" alt="image" src="https://github.com/user-attachments/assets/480268cf-afe0-4921-82bc-6078862e88c7" />

<img width="1920" height="1057" alt="image" src="https://github.com/user-attachments/assets/f1bfd7d7-4641-4d12-8cca-913ef64a247c" />

<img width="1920" height="1057" alt="image" src="https://github.com/user-attachments/assets/2fb43d22-3517-4a41-a2b1-b7e813ca7f27" />

<img width="1920" height="1057" alt="image" src="https://github.com/user-attachments/assets/4dcf29ba-eb68-4819-9faa-725711effc07" />

<img width="1920" height="1057" alt="image" src="https://github.com/user-attachments/assets/efd1a418-ecdc-48fd-bfee-400ebde7b830" />

<img width="1920" height="1057" alt="image" src="https://github.com/user-attachments/assets/555993ce-8c5f-4aae-a019-654e41898c25" />


---

## ⚠️ Important Setup Requirement
**Disable standard vanilla Minecraft clouds in game settings!**  
Go to:  
**Options > Video Settings > Details > Clouds: OFF**  
*(Настройки > Настройки графики > Элементы... > Облака: ВЫКЛ)*  
This prevents vanilla 2D/blocky clouds from clipping through Lumina's procedural 3D volumetric clouds.

---

## Features

- **Balanced Daylight & Natural Tone**: Warm sunlight, cool sky-fill ambient shadows under trees and overhangs with a clean 2:1 contrast ratio, and filmic ACES highlight roll-off.
- **Foliage Subsurface Scattering (SSS)**: Cherry blossoms and plant leaves catch warm translucent sunlight when backlit.
- **Solar Contours & Rim Lighting**: Low grass tops and mountain ridges catch a delicate golden glow when looking toward the sun.
- **Procedural 3D Volumetric Clouds**: Spherical cumulus billows with organic altitude gates and boundary-safe erosion.
- **Crystalline Water**: Animated multi-frequency wave perturbation, sunlight glints, caustics, and Fresnel sky reflections.
- **Atmospheric Fog & God Rays**: Crepuscular sun rays through trees and soft horizon depth fade.
- **Underwater Optics**: Depth-based light absorption, caustics, and subtle refraction.

---

## Configuration & In-Game Options

All options are configurable in-game under **Options > Horizon Settings > Shader Packs > Lumina**, or by editing `horizon-shaders.toml`:

### ☁️ Volumetric Clouds (`cloud_profile` & `volumetric_clouds`)
- `volumetric_clouds = true` (Default: `true`): Enable or disable 3D volumetric clouds. Turn OFF for flat sky or maximum performance.
- `cloud_profile` (Default: `"Fast"`):
  - **`"Fast"`** *(Recommended for high FPS)*: Fast 12-step raymarching. Ultra-lightweight with high performance.
  - **`"Balanced"`**: Smooth 16-step raymarching with enhanced billow contours.
  - **`"Cinematic"`**: 20-step raymarching for high-detail captures and screenshots.
- `cloud_density_opt` (Default: `1.0`): Adjusts cloud thickness and sky coverage.

### 🌧️ Rain Wetness & Procedural Puddles (`rain_puddles`)
- `rain_puddles = false` (Default: `false`):
  - By default, puddles are turned off to maximize FPS on all GPUs.
  - **To enable puddles**: Set `rain_puddles = true` in the in-game options or in `horizon-shaders.toml`.
  - When enabled during rain, organic water puddles form across grass blocks and dirt with dynamic circular raindrop impact ripples, wet surface dampening, and sky reflections.

### ☀️ Lighting & Atmosphere
- `sun_glow` (Default: `1.0`): Solar corona and horizon atmospheric scatter.
- `god_rays` (Default: `true`): Volumetric crepuscular light shafts streaming through tree canopies.
- `torch_warmth` (Default: `1.0`): Warm amber-orange radiance of torches and lanterns.
- `fog_density` (Default: `1.0`): Atmospheric distance and valley mist density.
- `water_waves` (Default: `true`): Animated 3D water waves and sunlight glints.

---
---

# Шейдер-пак Lumina для Horizon (Minecraft 26.3) [RU]

> **Ранняя версия / В разработке**  
> *Lumina находится в активной разработке, это не финальная версия. Баланс освещения, визуальные эффекты и оптимизация продолжают улучшаться.*

Lumina — это нативный WGSL шейдер-пак, созданный специально для движка **Horizon** (Rust/WGPU). Главная концепция пака — **легковесность в плане производительности (высокий FPS)** и **сбалансированная, приятная глазу атмосфера** без перегруженности лишними эффектами.

---

## ⚠️ Важная настройка перед игрой
**Обязательно отключите стандартные майнкрафтовские облака!**  
Перейдите в:  
**Настройки > Настройки графики > Элементы... > Облака: ВЫКЛ**  
*(Options > Video Settings > Details > Clouds: OFF)*  
Это необходимо, чтобы плоские квадратные облака игры не пересекались с кастомными объемными 3D-облаками Lumina.

---

## Ключевые визуальные особенности

- **Сбалансированное дневное освещение**: Тёплые солнечные лучи на открытой местности, мягкая прохладная небесная полутень под кронами сакур и деревьев, отсутствие выжигающего «ядерного» пересвета благодаря ACES-тонемаппингу.
- **Просвечивание листвы (Subsurface Scattering)**: Лепестки цветущей сакуры и листва деревьев излучают нежное тёплое свечение, когда солнце светит сквозь них.
- **Контурный свет на траве (Rim Lighting)**: На рассвете и закате верхушки травы и контуры холмов подсвечиваются золотистым ореолом.
- **Объемные 3D-облака**: Мягкие кучевые облака с естественной формой без ступенчатых срезов.
- **Кристальная вода**: Анимированная рябь волн, солнечные блики, подводные каустики и отражение неба по Френелю.
- **Лучи солнца (God Rays)**: Чистые объемные световые столбы, пробивающиеся сквозь деревья и горы.
- **Подводная оптика**: Реалистичное поглощение света на глубине (бирюзовый градиент), преломление волн и солнечные узоры на дне.

---

## Настройки в меню и конфигурации

Все параметры можно переключать прямо в игре через меню:  
**Настройки > Настройки Horizon > Шейдер-паки > Lumina** (либо в файле `horizon-shaders.toml`).

### ☁️ Режимы и профили облаков (`cloud_profile` и `volumetric_clouds`)
- `volumetric_clouds = true` (По умолчанию: `true`): Включение или полное отключение кастомных 3D-облаков. Если отключить, небо будет чистым, а FPS вырастет до максимума.
- `cloud_profile` (По умолчанию: `"Fast"`):
  - **`"Fast"`** *(Рекомендуется для максимального FPS)*: Быстрый реймаршинг в 12 шагов. Минимальная нагрузка на видеокарту.
  - **`"Balanced"`**: Оптимальный профиль с улучшенной детализацией кучевых шапок (16 шагов).
  - **`"Cinematic"`**: Высокодетализированный профиль (20 шагов) для красивых скриншотов и видео.
- `cloud_density_opt` (По умолчанию: `1.0`): Плотность и заполненность неба облаками.

### 🌧️ Намокание поверхностей и лужи (`rain_puddles`)
- `rain_puddles = false` (По умолчанию: `false`):
  - Для максимальной производительности процедурные лужи по умолчанию отключены.
  - **Как включить лужи**: Установите переключатель в настройках игры в положение `true` (или в файле `horizon-shaders.toml` пропишите `default = true` в блоке `rain_puddles`).
  - Во время дождя на дёрне и земле будут органично появляться лужи с реалистичными расходящимися кругами от падающих капель дождя и отражением неба.

### ☀️ Освещение и атмосфера
- `sun_glow` (По умолчанию: `1.0`): Яркость солнечной короны и рассеивания на горизонте.
- `god_rays` (По умолчанию: `true`): Включение/выключение объемных лучей солнца.
- `torch_warmth` (По умолчанию: `1.0`): Теплота и мягкость света факелов и фонарей.
- `fog_density` (По умолчанию: `1.0`): Плотность атмосферного тумана.
- `water_waves` (По умолчанию: `true`): Анимация 3D-волн и бликов на воде.

---

## Лицензия / License

Distributed under the **GNU General Public License v3.0 or later** (`GPL-3.0-or-later`).  
See [LICENSE](LICENSE) for full details.

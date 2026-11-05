# Lumina Shader Pack for Horizon (Minecraft 26.3) — v1.0.0

Lumina is a native WGSL shader pack engineered specifically for the modern **Horizon** Rust/WGPU game engine. It is designed to deliver **radiant, realistic, and rich atmospheric visuals** while maintaining **exceptionally high frame rates** without heavy post-processing bloat.

---

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/edef0d22-c361-489d-8a01-074a71db805f" />

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/d0f7ef6a-972c-4d16-a9ed-7ebbe1308e80" />

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/639207fc-d1a9-4d54-ab3a-d6bab7f43b80" />

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/b2b4b6c4-8be9-446f-ba63-4598f2f29bb4" />

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/d2f64282-ac44-416d-b476-d3fad04a6932" />

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/fa67a093-5a00-4ffd-9a86-7b42db2485a7" />

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/9afe340a-bf46-45fd-bcdd-a8d88ac6afe1" />

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/c9b85ba7-d502-477e-9930-12ebd46fec60" />

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/d8b05f9a-9d07-4b7a-8a91-99bf23c40baa" />

<img width="2560" height="1440" alt="image" src="https://github.com/user-attachments/assets/101558b5-8ef8-4a90-b7a9-8098ae97fbeb" />

---

## ⚠️ Recommended Game Setup
**Disable standard Minecraft clouds in game settings:**  
Set **Clouds: OFF** in your video details settings to let Lumina's procedural 3D volumetric clouds render without interference.

---

## 🌟 Key Features

### ☀️ Radiant Daytime & Atmosphere
- **Warm Golden Sunlight**: Natural warm sunbeams illuminating open terrain, contrasted with cool, radiant azure ambient skylight in shadows.
- **Directional Hemispherical Sky Occlusion**: Physically accurate dome lighting. Horizontal surfaces receive full zenith sky light, vertical walls receive half-hemisphere fill, and downwards-facing surfaces (ceilings, eaves) receive soft ground bounce.
- **Deep Roof & Overhang Shadowing**: Real non-linear ambient light falloff under house roofs, porches, and balconies, creating deep architectural contrast and cozy shaded interiors.
- **Selective Vibrance**: Midtone chroma enhancement that makes green grass, foliage, and flowers lush and vibrant without oversaturating bright highlights or lava.
- **Subsurface Scattering (SSS) & Solar Rim**: Translucent leaf glowing on cherry blossoms and foliage when backlit by the sun, plus delicate golden rim highlights on grass tops and ridges.

### 🌓 Dramatic Twilight & Midnight
- **Magical Sunset / Golden Hour**: Warm amber sunlight and soft rose-violet twilight horizons.
- **Midnight Navy**: Silver moonlight casting soft shadows, with dark celestial blue ambient illumination.

### 🛡️ Directional Shadows & Ambient Occlusion
- **Real-Time Sun & Moon Shadows**: Cast by terrain, blocks, foliage, and entities with distortion-aware bias calculation for razor-sharp grass shadows at any distance without acne.
- **Deep Contact Vertex AO**: Pronounced contact shadows in corners and crevices under roofs and against walls.

### 🔍 Clarity Anti-Aliasing (FXAA)
- **Edge-Selective Smoothing**: Smooths jagged pixel staircases on block edges, roofs, and stair blocks without smearing or blurring textures.
- **Clarity Guard & Micro-Sharpening**: Flat surfaces, pixel-art textures, wood planks, stone, and UI remain 100% untouched and razor-sharp.
- **Three Modes**: *Sharp* (crisp edges + HD texture clarity), *Smooth* (cinematic edge softening), and *Off* (native raw pixels).

### 🌊 Physical Water, Reflections & Underwater World
- **Dual Reflection Pipeline**: High-speed Screen Space Reflections (SSR) for smooth 200+ FPS reflections, combined with planar mirror reflections of mountains, trees, and terrain.
- **Beer-Lambert Light Absorption**: Crystal-clear shallow waters transitioning into sapphire/turquoise depth.
- **Snell's Window**: Looking up from underwater provides a crystal-clear, undulating view of the sun, sky, clouds, and trees, with total internal reflection at glancing angles.
- **Underwater Optics**: Animated sunlight caustics dancing across the seabed, sand, and corals, combined with gentle refractive screen wobble and oceanic depth absorption.

### ☁️ Procedural 3D Volumetric Clouds
- Multi-octave cumulus cloud billows with organic altitude gates, realistic sun phase scattering, and boundary-safe edge erosion with zero slicing artifacts.
- Includes **Fast**, **Balanced**, and **Cinematic** performance profiles.

### 🌧️ Rain Puddles & Atmospheric Weather
- **Procedural Rain Puddles**: Form naturally across grass blocks and dirt during rainfall with concentric raindrop impact ripples and sky reflections.
- **Native Weather Stage**: Custom rain and snowfall rendering styled to match the atmospheric aesthetic.
- **Volumetric God Rays**: Crepuscular sunbeams streaming through mountain passes and tree canopies.

---

## ⚙️ Configuration & In-Game Options

All settings can be tweaked directly in the **shader settings menu** in-game, or edited in `horizon-shaders.toml`:

| Setting | Type | Default | Description |
|---|---|---|---|
| **Anti-Aliasing (FXAA)** | Choice | `Sharp` | `Sharp` (edge-selective smoothing + HD clarity), `Smooth`, or `Off`. |
| **Roof & Overhang Occlusion** | Bool | `true` | Realistic directional shading and deep ambient occlusion under house roofs and eaves. |
| **Directional Shadows** | Bool | `true` | Real sun & moon shadow maps cast by terrain and blocks. |
| **Shadow Quality (FPS)** | Choice | `1024` | Shadow map resolution: `512` (fastest), `1024` (balanced), `1536`, `2048` (ultra). |
| **Shadow Distance** | Choice | `112` | Distance in blocks that shadow mapping covers. |
| **Planar Water Reflections** | Bool | `true` | Real-time planar mirror reflections of terrain and trees on water. |
| **Screen-Space Reflections (SSR)** | Bool | `true` | High-speed SSR reflecting visible terrain and shores at 200+ FPS. |
| **Water Waves & Glints** | Bool | `true` | Animated 3D waves, Fresnel reflections, and sunlight sparkles. |
| **Underwater Optics & Caustics** | Bool | `true` | Refractive wave wobble, dancing sunlight caustics, and turquoise absorption. |
| **Volumetric 3D Clouds** | Bool | `true` | Enable or disable custom raymarched 3D cumulus clouds. |
| **Cloud Performance Preset** | Choice | `Fast` | `Fast` (12-step max FPS), `Balanced` (16-step), or `Cinematic` (20-step). |
| **Cloud Density** | Float | `1.0` | Cloud thickness and sky coverage. |
| **Rain Puddles & Wetness** | Bool | `false` | Organic rain puddles on grass and dirt with raindrop ripples. |
| **Volumetric God Rays** | Bool | `true` | Sunbeams streaming through tree canopies. |
| **Wide Bloom** | Bool | `true` | Dual-tier atmospheric glow around torches, lanterns, and celestial bodies. |
| **Cinematic Lens Flares** | Bool | `true` | Anamorphic sun streaks and optical flares. |
| **Waving Foliage** | Bool | `true` | Wind swaying on leaves, grass, and plants. |
| **Torch Warmth** | Float | `1.0` | Warm golden-amber radiance of lanterns and torches. |


High quality and performance settings

<img width="1053" height="928" alt="image" src="https://github.com/user-attachments/assets/526c78a7-970f-439d-aee4-0a6f8f0537cb" />

---

# Шейдер-пак Lumina для Horizon (Minecraft 26.3) — v1.0.0 [RU]

Lumina — это нативный WGSL шейдер-пак, созданный специально для современного игрового движка **Horizon** (Rust/WGPU). Главные достоинства пака — **чистая, живая и реалистичная атмосфера** в сочетании с **высоким фреймрейтом (200-300+ FPS)** без перегруженности лишними пост-эффектами.

---

## ⚠️ Рекомендуемая настройка перед игрой
**Отключите стандартные облака игры в настройках графики:**  
Установите **Облака: ВЫКЛ** (*Clouds: OFF*), чтобы ванильные плоские облака не пересекались с кастомными объемными 3D-облаками Lumina.

---

## 🌟 Главные особенности

### ☀️ Дневное освещение и сочная атмосфера
- **Тёплый золотистый солнечный свет**: Натуральный тёплый свет солнца на открытых пространствах в гармонии со свежей сияющей лазурью неба в тенях.
- **Купольное полусферное затенение (Sky Occlusion)**: Верхние грани блоков видят всё небо (100%), вертикальные стены — половину (75%), а потолки и нижние стороны блоков обращены к земле и получают только мягкий отражённый свет (30-35%).
- **Глубокие тени под крышами и навесами**: Нелинейный физический спад рассеянного света под крыльцом, навесом или свесом крыши дома. Под навесами теперь царит настоящая глубокая, объёмная полутень.
- **Selective Vibrance**: Алгоритм селективной сочности, который делает зелень травы, листву деревьев и цветы насыщенными и живыми, предотвращая кислотное перенасыщение ярких блоков.
- **Просвечивание листвы (SSS) и солнечный контур**: Сквозное свечение листвы и лепестков сакуры на солнце, а также золотистый контурный ореол на траве и верхушках холмов.

### 🌓 Закат, сумерки и ночь
- **Кинематографичный закат**: Насыщенные янтарные солнечные лучи и розово-фиолетовый горизонт.
- **Глубокая полночь**: Серебристый лунный свет с мягкими тенями и тёмно-синей небесной полутенью.

### 🛡️ Направленные тени и контактное затенение
- **Динамические тени солнца и луны**: Настоящие теневые карты от блоков, деревьев и сущностей с защитой от искажений на любом расстоянии.
- **Контактное затенение (Vertex AO)**: Глубокие контрастные тени в стыках между крышей и стенами.

### 🔍 Сглаживание Clarity Anti-Aliasing (FXAA)
- **Устранение лесенок без размытия**: Сглаживает геометрические ступеньки на краях крыш, ступенях и заборах на фоне неба.
- **Защита текстур (Clarity Guard)**: Плоские поверхности, доски, кирпич, камень, листва и интерфейс не размываются, сохраняя фирменную чёткость Lumina.
- **Режимы**: *Sharp* (сглаженные края + чёткие текстуры), *Smooth* (мягкое сглаживание) и *Off* (исходные пиксели).

### 🌊 Физическая вода, отражения и подводный мир
- **Комбинированные отражения**: Быстрые Screen Space Reflections (SSR) для максимального FPS (200+) в сочетании с нативными плоскими зеркальными отражениями гор и деревьев.
- **Поглощение света (Закон Бера-Ламберта)**: Кристально прозрачное мелководье, плавно переходящее в сапфировую и бирюзовую глубину.
- **Окно Снелла**: При взгляде вверх из-под воды солнце, небо, облака и берег кристально видны сквозь колеблющиеся волны.
- **Подводная атмосфера**: Анимированные солнечные каустики на песчаном дне, мягкое волновое покачивание экрана и глубокое бирюзовое рассеивание.

### ☁️ Объемные 3D-облака
- Многооктавные кучевые облака с естественной формой, рассеиванием света и профилями производительности (**Fast**, **Balanced**, **Cinematic**).

### 🌧️ Лужи и кастомная погода
- **Процедурные лужи**: Формируются во время дождя на дёрне и земле с кругами от падающих капель и отражением неба.
- **Кастомные осадки**: Стилизованные капли дождя и снежинки.
- **Солнечные лучи (God Rays)**: Чистые объемные столбы света сквозь горы и деревья.

---

## ⚙️ Настройки в игре

Все параметры настраиваются прямо в **настройках шейдеров** в игре, либо через файл `horizon-shaders.toml`.

---

## Лицензия / License

Distributed under the **GNU General Public License v3.0 or later** (`GPL-3.0-or-later`).  
See [LICENSE](LICENSE) for full details.

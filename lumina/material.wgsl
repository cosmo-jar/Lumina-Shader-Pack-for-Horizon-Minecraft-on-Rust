// Lumina - Natural Surfaces, soft Lighting & Animated Water (WGSL)

override torch_warmth: f32 = 1.0;
override rain_puddles: bool = false;
override shadows: bool = true;
override reflections: bool = true;
override ssr_reflections: bool = true;
override roof_occlusion_opt: bool = true;

// The distance from the camera of what lies at screen point with depth
fn distance_at(screen: vec2<f32>, depth: f32) -> f32 {
    if depth <= 0.0 {
        return 1e4;
    }
    let clip = vec4<f32>(screen.x * 2.0 - 1.0, 1.0 - screen.y * 2.0, depth, 1.0);
    let view = frame.projection_inverse * clip;
    return length(view.xyz / view.w);
}

// Ground coverage of 1 shadow texel at point p accounting for nonlinear distortion
fn shadow_texel(p: vec3<f32>) -> f32 {
    let k = frame.shadow_distortion;
    let r = length((frame.shadow_view_proj * vec4<f32>(p, 1.0)).xy);
    let d = r * k + 1.0 - k;
    return frame.shadow_center_texel * d * d;
}

// Smooth directional sun/moon shadow with distortion-aware bias (stable grass shadows at any distance, zero acne)
fn sun_shadow(p: vec3<f32>, offset_dir: vec3<f32>, ndl: f32) -> f32 {
    if !shadows || frame.has_shadow == 0u {
        return 1.0;
    }
    let dist = length(p);
    if dist > frame.shadow_distance {
        return 1.0;
    }
    let ground = shadow_texel(p);
    let c = clamp(ndl, 0.05, 1.0);
    let slope = min(sqrt(1.0 - c * c) / c, 8.0);
    let s = shadow_position(p + offset_dir * ground * (1.2 + slope * 1.5));
    if s.x < 0.001 || s.x > 0.999 || s.y < 0.001 || s.y > 0.999 {
        return 1.0;
    }
    let texel = 1.0 / frame.shadow_resolution;
    let s0 = textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy + vec2<f32>(-texel * 0.5, -texel * 0.5), s.z);
    let s1 = textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy + vec2<f32>(texel * 0.5, texel * 0.5), s.z);
    let lit = (s0 + s1) * 0.5;
    // Ultra-smooth distance fade: shadows dissolve softly over a wide 40-block boundary (zero pop-in while flying)
    let fade_start = frame.shadow_distance * 0.62;
    let fade = smoothstep(fade_start, frame.shadow_distance, dist);
    return mix(lit, 1.0, fade);
}

// Geometric normal of water surface synchronized with vertex wave motion
fn water_normal(xz: vec2<f32>, t: f32) -> vec3<f32> {
    if !water_waves {
        return vec3<f32>(0.0, 1.0, 0.0);
    }
    let t_geom = t * 2.5;
    let swell_x = cos(xz.x * 0.90 + t_geom * 1.3) * sin(xz.y * 0.70 + t_geom * 1.1) * 0.90;
    let swell_z = sin(xz.x * 0.90 + t_geom * 1.3) * cos(xz.y * 0.70 + t_geom * 1.1) * 0.70;
    let chop = cos((xz.x + xz.y) * 1.70 - t_geom * 2.1) * 0.85;

    let slope = (vec2<f32>(swell_x + chop, swell_z + chop) / 3.0) * (WATER_AMPLITUDE * 2.6);
    let ripple = vec2<f32>(
        sin(xz.x * 4.2 + xz.y * 1.8 + t * 3.2),
        cos(xz.y * 3.8 - xz.x * 2.2 + t * 2.8)
    ) * 0.035;

    return normalize(vec3<f32>(slope.x - ripple.x, 1.0, slope.y - ripple.y));
}

// High-Speed Screen Space Reflection (SSR): traces terrain in screen space with 0 extra draw calls!
fn screen_space_reflection(p: vec3<f32>, n: vec3<f32>, screen_uv: vec2<f32>, water_dist: f32) -> vec4<f32> {
    let to_eye = -normalize(p);
    let r = reflect(-to_eye, n);
    if r.y <= 0.02 {
        return vec4<f32>(0.0);
    }

    let p_end = p + r * 42.0;
    let clip_start = frame.projection * vec4<f32>(p, 1.0);
    let clip_end = frame.projection * vec4<f32>(p_end, 1.0);
    if clip_start.w <= 0.01 || clip_end.w <= 0.01 {
        return vec4<f32>(0.0);
    }

    let ndc_start = clip_start.xy / clip_start.w;
    let ndc_end = clip_end.xy / clip_end.w;

    let uv_start = vec2<f32>(ndc_start.x * 0.5 + 0.5, 0.5 - ndc_start.y * 0.5);
    let uv_end = vec2<f32>(ndc_end.x * 0.5 + 0.5, 0.5 - ndc_end.y * 0.5);

    let delta = uv_end - uv_start;
    let len = length(delta);
    if len < 0.005 {
        return vec4<f32>(0.0);
    }

    let steps = 10;
    let step_uv = delta / f32(steps);
    var curr_uv = uv_start + step_uv * 0.7;

    for (var i = 0; i < 10; i++) {
        if curr_uv.x < 0.002 || curr_uv.x > 0.998 || curr_uv.y < 0.002 || curr_uv.y > 0.998 {
            break;
        }
        let texel = vec2<i32>(curr_uv * frame.resolution);
        let d = textureLoad(opaque_depth, texel, 0);

        if d > 0.0001 {
            let scene_dist = distance_at(curr_uv, d);
            let t_frac = (f32(i) + 0.7) / f32(steps);
            let ray_pos = mix(p, p_end, t_frac);
            let ray_dist = length(ray_pos);
            let diff = ray_dist - scene_dist;

            if diff >= -0.2 && diff < 3.2 {
                let hit_col = textureLoad(opaque_color, texel, 0).rgb;
                let edge = smoothstep(0.01, 0.08, min(min(curr_uv.x, 1.0 - curr_uv.x), min(curr_uv.y, 1.0 - curr_uv.y)));
                return vec4<f32>(hit_col, edge);
            }
        }
        curr_uv += step_uv;
    }
    return vec4<f32>(0.0);
}

// Ultra-fast dedicated water pipeline (early return: 0 terrain overhead, 0 redundant shadow passes!)
fn render_water(input: MaterialInput) -> vec4<f32> {
    let world = input.position + frame.camera_position;
    let to_eye = normalize(-input.position);
    let top = input.face == 1u;
    var n = input.normal;
    if top {
        n = water_normal(world.xz, frame.time);
        n = select(n, -n, input.normal.y < 0.0);
    }

    let water_dist = length(input.position);

    // Physical refraction: wave ripples distort seabed, safe against foreground objects
    var bent = clamp(input.screen + n.xz * 0.028, vec2<f32>(0.001), vec2<f32>(0.999));
    var texel = vec2<i32>(bent * frame.resolution);
    var behind_depth = textureLoad(opaque_depth, texel, 0);
    var behind_distance = distance_at(bent, behind_depth);
    if behind_distance < water_dist {
        bent = input.screen;
        texel = vec2<i32>(bent * frame.resolution);
        behind_distance = distance_at(bent, textureLoad(opaque_depth, texel, 0));
    }
    let behind = textureLoad(opaque_color, texel, 0).rgb;
    let thickness = max(behind_distance - water_dist, 0.0);

    let day = daylight();
    let tw = twilight();
    let rain = frame.rain;

    // Fast 1-tap shadow lookup on water surface (skips calculation if beyond shadow distance)
    var water_sun_vis = 1.0;
    if shadows && frame.has_shadow == 1u && frame.dimension == 0 && water_dist < frame.shadow_distance {
        let s = shadow_position(input.position + vec3<f32>(0.0, 0.08, 0.0));
        if s.x >= 0.001 && s.x <= 0.999 && s.y >= 0.001 && s.y <= 0.999 {
            water_sun_vis = textureSampleCompareLevel(shadow_map, shadow_sampler, s.xy, s.z);
            water_sun_vis = mix(water_sun_vis, 1.0, smoothstep(0.85, 1.0, water_dist / frame.shadow_distance));
        }
    }

    // Direct sun and ambient light
    let is_sun = dot(frame.light_direction, frame.sun_direction) > 0.0;
    let sun_color = select(vec3<f32>(0.30, 0.36, 0.50), mix(vec3<f32>(1.38, 0.82, 0.40), vec3<f32>(1.06, 0.98, 0.88), day), is_sun);
    let direct_sun = sun_color * (water_sun_vis * 0.70 * (1.0 - rain * 0.75));
    let ambient = input.lightmap * 0.85 + input.colored_light;

    // Clean crystal watercolor (no grainy vanilla texture noise!)
    let water_base = mix(vec3<f32>(0.05, 0.35, 0.62), input.tint.rgb, 0.72);
    let body = water_base * (ambient + direct_sun * 0.4);
    let reach = 9.0;
    let absorb = exp(-thickness / reach * vec3<f32>(2.0, 0.85, 0.50));
    var color = mix(body, behind, absorb);

    // Underwater, the surface overhead creates Snell's Window with gentle waves & total internal reflection
    if frame.eye_in == 1u {
        let cos_up = clamp(abs(dot(n, to_eye)), 0.0, 1.0);
        // Distance through water from camera to surface overhead
        let surface_absorb = exp(-water_dist / 14.0 * vec3<f32>(0.20, 0.06, 0.02));
        var surface_view = mix(body, behind, surface_absorb);

        // Total Internal Reflection (critical angle ~48.6°, cos ≈ 0.66): glancing angles reflect deep water
        let tir = smoothstep(0.70, 0.45, cos_up);
        let deep_water_scatter = vec3<f32>(0.025, 0.22, 0.38) * (day * 0.75 + 0.25);
        surface_view = mix(surface_view, deep_water_scatter, tir * 0.85);

        // Sunlight sparkle on surface ripples viewed from below
        if rain < 0.85 {
            let h = normalize(frame.light_direction + to_eye);
            let glint = pow(max(dot(-n, h), 0.0), 320.0) * 3.5;
            surface_view += direct_sun * glint;
        }

        return vec4<f32>(shoulder(surface_view), 1.0);
    }

    // Reflection by Schlick's Fresnel (water F0 = 0.02)
    let cos_v = clamp(dot(n, to_eye), 0.0, 1.0);
    let fresnel = 0.025 + 0.975 * pow(1.0 - cos_v, 4.5);

    // Dynamic Sky Reflection across the waves: each wave crest catches more sky light!
    let zenith_sky = vec3<f32>(0.42, 0.68, 0.98);
    let horizon_sky = frame.fog_color;
    let wave_sky = mix(horizon_sky, zenith_sky, clamp(n.y * 0.8 + 0.2, 0.0, 1.0)) * day;
    let night_refl = vec3<f32>(0.02, 0.04, 0.08);
    var mirrored = mix(night_refl, wave_sky, day);
    mirrored = mix(mirrored, vec3<f32>(0.96, 0.60, 0.35), tw * (1.0 - rain));

    var has_planar = false;
    // 1. Real Planar Mirror Reflection: waves physically undulate and ripple the reflected world!
    if reflections && top && frame.has_reflection == 1u && input.light.y > 0.08 && fresnel > 0.035 {
        let refl_uv = clamp(input.screen + n.xz * 0.032, vec2<f32>(0.002), vec2<f32>(0.998));
        mirrored = textureSampleLevel(reflection, reflection_sampler, refl_uv, 0.0).rgb;
        has_planar = true;
    }

    // 2. High-speed Screen Space Reflection (SSR): reflects mountains/trees on water at 200+ FPS!
    if !has_planar && ssr_reflections && top && input.light.y > 0.12 && fresnel > 0.035 {
        let ssr = screen_space_reflection(input.position, n, input.screen, water_dist);
        if ssr.a > 0.01 {
            mirrored = mix(mirrored, ssr.rgb, ssr.a);
        }
    }

    color = mix(color, mirrored, fresnel * smoothstep(0.15, 0.85, input.light.y));

    // Sharp pinpoint sunlight glint (pure sparkles on wave crests, zero shadow acne)
    if rain < 0.85 {
        let h = normalize(frame.light_direction + to_eye);
        let glint = pow(max(dot(n, h), 0.0), 380.0) * 4.5;
        color += direct_sun * glint;
    }

    return vec4<f32>(shoulder(color), 1.0);
}

fn material(input: MaterialInput) -> Surface {
    // 1. Water & Lava Early Return: instantly saves hundreds of instructions on every fluid fragment!
    if input.fluid == 1u {
        return Surface(render_water(input));
    }
    if input.fluid == 2u {
        return Surface(vec4<f32>(input.albedo.rgb * input.tint.rgb * 1.15, input.albedo.a));
    }
    let albedo = input.albedo;
    let tint = input.tint;

    // Environmental factors from frame.day_time
    let day = daylight();
    let tw = twilight();
    let night = night_factor();
    let rain = frame.rain;

    // Light levels:
    // input.light.x = Block / torch light (0..1)
    // input.light.y = Sky light access (0..1)
    let block_level = input.light.x;
    let sky_level = input.light.y;

    // --- 1. Base Lighting from Engine Lightmap & Mesher ---
    var light_col = input.lightmap;

    // Nether and The End fallback
    if frame.dimension != 0 {
        let block_falloff = pow(block_level, 1.75);
        let torch_color = vec3<f32>(1.0, 0.76, 0.42);
        let torch_light = torch_color * (block_falloff * 1.35 * torch_warmth);
        let final_color = albedo.rgb * tint.rgb * max(light_col * 1.1 + torch_light, vec3<f32>(0.04));
        return Surface(vec4<f32>(final_color, albedo.a));
    }

    // --- 2. Balanced soft Direct Sunlight & Skylight Ambient ---
    var direct_access = pow(sky_level, 3.2);

    // Palette:
    // Daytime: rich radiant golden sunlight & crisp azure-blue ambient shade
    let day_sun = vec3<f32>(1.35, 1.15, 0.78);
    let day_shade = vec3<f32>(0.50, 0.68, 0.92);

    // Sunset / Golden Hour (warm amber sunlight, soft rose-violet twilight shade)
    let dusk_sun = vec3<f32>(1.38, 0.82, 0.40);
    let dusk_shade = vec3<f32>(0.72, 0.54, 0.65);

    // Night (silver-blue moonlight & cool midnight navy ambient)
    let night_moon = vec3<f32>(0.30, 0.36, 0.50);
    let night_shade = vec3<f32>(0.16, 0.20, 0.30);

    // Rain (soft diffuse daylight & storm gray)
    let rain_sun = vec3<f32>(0.56, 0.60, 0.68);
    let rain_shade = vec3<f32>(0.46, 0.50, 0.56);

    var sun_filter = mix(night_moon, day_sun, day);
    sun_filter = mix(sun_filter, dusk_sun, tw * (1.0 - rain));
    sun_filter = mix(sun_filter, rain_sun, rain);

    var shade_filter = mix(night_shade, day_shade, day);
    shade_filter = mix(shade_filter, dusk_shade, tw * (1.0 - rain));
    shade_filter = mix(shade_filter, rain_shade, rain);

    // --- Real Directional Sun & Moon Shadows from Engine Shadow Map ---
    let is_foliage = (input.tags & 1u) != 0u;

    if shadows && frame.has_shadow == 1u && frame.dimension == 0 && sky_level > 0.05 {
        let n_dot_l = dot(input.normal, frame.light_direction);

        if n_dot_l > 0.0 || is_foliage {
            let offset_dir = select(input.normal, frame.light_direction, is_foliage);
            let ndl = select(n_dot_l, 1.0, is_foliage);
            // Soft terminator easing: avoids harsh grazing acne on building walls at sunset
            let terminator = select(smoothstep(0.0, 0.12, n_dot_l), 1.0, is_foliage);
            let shadow_vis = sun_shadow(input.position, offset_dir, ndl) * terminator;
            direct_access = shadow_vis * pow(sky_level, 1.2);
        } else {
            direct_access = 0.0;
        }
    }

    // --- Directional Ambient Sky Occlusion (Hemispherical Dome Lighting) ---
    // Top surfaces facing open zenith (y > 0) receive full sky dome illumination (1.0).
    // Vertical walls (y == 0) see half the sky hemisphere (0.76).
    // Downward ceilings & roof undersides (y < 0) face the ground, receiving soft ground bounce (0.32..0.45).
    var directional_shade = 1.0;
    var roof_ambient = sky_level;
    if roof_occlusion_opt {
        let ny = input.normal.y;
        var sky_dome_factor = 0.76 + select(0.24 * ny, 0.44 * ny, ny < 0.0);
        if is_foliage {
            sky_dome_factor = mix(sky_dome_factor, 0.88, 0.50);
        }
        let wall_contrast = 1.0 - 0.06 * input.normal.x * input.normal.x;
        directional_shade = sky_dome_factor * wall_contrast;

        // Under house roofs, porches, eaves and tree canopies:
        // Skylight rolls off along a smooth physical S-curve into deep, realistic occlusion!
        let sky_s_curve = smoothstep(0.03, 0.98, sky_level);
        roof_ambient = pow(sky_s_curve, 1.30);
    }

    let ambient_level = (0.04 + 0.96 * roof_ambient) * directional_shade;
    let ambient_fill = shade_filter * ambient_level;
    let direct_sun = sun_filter * (direct_access * 0.72 * (1.0 - rain * 0.75));

    // Normalized tone: radiant sunny daytime (~1.12), rich dramatic twilight & midnight
    let day_boost = mix(0.92, 1.12, day);
    let celestial_tone = (ambient_fill + direct_sun) * day_boost;
    light_col = light_col * celestial_tone;

    // Deep ambient floor: maintains clean readability in deep caves while letting roof shadows be rich
    let min_ambient = mix(vec3<f32>(0.025), vec3<f32>(0.035, 0.040, 0.055), day);
    light_col = max(light_col, min_ambient);

    // --- 3. Rich Golden Torch, Colored & Emissive Light ---
    let block_falloff = pow(block_level, 1.75);
    let torch_color = vec3<f32>(1.0, 0.74, 0.38);
    let torch_boost = torch_color * (block_falloff * 1.35 * torch_warmth);
    light_col += torch_boost;

    // Dynamic colored lights (soul lanterns, redstone torches, held glow items)
    let colored_boost = input.colored_light * 1.5;
    light_col += colored_boost;

    // Emissive blocks (lanterns, glowstone, torches, froglights, magma)
    if input.emission > 0.01 {
        let emissive_light = mix(vec3<f32>(1.0, 0.78, 0.45), vec3<f32>(1.10, 1.05, 1.0), input.emission) * (input.emission * 1.6);
        light_col = max(light_col, emissive_light);
    }

    // --- 4. Foliage Subsurface Scattering (Backlight glow against the sun) ---
    // Smooth camera-relative view ray: 100% continuous, zero derivatives, zero diagonal seams!
    let view_dir = normalize(input.position);

    if is_foliage && (day > 0.02 || tw > 0.02) && sky_level > 0.25 {
        let sun_align = max(dot(-view_dir, frame.sun_direction), 0.0);
        let sss_amount = pow(sun_align, 3.2) * sky_level * 0.35 * (day * 0.75 + tw * 1.35) * (1.0 - rain);
        let is_cherry = (albedo.r > 0.65 && albedo.b > 0.55);
        let sss_foliage_base = select(vec3<f32>(0.55, 0.98, 0.35), vec3<f32>(1.0, 0.76, 0.68), is_cherry);
        let sss_color = mix(sss_foliage_base, vec3<f32>(1.0, 0.68, 0.28), tw);
        light_col += sss_color * sss_amount;
    }

    // --- 5. Golden Solar Rim & Foliage Forward Scattering ---
    // Restricted strictly to foliage: leaves and grass tops catch a soft golden rim; buildings stay rock-solid!
    if is_foliage && (day > 0.02 || tw > 0.02) && sky_level > 0.45 {
        let sun_align = max(dot(-view_dir, frame.sun_direction), 0.0);
        let rim_face = max(dot(input.normal, -view_dir), 0.0);
        let rim_glow = pow(sun_align, 4.0) * pow(sky_level, 2.0) * rim_face * (day * 0.18 + tw * 0.50) * (1.0 - rain);
        let rim_col = mix(vec3<f32>(1.0, 0.62, 0.22), vec3<f32>(1.0, 0.96, 0.86), day);
        light_col += rim_col * rim_glow;
    }

    // Status effects support (Night Vision potion, Darkness, Blindness)
    if frame.night_vision > 0.0 {
        light_col = mix(light_col, max(light_col, vec3<f32>(0.82)), frame.night_vision);
    }
    if frame.darkness > 0.0 {
        light_col *= (1.0 - frame.darkness * 0.88);
    }
    if frame.blindness > 0.0 {
        light_col *= (1.0 - frame.blindness * 0.94);
    }

    // --- 5. Clean Crystalline Water with Animated Wave Ripples ---
    // Deepen natural ambient occlusion and 3D facet shading during daytime and noon
    let ao_power = mix(1.10, 1.55, day);
    let ao_enhanced = pow(tint.rgb, vec3<f32>(ao_power));
    var base_color = albedo * vec4<f32>(ao_enhanced, tint.a);
    var specular = vec3<f32>(0.0);

    // --- 6. Rain Wetness (Physical dampening of porous surfaces exposed to rain) ---
    if rain_puddles && frame.wetness > 0.01 && frame.dimension == 0 {
        // Continuous curve: only surfaces exposed to open sky get damp (caves/underground stay dry!)
        let sky_open = smoothstep(0.80, 0.98, sky_level);
        let wetness = frame.wetness * sky_open;
        let wet_darken = 1.0 - 0.12 * wetness;
        base_color = vec4<f32>(base_color.rgb * wet_darken, base_color.a);
    }

    var lit_color = base_color.rgb * light_col;

    // --- 7. Natural Procedural Puddles (Grass Blocks & Dirt Only) ---
    if rain_puddles && !input.translucent && frame.wetness > 0.05 && frame.dimension == 0 && frame.precipitation == 1u {
        // Exact geometric upward normal verification (zero screen derivatives, zero seam artifacts!)
        let is_upward = input.normal.y > 0.90;
        let is_solid = albedo.a > 0.99;
        let is_top_surface = is_upward && is_solid;

        // --- Block Identification ---
        // 1. Grass Block (Top of Grass Block / дёрн):
        // In Minecraft assets, grass_block_top.png is greyscale. Biome tint makes it green.
        let is_grass_albedo = abs(albedo.r - albedo.g) < 0.08 && abs(albedo.g - albedo.b) < 0.08;
        let is_grass_tint = (tint.g > tint.r * 1.01) && (tint.g > tint.b * 1.03);
        let is_grass_block = is_top_surface && is_grass_albedo && is_grass_tint;

        // 2. Dirt Blocks (Dirt, Coarse Dirt, Rooted Dirt, Mud, Podzol / земля):
        // Dirt in Minecraft is untinted (tint.r ≈ tint.g ≈ tint.b) and has a warm earthy brown hue (R > G > B).
        let is_untinted = abs(tint.r - tint.g) < 0.06 && abs(tint.g - tint.b) < 0.06;
        let is_dirt_color = (albedo.r > albedo.g * 1.03) && (albedo.g > albedo.b * 1.04) && (albedo.r > albedo.b * 1.15) && (albedo.r >= 0.18 && albedo.r <= 0.72) && (albedo.b <= 0.40);
        let is_dirt_block = is_top_surface && is_untinted && is_dirt_color;

        let is_puddle_surface = is_grass_block || is_dirt_block;

        if is_puddle_surface {
            // Smooth continuous sky exposure (blocks under tree canopies or caves softly roll off to 0)
            let sky_exposure = smoothstep(0.72, 0.98, sky_level);

            // True 3D world coordinates
            let world_xz = input.position.xz + frame.camera_position.xz;
            let world_y = input.position.y + frame.camera_position.y;
            let block_y = floor(world_y + 0.1);

            // UNIQUE PER Y-LEVEL:
            // Hash each discrete integer block height so each terrace/elevation has its own independent puddles.
            // Puddles on the surface NEVER slice through into underground layers or repeat down terraced slopes!
            let y_hash = hash2(vec2<f32>(block_y * 19.17, block_y * 31.73));
            let puddle_coords = world_xz + y_hash * 37.0;

            // Multi-scale procedural noise for broad organic puddle pools
            var p_noise = value_noise(puddle_coords * 0.12) * 0.56;
            p_noise += value_noise(puddle_coords * 0.28) * 0.30;
            p_noise += value_noise(puddle_coords * 0.65) * 0.14;

            // Natural organic puddles with wide, soft feathered shores (рассеянные края)
            let puddle_thresh = mix(0.58, 0.40, rain);
            let puddle_mask = smoothstep(puddle_thresh, puddle_thresh + 0.36, p_noise) * sky_exposure;

            if puddle_mask > 0.001 {
                // Layer 1: Physical dampening of wet earth/grass under puddle
                let wet_ground_darken = mix(1.0, 0.86, puddle_mask);
                lit_color *= wet_ground_darken;

                // Layer 2: Puddle water surface with REAL circular raindrop impact waves
                let drops = puddle_raindrop_ripples(world_xz, frame.time);
                let rip_t = frame.time * 4.5;
                let rip_x = sin(world_xz.x * 5.5 + rip_t) * cos(world_xz.y * 5.0 - rip_t * 0.85);
                let rip_z = cos(world_xz.x * 5.0 - rip_t * 0.9) * sin(world_xz.y * 5.5 + rip_t);
                let puddle_normal = normalize(vec3<f32>(
                    (rip_x * 0.015 + drops.x * 0.055) * rain,
                    1.0,
                    (rip_z * 0.015 + drops.y * 0.055) * rain
                ));

                // Layer 3: Dynamic Time-of-Day Matched Sky Reflection
                let day_sky_refl = mix(vec3<f32>(0.46, 0.50, 0.56), vec3<f32>(0.22, 0.25, 0.30), frame.thunder);
                let dusk_sky_refl = vec3<f32>(0.32, 0.24, 0.28);
                let night_sky_refl = vec3<f32>(0.035, 0.045, 0.070);

                var sky_refl_color = mix(night_sky_refl, day_sky_refl, day);
                sky_refl_color = mix(sky_refl_color, dusk_sky_refl, tw * (1.0 - rain * 0.5));

                // Modulate reflection by local surface ambient lighting so puddles in shadow softly dim
                // and naturally dissolve into shadows without any harsh bright contrast steps!
                let local_light = max(luminance(light_col), 0.05);
                let ambient_factor = clamp(local_light * 1.4, 0.20, 1.0);
                let torch_refl = torch_color * (pow(block_level, 2.0) * 0.55);
                let puddle_refl = sky_refl_color * ambient_factor + torch_refl;

                // Layer 4: Glassy Fresnel reflection (gentle 0.15..0.45, preserving natural grass underneath)
                let cos_view = max(dot(-view_dir, puddle_normal), 0.0);
                let fresnel = mix(0.15, 0.45, pow(1.0 - cos_view, 2.5));

                let refl_factor = fresnel * puddle_mask;
                lit_color = mix(lit_color, puddle_refl, refl_factor);

                // Light specular glint during daytime/sunset rain if sunlight breaks through
                if rain < 0.90 && (day > 0.05 || tw > 0.05) {
                    let half_vec = normalize(-view_dir + frame.sun_direction);
                    let ndoth = max(dot(puddle_normal, half_vec), 0.0);
                    let puddle_glint = pow(ndoth, 55.0) * 1.8 * puddle_mask * sky_level * (day + tw) * (1.0 - rain * 0.60);
                    specular += vec3<f32>(puddle_glint);
                }
            }
        }
    }

    let final_surface = lit_color + specular;
    return Surface(vec4<f32>(final_surface, base_color.a));
}

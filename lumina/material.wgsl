// Lumina - Natural Surfaces, soft Lighting & Animated Water (WGSL)

override torch_warmth: f32 = 1.0;
override water_waves: bool = true;
override rain_puddles: bool = false;

fn material(input: MaterialInput) -> Surface {
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
    // Direct sky access: open terrain receives full warm direct sunlight;
    // under tree canopies and overhangs, direct sunlight drops off, leaving soft ambient shade!
    let direct_access = pow(sky_level, 3.2);

    // Palette:
    // Daytime: warm balanced sunlight, not blinding or nuclear
    let day_sun = vec3<f32>(1.06, 0.98, 0.88);
    let day_shade = vec3<f32>(0.66, 0.76, 0.94);

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

    // Balanced lighting curve:
    // Direct sunlight shines on open terrain; ambient skylight illuminates shadows
    let ambient_fill = shade_filter * (0.38 + 0.62 * sky_level);
    let direct_sun = sun_filter * (direct_access * 0.70 * (1.0 - rain * 0.75));

    // Normalized tone: open sunlight ~ 1.05, shaded areas ~ 0.55 (2:1 ratio, rich & atmospheric)
    let celestial_tone = (ambient_fill + direct_sun) * 0.76;
    light_col = light_col * celestial_tone;

    // Ambient light floor: keeps deep undergrowth and tree trunks readable and rich
    let min_ambient = mix(vec3<f32>(0.04), vec3<f32>(0.07, 0.08, 0.11), day);
    light_col = max(light_col, min_ambient);

    // --- 3. Rich Golden Torch / Lantern Light ---
    let block_falloff = pow(block_level, 1.75);
    let torch_color = vec3<f32>(1.0, 0.74, 0.38);
    let torch_boost = torch_color * (block_falloff * 1.35 * torch_warmth);
    light_col += torch_boost;

    // --- 4. Foliage Subsurface Scattering (Backlight glow against the sun) ---
    // Smooth camera-relative view ray: 100% continuous, zero derivatives, zero diagonal seams!
    let view_dir = normalize(input.position);
    let is_foliage = (tint.g > tint.r * 1.05 && tint.g > 0.22) || (albedo.a < 0.99 && !input.translucent);

    if is_foliage && (day > 0.02 || tw > 0.02) && sky_level > 0.25 {
        let sun_align = max(dot(-view_dir, frame.sun_direction), 0.0);
        let sss_amount = pow(sun_align, 3.2) * sky_level * 0.28 * (day * 0.75 + tw * 1.35) * (1.0 - rain);
        // Cherry blossoms (pink/white) vs standard foliage (green)
        let is_cherry = (albedo.r > 0.65 && albedo.b > 0.55);
        let sss_foliage_base = select(vec3<f32>(0.60, 0.98, 0.38), vec3<f32>(1.0, 0.76, 0.68), is_cherry);
        let sss_color = mix(sss_foliage_base, vec3<f32>(1.0, 0.68, 0.28), tw);
        light_col += sss_color * sss_amount;
    }

    // --- 5. Golden Solar Rim & Terrain Forward Scattering ---
    // When looking towards the sun, grass tops and contours catch a soft golden atmospheric rim!
    if (day > 0.02 || tw > 0.02) && sky_level > 0.45 {
        let sun_align = max(dot(-view_dir, frame.sun_direction), 0.0);
        let rim_glow = pow(sun_align, 4.0) * pow(sky_level, 2.0) * (day * 0.18 + tw * 0.50) * (1.0 - rain);
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
    let ao_power = mix(1.08, 1.45, day);
    let ao_enhanced = pow(tint.rgb, vec3<f32>(ao_power));
    var base_color = albedo * vec4<f32>(ao_enhanced, tint.a);
    var specular = vec3<f32>(0.0);

    // --- 6. Rain Wetness (Physical dampening of porous surfaces exposed to rain) ---
    if rain_puddles && rain > 0.01 && frame.dimension == 0 {
        // Continuous curve: only surfaces exposed to open sky get damp (caves/underground stay dry!)
        let sky_open = smoothstep(0.80, 0.98, sky_level);
        let wetness = rain * sky_open;
        let wet_darken = 1.0 - 0.10 * wetness;
        base_color = vec4<f32>(base_color.rgb * wet_darken, base_color.a);
    }

    if input.translucent {
        let world_xz = input.position.xz + frame.camera_position.xz;
        let t = frame.time * 1.6;

        // Multi-frequency wave normal perturbation
        let w1_x = sin(world_xz.x * 1.2 + t * 2.2);
        let w1_z = cos(world_xz.y * 1.4 + t * 2.0);
        let w2_x = cos((world_xz.x + world_xz.y) * 2.1 - t * 3.1);
        let w2_z = sin((world_xz.x - world_xz.y) * 2.3 + t * 2.8);
        let w3_x = sin(world_xz.x * 4.5 + t * 4.2) * 0.5;
        let w3_z = cos(world_xz.y * 4.7 - t * 3.8) * 0.5;

        let wave_slope_x = (w1_x * 0.6 + w2_x * 0.4 + w3_x) * 0.18;
        let wave_slope_z = (w1_z * 0.6 + w2_z * 0.4 + w3_z) * 0.18;

        var wave_normal = vec3<f32>(0.0, 1.0, 0.0);
        if water_waves {
            wave_normal = normalize(vec3<f32>(wave_slope_x, 1.0, wave_slope_z));
        }

        // Raindrop micro-ripples across water surface during rainfall
        if rain > 0.05 {
            let rain_t = frame.time * 4.5;
            let rip = sin(world_xz.x * 7.0 + rain_t) * cos(world_xz.y * 7.0 - rain_t * 0.9);
            wave_normal = normalize(wave_normal + vec3<f32>(rip * 0.05 * rain, 0.0, rip * 0.05 * rain));
        }

        // Animated surface caustics pattern
        let caustic = (sin(world_xz.x * 1.8 + t * 2.0) * cos(world_xz.y * 1.8 - t * 1.7) * 0.5 + 0.5);
        let caustic_glow = pow(caustic, 3.0) * 0.16 * sky_level * (day * 0.85 + 0.1) * (1.0 - rain * 0.7);

        // Fresnel reflection of the sky (azure in clear day, dark navy at night, slate-gray in rain)
        let cos_v = max(dot(-view_dir, wave_normal), 0.0);
        let fresnel = 0.03 + 0.97 * pow(1.0 - cos_v, 4.0);
        let clear_sky_refl = mix(vec3<f32>(0.03, 0.05, 0.10), vec3<f32>(0.60, 0.78, 0.98), day);
        let dusk_sky_refl = vec3<f32>(0.92, 0.58, 0.38);
        let storm_sky_refl = mix(vec3<f32>(0.35, 0.40, 0.46), vec3<f32>(0.15, 0.18, 0.22), frame.thunder);
        var sky_reflect_color = mix(clear_sky_refl, dusk_sky_refl, tw * (1.0 - rain));
        sky_reflect_color = mix(sky_reflect_color, storm_sky_refl, rain);
        let sky_reflect = sky_reflect_color * fresnel * pow(sky_level, 1.0);

        // Water tint and transparency
        let water_tone = vec3<f32>(0.08, 0.38, 0.60);
        base_color = vec4<f32>(mix(base_color.rgb, water_tone, 0.30) + sky_reflect * 0.70 + vec3<f32>(caustic_glow), 0.58);

        // Specular glint: Sun during day, Moon at night
        if rain < 0.9 {
            let is_sun = (day > 0.05 || tw > 0.05);
            let active_light_dir = select(frame.moon_direction, frame.sun_direction, is_sun);
            let half_vec = normalize(-view_dir + active_light_dir);
            let ndoth = max(dot(wave_normal, half_vec), 0.0);

            let sun_spec = pow(ndoth, 85.0) * 2.5 * sky_level * (day + tw * 1.4) * (1.0 - rain);
            let moon_spec = pow(ndoth, 60.0) * 0.50 * sky_level * night * (1.0 - rain);

            let spec_sun_color = mix(vec3<f32>(1.0, 0.98, 0.95), vec3<f32>(1.0, 0.75, 0.38), tw);
            let spec_color = select(vec3<f32>(0.65, 0.78, 1.0) * moon_spec, spec_sun_color * sun_spec, is_sun);
            specular = spec_color;
        }
    }

    var lit_color = base_color.rgb * light_col;

    // --- 7. Natural Procedural Puddles (Grass Blocks & Dirt Only) ---
    if rain_puddles && !input.translucent && rain > 0.05 && frame.dimension == 0 {
        // True geometric horizontal surface check:
        // For any flat horizontal block top, pos.y does not change across screen pixels (dpos_y ≈ 0.0).
        // For vertical walls and upright plant quads, pos.y varies significantly across screen pixels (dpos_y > 0.04).
        let dpos_y = abs(dpdx(input.position.y)) + abs(dpdy(input.position.y));
        let is_flat_y = dpos_y < 0.012;

        // Geometric normal verification: must face upwards
        let cross_n = cross(dpdx(input.position), dpdy(input.position));
        let n_len = length(cross_n);
        let is_upward = (n_len > 1e-7) && ((abs(cross_n.y) / n_len) > 0.75);

        // Solid opaque check: exclude any transparent cutout fragments
        let is_solid = albedo.a > 0.99;

        let is_top_surface = is_flat_y && is_upward && is_solid;

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

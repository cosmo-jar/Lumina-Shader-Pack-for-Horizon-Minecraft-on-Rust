// Lumina - Atmospheric Fog & Volumetric God Rays (WGSL)

override fog_density: f32 = 1.0;
override god_rays: bool = true;
override god_rays_intensity: f32 = 1.0;
override underwater_optics: bool = true;

fn post(input: PostInput) -> vec4<f32> {
    // --- Underwater Optics & Caustics ---
    if underwater_optics && frame.eye_in == 1u {
        let aspect = frame.resolution.x / frame.resolution.y;
        let w_time = frame.time * 2.2;
        let wave_uv = input.uv * vec2<f32>(14.0 * aspect, 14.0);
        let refract_offset = vec2<f32>(
            sin(wave_uv.x * 1.3 + wave_uv.y * 1.1 + w_time),
            cos(wave_uv.x * 1.1 - wave_uv.y * 1.4 + w_time * 0.9)
        ) * 0.0035;

        let refr_uv = clamp(input.uv + refract_offset, vec2<f32>(0.001), vec2<f32>(0.999));
        let base_col = textureSampleLevel(previous, linear_sampler, refr_uv, 0.0).rgb;

        let is_terrain = input.depth > 0.00002;
        let vpos = select(vec3<f32>(0.0, 0.0, 36.0), view_position(input.uv, input.depth), is_terrain);
        let dist = select(36.0, length(vpos), is_terrain);

        // Water absorption: Red wavelengths vanish first, giving deep vibrant turquoise tone
        let water_extinction = exp(-vec3<f32>(0.15, 0.045, 0.018) * dist);

        let day = daylight();
        let tw = twilight();
        let day_water = vec3<f32>(0.025, 0.22, 0.38);
        let tw_water = vec3<f32>(0.040, 0.16, 0.32);
        let night_water = vec3<f32>(0.006, 0.045, 0.08);
        var water_scatter_color = mix(night_water, day_water, day);
        water_scatter_color = mix(water_scatter_color, tw_water, tw * (1.0 - frame.rain));
        water_scatter_color = mix(water_scatter_color, vec3<f32>(0.02, 0.14, 0.22), frame.rain * 0.6);

        let water_scatter = 1.0 - exp(-dist * 0.065);

        var col = base_col * water_extinction + water_scatter_color * water_scatter;

        // Animated sunlight caustics dancing on underwater blocks
        if is_terrain {
            let world_pos = vpos + frame.camera_position;
            let caustic_p = world_pos.xz * 0.45;
            let c1 = sin(caustic_p.x * 2.2 + w_time) + cos(caustic_p.y * 2.0 + w_time * 1.1);
            let c2 = sin(caustic_p.x * 1.8 - w_time * 1.2) + cos(caustic_p.y * 2.4 - w_time * 0.8);
            let caustic = pow(clamp((c1 + c2) * 0.32 + 0.5, 0.0, 1.0), 3.0);
            let caustic_fade = exp(-dist * 0.05) * day * (1.0 - frame.rain * 0.8);
            col += vec3<f32>(0.15, 0.45, 0.55) * (caustic * caustic_fade * 0.35);
        }

        return vec4<f32>(col, input.color.a);
    }

    // Camera submerged in lava
    if frame.eye_in == 2u {
        let is_terrain = input.depth > 0.00002;
        let vpos = select(vec3<f32>(0.0, 0.0, 6.0), view_position(input.uv, input.depth), is_terrain);
        let dist = select(6.0, length(vpos), is_terrain);
        let lava_fog = vec3<f32>(1.0, 0.28, 0.03);
        let fog_factor = 1.0 - exp(-dist * 0.65);
        return vec4<f32>(mix(input.color.rgb, lava_fog, fog_factor), input.color.a);
    }

    // Sky pixels: keep sky stage unmodified
    if input.depth <= 0.00002 {
        return input.color;
    }

    // Reconstruct camera-relative view position
    let vpos = view_position(input.uv, input.depth);
    let dist = length(vpos);
    let ray_dir = normalize(vpos);

    // Environmental factors from common.wgsl
    let day = daylight();
    let tw = twilight();
    let night = night_factor();
    let rain = frame.rain;

    var scene_color = input.color.rgb;

    // --- 1. Clean Distance Fog (clear near/mid, smooth horizon fade) ---
    // Render distance is in blocks (e.g. 256).
    // Air is crystal clear up to 70% of render distance; fog only smoothly dissolves chunk edges into the horizon sky!
    let rd = max(frame.render_distance, 64.0);
    let norm_dist = clamp(dist / rd, 0.0, 1.0);
    let chunk_edge_fog = pow(norm_dist, 5.0) * 0.95 * fog_density;

    // Subtle atmospheric aerial perspective for distant mountains (> 120 blocks)
    let distant_haze = smoothstep(96.0, rd * 0.9, dist) * 0.12 * fog_density * (day * 0.8 + 0.2);

    // Rain mist: rolling atmospheric rain sheets
    let rain_mist = (1.0 - exp(-dist * 0.018 * fog_density)) * rain * (0.75 + frame.thunder * 0.20);

    var fog_amount = clamp(chunk_edge_fog + distant_haze + rain_mist, 0.0, 1.0);

    // --- 2. Dynamic Atmospheric Color Palette ---
    // Pure azure for clear day, magical rose/amber for sunset, cosmic dark navy for night, slate/storm for rain
    let day_fog = vec3<f32>(0.60, 0.76, 0.96);
    let tw_fog = mix(vec3<f32>(0.76, 0.30, 0.46), vec3<f32>(1.0, 0.52, 0.18), max(dot(ray_dir, frame.sun_direction), 0.0));
    let night_fog = vec3<f32>(0.015, 0.024, 0.048);
    let rain_fog = mix(vec3<f32>(0.42, 0.46, 0.52), vec3<f32>(0.18, 0.20, 0.25), frame.thunder) * (1.0 - frame.thunder * 0.40);

    var base_fog = mix(night_fog, day_fog, day);
    base_fog = mix(base_fog, tw_fog, tw * (1.0 - rain));
    base_fog = mix(base_fog, rain_fog, rain);

    // Nether / End dimensions fallback
    if frame.dimension != 0 {
        base_fog = frame.fog_color;
        fog_amount = 1.0 - exp(-pow(dist / max(frame.render_distance * 0.85, 32.0), 2.0) * fog_density);
    }

    // --- 3. Atmospheric Golden Sunlight In-Scattering (Mie Forward Scattering) ---
    // When looking towards the sun, air is naturally filled with warm glowing light shafts and moisture
    let sun_align = max(dot(ray_dir, frame.sun_direction), 0.0);
    var sun_haze_color = vec3<f32>(0.0);
    if sun_align > 0.0 && frame.dimension == 0 && (day > 0.02 || tw > 0.02) {
        // Dual-lobe Mie forward scatter: broad forward envelope + intense solar glow
        let broad_lobe = pow(sun_align, 2.0);
        let sharp_lobe = pow(sun_align, 6.0);
        let inscatter_lobe = broad_lobe * 0.65 + sharp_lobe * 0.35;

        // Depth extinction: distant terrain is enveloped in the golden atmosphere
        let forward_haze = (1.0 - exp(-dist * 0.020)) * inscatter_lobe * (day * 0.65 + tw * 1.35) * (1.0 - rain * 0.85);
        let golden_sun = mix(vec3<f32>(1.0, 0.52, 0.16), vec3<f32>(1.0, 0.94, 0.82), day);
        sun_haze_color = golden_sun * (forward_haze * 0.65);

        let distant_lobe = pow(sun_align, 14.0) * (day * 0.45 + tw * 0.95) * (1.0 - rain * 0.9);
        let distant_color = mix(vec3<f32>(1.0, 0.54, 0.18), vec3<f32>(1.0, 0.98, 0.92), day);
        base_fog = mix(base_fog, distant_color, clamp(distant_lobe * 0.55, 0.0, 0.75));
    }

    // --- 4. Volumetric Sun Rays (God Rays / Crepuscular Light Shafts) ---
    var godrays_color = vec3<f32>(0.0);
    if god_rays && sun_align > 0.12 && (day > 0.05 || tw > 0.05) && rain < 0.85 && frame.dimension == 0 {
        let sun_view = frame.view * vec4<f32>(frame.sun_direction, 0.0);
        let clip = frame.projection * vec4<f32>(sun_view.xyz, 1.0);

        if clip.w > 0.0 {
            let ndc = clip.xy / clip.w;
            let sun_uv = vec2<f32>(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);

            let delta = sun_uv - input.uv;
            let ray_len = length(delta);

            if ray_len > 0.001 {
                let steps = 8;
                let step_len = min(ray_len, 0.45) / f32(steps);
                let step_dir = delta / ray_len;
                let step_vec = step_dir * step_len;

                // Screen-space dither: completely prevents stepping jumps when the player moves
                let dither = fract(sin(dot(input.uv, vec2<f32>(12.9898, 78.233))) * 43758.5453);
                var march_uv = input.uv + step_vec * (0.25 + dither * 0.50);
                var ray_accum = 0.0;
                var decay = 1.0;

                for (var s = 0; s < 8; s++) {
                    march_uv += step_vec;
                    if march_uv.x >= 0.0 && march_uv.x <= 1.0 && march_uv.y >= 0.0 && march_uv.y <= 1.0 {
                        let sample_d = depth_at(march_uv);
                        // Unoccluded sky shines through foliage and terrain ridges!
                        if sample_d <= 0.00002 {
                            ray_accum += decay;
                        }
                    }
                    decay *= 0.82;
                }

                // Air depth factor: nearby walls / building facades (< 6 blocks) never get painted with jumping rays!
                let air_depth = 1.0 - exp(-dist * 0.045);
                let ray_radial_fade = pow(sun_align, 2.5);
                let ray_factor = (ray_accum / 5.2) * ray_radial_fade * god_rays_intensity * (day * 0.75 + tw * 1.6) * (1.0 - rain) * air_depth;

                let ray_tint = mix(vec3<f32>(1.0, 0.52, 0.16), vec3<f32>(1.0, 0.96, 0.88), day);
                godrays_color = ray_tint * (ray_factor * 0.48);
            }
        }
    }

    let blended = mix(scene_color, base_fog, fog_amount) + godrays_color + sun_haze_color;
    return vec4<f32>(blended, input.color.a);
}

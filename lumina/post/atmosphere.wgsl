// Lumina - Atmospheric Fog & Volumetric God Rays (WGSL)

override fog_density: f32 = 1.0;
override god_rays: bool = true;
override god_rays_intensity: f32 = 1.0;
override underwater_optics: bool = true;

fn broad_lobe_fade(x: f32) -> f32 {
    return x * x * sqrt(max(x, 0.0));
}

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

        // Water absorption in linear light: Red wavelengths vanish first, giving deep vibrant turquoise tone
        let water_extinction = exp(-vec3<f32>(0.33, 0.10, 0.04) * dist);

        let day = daylight();
        let tw = twilight();
        let day_water = to_linear(vec3<f32>(0.025, 0.22, 0.38));
        let tw_water = to_linear(vec3<f32>(0.040, 0.16, 0.32));
        let night_water = to_linear(vec3<f32>(0.006, 0.045, 0.08));
        var water_scatter_color = mix(night_water, day_water, day);
        water_scatter_color = mix(water_scatter_color, tw_water, tw * (1.0 - frame.rain));
        water_scatter_color = mix(water_scatter_color, to_linear(vec3<f32>(0.02, 0.14, 0.22)), frame.rain * 0.6);

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
            col += to_linear(vec3<f32>(0.15, 0.45, 0.55)) * (caustic * caustic_fade * 0.55);
        }

        return vec4<f32>(col, 1.0);
    }

    // Camera submerged in lava
    if frame.eye_in == 2u {
        let is_terrain = input.depth > 0.00002;
        let vpos = select(vec3<f32>(0.0, 0.0, 6.0), view_position(input.uv, input.depth), is_terrain);
        let dist = select(6.0, length(vpos), is_terrain);
        let lava_fog = to_linear(vec3<f32>(1.0, 0.28, 0.03));
        let fog_factor = 1.0 - exp(-dist * 0.65);
        return vec4<f32>(mix(input.color.rgb, lava_fog, fog_factor), 1.0);
    }

    // Sky pixels: draw cosmic End sky in The End (bob-free via unbobbed FOV terms), keep Overworld/Nether sky unmodified
    if input.depth <= 0.00002 {
        if frame.dimension == 1 {
            let p00 = length(vec3<f32>(frame.projection[0][0], frame.projection[1][0], frame.projection[2][0]));
            let p11 = length(vec3<f32>(frame.projection[0][1], frame.projection[1][1], frame.projection[2][1]));
            let ndc_sky = vec2<f32>(input.uv.x * 2.0 - 1.0, 1.0 - input.uv.y * 2.0);
            let view_sky = vec3<f32>(ndc_sky.x / max(p00, 1e-4), ndc_sky.y / max(p11, 1e-4), -1.0);
            let world_ray = normalize((frame.view_inverse * vec4<f32>(view_sky, 0.0)).xyz);
            return vec4<f32>(sample_end_sky(world_ray, true), 1.0);
        }
        return vec4<f32>(input.color.rgb, 1.0);
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

    // --- 1. Crisp Near/Mid Air, Gentle Valley Haze & Seamless Far Border Fog ---
    let rd = max(frame.render_distance, 64.0);
    let ren_scale = min(192.0 / rd, 1.0);
    let world_y = vpos.y + frame.camera_position.y;
    let sky_expose = 0.15 + 0.85 * sqrt(clamp(frame.eye_light_smooth.y, 0.0, 1.0));

    // Near & mid terrain (< ~75 blocks) stays completely sharp; subtle aerial separation only far out
    let far_t = clamp((dist - 75.0) / max(rd * 0.88 - 75.0, 48.0), 0.0, 1.0);
    let aerial = far_t * far_t * 0.22 * fog_density * ren_scale;
    // Rain adds moody mist without flattening nearby hills
    let rain_mist = (1.0 - exp(-dist * 0.0055 * fog_density)) * rain * 0.55;
    var atm_fog = clamp(aerial + rain_mist, 0.0, 0.65);

    // Mountain peaks remain lush & crisp while distant low valleys keep soft depth mist
    let alt_factor = mix(1.0, 0.30, smoothstep(68.0, 132.0, world_y));
    atm_fog *= alt_factor * sky_expose;

    // Seamless Border Fog: dissolves outer chunk edges smoothly into the exact sky behind them
    let edge_t = clamp((dist - rd * 0.84) / max(rd * 0.15, 16.0), 0.0, 1.0);
    let border_fog = edge_t * edge_t * (3.0 - 2.0 * edge_t) * 0.98 * clamp(fog_density, 0.0, 1.5);

    var fog_amount = clamp(1.0 - (1.0 - atm_fog) * (1.0 - border_fog), 0.0, 1.0);

    // --- 2. Sky-Matched Atmospheric Color ---
    var base_fog = vec3<f32>(0.0);
    if frame.dimension == 1 {
        // The End: match distant void fog smoothly to the cosmic nebula sky
        base_fog = sample_end_sky(ray_dir, false);
        fog_amount = 1.0 - exp(-pow(dist / max(rd * 0.85, 56.0), 1.8) * fog_density);
    } else if frame.dimension != 0 {
        // Nether and other dimensions
        base_fog = frame.fog_color;
        fog_amount = 1.0 - exp(-pow(dist / max(rd * 0.80, 48.0), 1.6) * fog_density);
    } else {
        base_fog = sample_sky_atmosphere(ray_dir, 1.0);
    }

    // --- 3. Atmospheric Golden Sunlight In-Scattering (Mie Forward Scattering) ---
    // Warm sunlight glow concentrated far along the solar axis so nearby terrain stays vivid
    let sun_align = max(dot(ray_dir, frame.sun_direction), 0.0);
    var sun_haze_color = vec3<f32>(0.0);
    if sun_align > 0.0 && frame.dimension == 0 && (day > 0.02 || tw > 0.02) {
        // Dual-lobe Mie forward scatter: broad forward envelope + intense solar glow
        let broad_lobe = sun_align * sun_align;
        let sharp_lobe = broad_lobe * broad_lobe * broad_lobe;
        let inscatter_lobe = broad_lobe * 0.65 + sharp_lobe * 0.35;

        // Depth extinction: only distant terrain picks up warm forward in-scattering
        let forward_haze = (1.0 - exp(-dist * 0.0045)) * smoothstep(28.0, 140.0, dist) * inscatter_lobe * (day * 0.30 + tw * 1.15) * (1.0 - rain * 0.85);
        let golden_sun = mix(vec3<f32>(1.00000, 0.23725, 0.01774), vec3<f32>(1.00000, 0.87273, 0.64623), day);
        sun_haze_color = golden_sun * (forward_haze * 0.20);

        let d_lobe_4 = sharp_lobe * sharp_lobe;
        let distant_lobe = d_lobe_4 * broad_lobe * (day * 0.35 + tw * 0.90) * (1.0 - rain * 0.9);
        let distant_color = mix(vec3<f32>(1.00000, 0.25779, 0.02298), vec3<f32>(1.00000, 0.95660, 0.83240), day);
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

            if ray_len > 0.001 && ray_len < 0.80 {
                let steps = 6;
                let step_len = min(ray_len, 0.65) / f32(steps);
                let step_dir = delta / ray_len;
                let step_vec = step_dir * step_len;

                // Screen-space dither: completely prevents stepping jumps when the player moves
                let dither = fract(sin(dot(input.uv, vec2<f32>(12.9898, 78.233))) * 43758.5453);
                var march_uv = input.uv + step_vec * (0.25 + dither * 0.50);
                var ray_accum = 0.0;
                var decay = 1.0;

                for (var s = 0; s < 6; s++) {
                    march_uv += step_vec;
                    if march_uv.x >= 0.0 && march_uv.x <= 1.0 && march_uv.y >= 0.0 && march_uv.y <= 1.0 {
                        let sample_d = depth_at(march_uv);
                        if sample_d <= 0.00002 {
                            ray_accum += decay;
                        }
                    }
                    decay *= 0.77;
                }

                // Continuous air-depth ramp starting cleanly from 0 (no 3-block sphere step on overhead canopies!)
                let air_depth = smoothstep(2.0, 14.0, dist) * (1.0 - exp(-dist * 0.045));
                let screen_fade = 1.0 - smoothstep(0.45, 0.80, ray_len);
                let ray_radial_fade = broad_lobe_fade(sun_align) * smoothstep(0.12, 0.28, sun_align);
                let ray_factor = (ray_accum / 3.9) * ray_radial_fade * screen_fade * god_rays_intensity * (day * 0.75 + tw * 1.6) * (1.0 - rain) * air_depth;

                let ray_tint = mix(vec3<f32>(1.00000, 0.23725, 0.01774), vec3<f32>(1.00000, 0.91411, 0.75485), day);
                godrays_color = ray_tint * (ray_factor * 0.25);
            }
        }
    }

    let blended = mix(scene_color, base_fog, fog_amount) + godrays_color + sun_haze_color;
    return vec4<f32>(blended, 1.0);
}

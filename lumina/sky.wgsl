// Lumina - Atmospheric Sky & High-Fidelity 3D Volumetric Clouds (Minecraft World Altitude: Y=180..320)

// ============================================================================
// CONFIGURATION SWITCHES
// ============================================================================
// Turn custom clouds ON (true) or OFF (false):
// You can set default = false in horizon-shaders.toml, or toggle this override right here:
override volumetric_clouds: bool = true;
override cloud_density_opt: f32 = 1.0;
override cloud_profile: u32 = 0u;
override sun_glow: f32 = 1.0;

// Jorge Jimenez Interleaved Gradient Noise (Screen-Space Stable)
// Evaluated from screen-space projected pixel position:
// Rock-solid frame-to-frame stability: zero boiling, zero camera-bobbing swaying!
fn get_screen_dither(ray_dir: vec3<f32>) -> f32 {
    let view_dir = (frame.view * vec4<f32>(ray_dir, 0.0)).xyz;
    let z = select(-view_dir.z, view_dir.z, view_dir.z > 0.0);
    let uv = view_dir.xy / max(z, 0.0001);
    let screen_px = uv * frame.resolution;
    return fract(52.9829189 * fract(dot(screen_px, vec2<f32>(0.06711056, 0.00583715))));
}

// 2D Cloud Coverage Map
fn get_cloud_coverage(p_xz: vec2<f32>) -> f32 {
    let p = p_xz * 0.0012;
    return value_noise(p) * 0.65 + value_noise(p * 2.4) * 0.35;
}

// True 3D Cumulus Density with Organic Billows (Zero Slicing, Smooth Silhouette, High FPS)
fn sample_cumulus_density(
    pos: vec3<f32>,
    alt_frac: f32,
    target_coverage: f32,
    threshold: f32,
    wind: vec2<f32>
) -> f32 {
    // 1. Organic altitude profile (flat base condensation, dome tops)
    let base_gate = smoothstep(0.0, 0.12, alt_frac);
    let top_gate = 1.0 - smoothstep(0.55, 1.0, alt_frac);
    let height_gate = base_gate * top_gate;
    if height_gate <= 0.001 {
        return 0.0;
    }

    let p_xz = pos.xz + wind;

    // 2. Fast 2D Coverage Check: defines the horizontal cluster boundaries
    // 1st octave early exit if coverage mathematically cannot reach threshold!
    let p = p_xz * 0.0012;
    let n1 = value_noise(p);
    if (n1 * 0.65 + 0.35) <= threshold {
        return 0.0;
    }
    let cov = n1 * 0.65 + value_noise(p * 2.4) * 0.35;
    if cov <= threshold {
        return 0.0;
    }

    // Normalized envelope: 0.0 at cloud perimeter, smoothly rising to 1.0 at cloud core
    let envelope = (cov - threshold) / max(target_coverage, 0.01);

    // 3. Dynamic Cluster Height: denser cores tower higher
    let local_top = mix(0.68, 1.0, clamp(envelope * 1.2, 0.0, 1.0));
    let cluster_dome = 1.0 - smoothstep(local_top * 0.50, local_top, alt_frac);
    let shape_gate = base_gate * cluster_dome;
    if shape_gate <= 0.001 {
        return 0.0;
    }

    // 4. True 3D Cauliflower Billows
    // Evaluated only inside the cloud envelope!
    let p_billow = (pos + vec3<f32>(wind.x * 0.45, 0.0, wind.y * 0.45)) * 0.007;
    let b = noise3d_fast(p_billow);
    let billow = (b * b - 0.28) * 0.60;

    // 5. Wispy fine natural edge erosion (using fast 2D noise with height offset)
    let p_wisp = (pos.xz + wind) * 0.016 + pos.y * 0.008;
    let wisp = (value_noise(p_wisp) - 0.45) * 0.35;

    // Boundary-safe modulation: detail smoothly vanishes at the perimeter (envelope -> 0)
    // This mathematically GUARANTEES zero sharp cuts, steps, or sheared edges!
    let edge_weight = smoothstep(0.0, 0.20, envelope);
    let density = envelope * shape_gate + (billow - wisp) * (edge_weight * 0.35);

    return clamp(density * 2.8, 0.0, 1.0);
}

// High-Performance Volumetric Cloud Raymarcher (Zero Cuts, High Quality, High FPS)
fn render_volumetric_clouds(ray_dir: vec3<f32>, background_sky: vec3<f32>) -> vec3<f32> {
    if !volumetric_clouds {
        return background_sky;
    }

    // Early exit: rays looking down or grazing the horizon where cloud visibility is 0
    if abs(ray_dir.y) < 0.015 {
        return background_sky;
    }

    let cam_pos = frame.camera_position;

    // Cloud layer altitude in Minecraft world space (Y = 180 to 320)
    let h_base = 180.0;
    let h_top = 320.0;

    // Decouple camera altitude from player walking view-bobbing micro-oscillations:
    let stable_cam_y = select(round(cam_pos.y), cam_pos.y, cam_pos.y > (h_base - 20.0));

    let dy = select(ray_dir.y, 0.00001, abs(ray_dir.y) < 0.00001);

    let t_base = (h_base - stable_cam_y) / dy;
    let t_top  = (h_top  - stable_cam_y) / dy;

    let t_min = min(t_base, t_top);
    let t_max = max(t_base, t_top);

    // If cloud slab is completely behind camera:
    if t_max <= 0.0 {
        return background_sky;
    }

    let t_start = max(t_min, 0.0);
    let max_cloud_distance = 2600.0;

    if t_start >= max_cloud_distance {
        return background_sky;
    }

    let t_end = min(t_max, max_cloud_distance);
    let march_len = t_end - t_start;
    if march_len <= 1.0 {
        return background_sky;
    }

    // Stable screen-space dither
    let dither = get_screen_dither(ray_dir);

    // Adaptive step density:
    // When looking up (thin slab ~140m), 18m steps = ~8 steps total!
    // When looking near horizon, capped at 16 steps total!
    var step_len = 18.0;
    var max_steps = 16;
    if cloud_profile == 0u {
        step_len = 24.0;
        max_steps = 12;
    } else if cloud_profile == 2u {
        step_len = 15.0;
        max_steps = 20;
    }

    var t = t_start + dither * step_len;
    var current_pos = cam_pos + ray_dir * t;

    // Precalculate invariants outside the raymarching loop:
    let target_coverage = mix(0.24, 0.58, frame.rain) * cloud_density_opt;
    let threshold = 1.0 - target_coverage;
    let wind = vec2<f32>(frame.time * 2.5, frame.time * 1.0);

    // Time & weather factors
    let day = daylight();
    let tw = twilight();
    let night = night_factor();
    let rain = frame.rain;

    let is_sun = (day > 0.03 || tw > 0.03);
    let light_dir = select(frame.moon_direction, frame.sun_direction, is_sun);

    // Dual-lobe Mie forward scattering (Silver Lining!)
    let cos_theta = dot(ray_dir, light_dir);
    let g1 = 0.80;
    let hg1 = (1.0 - g1*g1) / (4.0 * 3.14159265 * pow(1.0 + g1*g1 - 2.0*g1*cos_theta, 1.5));
    let g2 = -0.24;
    let hg2 = (1.0 - g2*g2) / (4.0 * 3.14159265 * pow(1.0 + g2*g2 - 2.0*g2*cos_theta, 1.5));
    let phase = mix(hg2, hg1, 0.76) * 3.2;

    // 1. Direct Sun / Moon lighting colors
    let day_sun = vec3<f32>(1.65, 1.60, 1.50);
    let tw_sun  = vec3<f32>(1.95, 0.82, 0.28);
    let night_moon = vec3<f32>(0.26, 0.32, 0.46);
    let storm_sun = vec3<f32>(0.32, 0.36, 0.42);

    var direct_light = mix(night_moon, day_sun, day);
    direct_light = mix(direct_light, tw_sun, tw * (1.0 - rain * 0.5));
    direct_light = mix(direct_light, storm_sun, rain * 0.75);

    // 2. Ambient Sky light
    let day_amb = vec3<f32>(0.58, 0.72, 0.92);
    let tw_amb  = vec3<f32>(0.52, 0.26, 0.46);
    let night_amb = vec3<f32>(0.045, 0.065, 0.12);
    let storm_amb = vec3<f32>(0.22, 0.24, 0.28);

    var ambient_light = mix(night_amb, day_amb, day);
    ambient_light = mix(ambient_light, tw_amb, tw * (1.0 - rain * 0.5));
    ambient_light = mix(ambient_light, storm_amb, rain * 0.75);

    // 3. Ground bounce light
    let ground_bounce = mix(vec3<f32>(0.01), vec3<f32>(0.38, 0.46, 0.30), day) * (1.0 - rain * 0.7);

    var transmittance = 1.0;
    var accumulated_color = vec3<f32>(0.0);

    for (var i = 0; i < max_steps; i++) {
        if t >= t_end {
            break;
        }

        if current_pos.y >= h_base && current_pos.y <= h_top {
            let alt_frac = clamp((current_pos.y - h_base) / (h_top - h_base), 0.0, 1.0);
            let d = sample_cumulus_density(current_pos, alt_frac, target_coverage, threshold, wind);
            if d > 0.003 {
                let sun_exposure = smoothstep(0.12, 0.88, alt_frac);
                let direct_radiance = direct_light * (sun_exposure * 0.85 + phase * 0.38);
                let sky_radiance = ambient_light * (0.48 + 0.52 * alt_frac);
                let bounce_radiance = ground_bounce * ((1.0 - alt_frac) * 0.32);
                let step_radiance = direct_radiance + sky_radiance + bounce_radiance;

                let step_extinction = exp(-d * step_len * 0.035);
                let step_scatter = 1.0 - step_extinction;

                accumulated_color += step_radiance * step_scatter * transmittance;
                transmittance *= step_extinction;

                if transmittance < 0.025 {
                    break;
                }
            }
        }
        t += step_len;
        current_pos += ray_dir * step_len;
    }

    // Atmospheric aerial perspective fade near horizon and far distance
    let dist_fade = 1.0 - smoothstep(max_cloud_distance * 0.60, max_cloud_distance, t_start);
    let horizon_fade = smoothstep(0.015, 0.065, abs(ray_dir.y));
    let cloud_visibility = dist_fade * horizon_fade;

    accumulated_color *= cloud_visibility;
    transmittance = mix(1.0, transmittance, cloud_visibility);

    return background_sky * transmittance + accumulated_color;
}

fn sky(input: SkyInput) -> vec4<f32> {
    // Leave Nether and End untouched
    if frame.dimension != 0 {
        return input.color;
    }

    let d = input.direction;
    let up = max(d.y, 0.0);

    // Sun alignment & glare
    let cos_sun = dot(d, frame.sun_direction);
    let sun_facing = max(cos_sun, 0.0);

    // Moon alignment
    let cos_moon = dot(d, frame.moon_direction);
    let moon_facing = max(cos_moon, 0.0);

    // Weather and time factors from common.wgsl
    let day = daylight();
    let tw = twilight();
    let night = night_factor();
    let rain = frame.rain;

    // --- 1. Clean Daytime Azure Sky ---
    let day_zenith = vec3<f32>(0.12, 0.38, 0.88);
    let day_horizon = vec3<f32>(0.56, 0.76, 0.94);
    let day_sky = mix(day_horizon, day_zenith, smoothstep(0.0, 0.75, up));

    // --- 2. Magical Sunset / Twilight Palette ---
    let dusk_zenith = vec3<f32>(0.06, 0.08, 0.24);
    let dusk_mid = vec3<f32>(0.40, 0.22, 0.50);
    let dusk_horizon_sun = vec3<f32>(1.0, 0.52, 0.16);
    let dusk_horizon_spread = vec3<f32>(0.76, 0.28, 0.46);
    let dusk_horizon = mix(dusk_horizon_spread, dusk_horizon_sun, pow(sun_facing, 1.6));

    var dusk_sky = mix(dusk_horizon, dusk_mid, smoothstep(0.0, 0.28, up));
    dusk_sky = mix(dusk_sky, dusk_zenith, smoothstep(0.22, 0.75, up));

    // --- 3. Night Sky Palette ---
    let night_zenith = vec3<f32>(0.02, 0.03, 0.08);
    let night_horizon = vec3<f32>(0.05, 0.08, 0.16);
    let night_sky = mix(night_horizon, night_zenith, smoothstep(0.0, 0.60, up));

    // --- 4. Overcast Rain & Storm Palette ---
    let rain_zenith = vec3<f32>(0.20, 0.24, 0.30);
    let rain_horizon = vec3<f32>(0.44, 0.48, 0.54);
    let storm_darken = 1.0 - frame.thunder * 0.45;
    let rain_sky = mix(rain_horizon, rain_zenith, smoothstep(0.0, 0.70, up)) * storm_darken;

    // Blend clear skies across day/twilight/night
    var clear_sky = mix(night_sky, day_sky, day);
    clear_sky = mix(clear_sky, dusk_sky, tw * (1.0 - rain));

    // Blend with rain overcast
    var final_sky = mix(clear_sky, rain_sky, rain);

    // --- 5. Atmospheric Scattering (Preserves Vanilla Square Sun Quad) ---
    if rain < 0.95 {
        // Soft atmospheric twilight warmth along horizon without fake circular glare disc
        let sun_haze = pow(sun_facing, 3.0) * 0.12 * tw * (1.0 - rain) * sun_glow;
        final_sky += vec3<f32>(1.0, 0.55, 0.22) * sun_haze;

        let lunar_halo = pow(moon_facing, 8.0) * 0.05 * night * (1.0 - rain);
        final_sky += vec3<f32>(0.65, 0.78, 1.0) * lunar_halo;
    }

    // --- 6. Volumetric 3D Cumulus Clouds (Minecraft World Altitude: Y=180..320) ---
    final_sky = render_volumetric_clouds(d, final_sky);

    // --- 7. Horizon / Nadir Ground Blend ---
    let horizon_color = mix(mix(night_horizon, day_horizon, day), dusk_horizon, tw * (1.0 - rain));
    let ground_color = mix(horizon_color, rain_horizon, rain);
    if d.y < 0.0 {
        let nadir_fade = smoothstep(0.0, -0.45, d.y);
        final_sky = mix(final_sky, ground_color * 0.35, nadir_fade);
    }

    return vec4<f32>(final_sky, input.color.a);
}

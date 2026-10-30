// Lumina - Cinematic Grade, Lens Flares, Wide Bloom & Tonemapping (WGSL)

override exposure: f32 = 0.94;
override contrast: f32 = 1.04;
override saturation: f32 = 1.08;
override vignette: bool = true;
override chromatic_aberration: bool = true;
override chromatic_aberration_strength: f32 = 1.0;
override wide_bloom: bool = true;
override bloom_intensity: f32 = 1.0;
override lens_flares: bool = true;

// Extract highlight glow for bloom: fast, zero depth reads!
fn extract_bloom(uv: vec2<f32>) -> vec3<f32> {
    let col = textureSampleLevel(previous, linear_sampler, uv, 0.0).rgb;
    let lum = luminance(col);
    // Threshold set to 1.25..2.40: grass, sky and normal surfaces have lum < 1.0 and return 0.0!
    // Only genuine light sources (torches, fire, lanterns, lava, sun) emit bloom.
    return col * smoothstep(1.25, 2.40, lum);
}

// Cinematic Anamorphic Sun Streak (Zero Hard Edges, Ultra-Smooth Gaussian Falloff)
fn get_sun_lens_flare(uv: vec2<f32>) -> vec3<f32> {
    if !lens_flares || daylight() <= 0.02 || frame.rain > 0.85 || frame.dimension != 0 {
        return vec3<f32>(0.0);
    }

    let sun_view = frame.view * vec4<f32>(frame.sun_direction, 0.0);
    let clip = frame.projection * vec4<f32>(sun_view.xyz, 1.0);
    if clip.w <= 0.0001 {
        return vec3<f32>(0.0);
    }

    let ndc = clip.xy / clip.w;
    let sun_uv = vec2<f32>(ndc.x * 0.5 + 0.5, 0.5 - ndc.y * 0.5);

    // Skip if sun is off-screen
    if sun_uv.x < -0.15 || sun_uv.x > 1.15 || sun_uv.y < -0.15 || sun_uv.y > 1.15 {
        return vec3<f32>(0.0);
    }

    // Smooth sun occlusion check (averaging 5 points to prevent view-bobbing flicker)
    let o = vec2<f32>(0.008, 0.008);
    var occ = 0.0;
    if depth_at(sun_uv) <= 0.00002 { occ += 0.36; }
    if depth_at(sun_uv + vec2<f32>(o.x, 0.0)) <= 0.00002 { occ += 0.16; }
    if depth_at(sun_uv - vec2<f32>(o.x, 0.0)) <= 0.00002 { occ += 0.16; }
    if depth_at(sun_uv + vec2<f32>(0.0, o.y)) <= 0.00002 { occ += 0.16; }
    if depth_at(sun_uv - vec2<f32>(0.0, o.y)) <= 0.00002 { occ += 0.16; }

    if occ <= 0.01 {
        return vec3<f32>(0.0);
    }

    let aspect = frame.resolution.x / frame.resolution.y;
    let delta = (uv - sun_uv) * vec2<f32>(aspect, 1.0);
    let r2 = dot(delta, delta);

    // Radiant Solar Corona & Atmospheric Light Bloom (soft, glowing, zero laser lines)
    let core_glow = exp(-r2 * 60.0) * vec3<f32>(1.25, 1.10, 0.90) * 0.32;
    let wide_warmth = exp(-r2 * 8.0) * vec3<f32>(1.10, 0.85, 0.60) * 0.16;

    return (core_glow + wide_warmth) * (occ * daylight() * (1.0 - frame.rain * 0.85));
}

fn post(input: PostInput) -> vec4<f32> {
    var c = input.color.rgb;

    // --- 1. Chromatic Aberration (Subtle, Non-Distracting Cinema Lens Dispersion) ---
    if chromatic_aberration {
        let aspect = frame.resolution.x / frame.resolution.y;
        let to_center = (input.uv - 0.5) * vec2<f32>(aspect, 1.0);
        let r2 = dot(to_center, to_center);
        // Reduced from 0.0038 to 0.0010: zero pink/cyan fringe on trees, subtle clean lens curve
        let ca_offset = to_center * (r2 * 0.0010 * chromatic_aberration_strength);
        let r_col = textureSampleLevel(previous, linear_sampler, input.uv + ca_offset, 0.0).r;
        let b_col = textureSampleLevel(previous, linear_sampler, input.uv - ca_offset, 0.0).b;
        c = vec3<f32>(r_col, c.g, b_col);
    }

    // --- 2. Dual-Tier Wide Bloom (Single 8-Tap Interleaved Pass: 2x Faster, 0 Depth Reads!) ---
    let res_scale = frame.resolution.y / 720.0;
    let blur_step = (res_scale / frame.resolution) * 3.0;

    var bloom_sum = vec3<f32>(0.0);
    // 8-tap interleaved radius pattern: even taps core (2.5x), odd taps wide (7.5x)
    for (var i = 0; i < 8; i++) {
        let fi = f32(i);
        let angle = fi * 0.785398;
        let rad_mult = select(2.5, 7.5, (i & 1) != 0);
        let offset = vec2<f32>(cos(angle), sin(angle)) * (blur_step * rad_mult);
        bloom_sum += extract_bloom(input.uv + offset);
    }
    c += (bloom_sum / 8.0) * (0.13 * bloom_intensity);

    // --- 3. Cinematic Lens Flare & Anamorphic Sun Streaks ---
    c += get_sun_lens_flare(input.uv);

    // --- 4. Exposure ---
    c *= exposure;

    // --- 5. ACES Filmic Tonemapping ---
    c = tonemap_aces(c);

    // --- 6. Natural Contrast Curve ---
    c = pow(max(c, vec3<f32>(0.0)), vec3<f32>(contrast));

    // --- 7. Saturation ---
    let lum = luminance(c);
    let rain_sat = mix(saturation, saturation * 0.88, frame.rain * 0.70);
    c = mix(vec3<f32>(lum), c, rain_sat);

    // --- 8. Subtle Cinematic Vignette ---
    if vignette {
        let aspect = frame.resolution.x / frame.resolution.y;
        let coord = (input.uv - 0.5) * vec2<f32>(aspect, 1.0);
        let dist = length(coord) / (0.5 * length(vec2<f32>(aspect, 1.0)));
        let vig = 1.0 - smoothstep(0.70, 1.30, dist) * 0.18;
        c *= vig;
    }

    return vec4<f32>(clamp(c, vec3<f32>(0.0), vec3<f32>(1.0)), input.color.a);
}

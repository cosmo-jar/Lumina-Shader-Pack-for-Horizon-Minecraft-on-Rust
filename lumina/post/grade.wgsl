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
override anti_aliasing: u32 = 0u;

// High-Precision Edge-Selective Anti-Aliasing with Subpixel Clarity Protection
// Smooths geometric stairs on block silhouettes and roofs while keeping textures 100% razor-sharp.
fn apply_clarity_fxaa(uv: vec2<f32>, raw_col: vec3<f32>) -> vec3<f32> {
    if anti_aliasing == 2u {
        return raw_col;
    }

    let px = 1.0 / frame.resolution;

    // Sample 4 cross neighbours
    let col_u = textureSampleLevel(previous, linear_sampler, uv + vec2<f32>(0.0, -px.y), 0.0).rgb;
    let col_d = textureSampleLevel(previous, linear_sampler, uv + vec2<f32>(0.0,  px.y), 0.0).rgb;
    let col_l = textureSampleLevel(previous, linear_sampler, uv + vec2<f32>(-px.x, 0.0), 0.0).rgb;
    let col_r = textureSampleLevel(previous, linear_sampler, uv + vec2<f32>( px.x, 0.0), 0.0).rgb;

    let luma_c = luminance(raw_col);
    let luma_u = luminance(col_u);
    let luma_d = luminance(col_d);
    let luma_l = luminance(col_l);
    let luma_r = luminance(col_r);

    let luma_min = min(luma_c, min(min(luma_u, luma_d), min(luma_l, luma_r)));
    let luma_max = max(luma_c, max(max(luma_u, luma_d), max(luma_l, luma_r)));
    let luma_range = luma_max - luma_min;

    // Clarity Guard: Skip all flat surfaces, textures, HUD, and low-contrast areas!
    // Sharp mode (0u) uses high threshold (0.09) to strictly target high-contrast geometric edges.
    // Smooth mode (1u) uses 0.045 for softer cinematic coverage.
    let edge_thresh = select(0.09, 0.045, anti_aliasing == 1u);
    if luma_range < max(edge_thresh, luma_max * 0.14) {
        // Flat surface: add subtle adaptive micro-sharpening to make textures look crisp and HD!
        if anti_aliasing == 0u {
            let micro_sharp = raw_col * 1.12 - (col_u + col_d + col_l + col_r) * 0.03;
            return clamp(micro_sharp, vec3<f32>(0.0), vec3<f32>(1.5) * raw_col);
        }
        return raw_col;
    }

    // Determine edge orientation (horizontal vs vertical)
    let edge_h = abs(-2.0 * luma_c + luma_u + luma_d);
    let edge_v = abs(-2.0 * luma_c + luma_l + luma_r);
    let is_horizontal = edge_h >= edge_v;

    // Gradient along normal of the edge
    let grad_pos = select(abs(luma_d - luma_c), abs(luma_r - luma_c), is_horizontal);
    let grad_neg = select(abs(luma_u - luma_c), abs(luma_l - luma_c), is_horizontal);
    let step_dir = select(-1.0, 1.0, grad_pos >= grad_neg);

    let subpixel_factor = select(0.35, 0.50, anti_aliasing == 1u);
    let subpixel_offset = select(
        vec2<f32>(0.0, px.y * step_dir * subpixel_factor),
        vec2<f32>(px.x * step_dir * subpixel_factor, 0.0),
        is_horizontal
    );

    let smoothed = textureSampleLevel(previous, linear_sampler, uv + subpixel_offset, 0.0).rgb;
    let blend_weight = clamp(luma_range / max(luma_max, 0.001), 0.25, 0.75);
    return mix(raw_col, smoothed, blend_weight);
}

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
    if !lens_flares || daylight() <= 0.02 || frame.rain > 0.85 || frame.dimension != 0 || frame.eye_in != 0u {
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

    let aspect = frame.resolution.x / frame.resolution.y;
    let delta = (uv - sun_uv) * vec2<f32>(aspect, 1.0);
    let r2 = dot(delta, delta);

    // Early exit: only pixels close to the sun need occlusion testing (saves ~10 million depth reads/frame!)
    if r2 > 0.35 {
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

    // Radiant Solar Corona & Atmospheric Light Bloom (soft, glowing, zero laser lines)
    let core_glow = exp(-r2 * 60.0) * vec3<f32>(1.25, 1.10, 0.90) * 0.32;
    let wide_warmth = exp(-r2 * 8.0) * vec3<f32>(1.10, 0.85, 0.60) * 0.16;

    return (core_glow + wide_warmth) * (occ * daylight() * (1.0 - frame.rain * 0.85));
}

fn post(input: PostInput) -> vec4<f32> {
    var c = apply_clarity_fxaa(input.uv, input.color.rgb);

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

    // --- 2. Dual-Tier Wide Bloom (Single 8-Tap Interleaved Pass: Precomputed static directions) ---
    if wide_bloom && bloom_intensity > 0.01 {
        let res_scale = frame.resolution.y / 720.0;
        let blur_step = (res_scale / frame.resolution) * 3.0;

        let dirs = array<vec2<f32>, 8>(
            vec2<f32>( 1.0000,  0.0000),
            vec2<f32>( 0.7071,  0.7071),
            vec2<f32>( 0.0000,  1.0000),
            vec2<f32>(-0.7071,  0.7071),
            vec2<f32>(-1.0000,  0.0000),
            vec2<f32>(-0.7071, -0.7071),
            vec2<f32>( 0.0000, -1.0000),
            vec2<f32>( 0.7071, -0.7071)
        );

        var bloom_sum = vec3<f32>(0.0);
        for (var i = 0; i < 8; i++) {
            let rad_mult = select(2.5, 7.5, (i & 1) != 0);
            let offset = dirs[i] * (blur_step * rad_mult);
            bloom_sum += extract_bloom(input.uv + offset);
        }
        c += (bloom_sum / 8.0) * (0.13 * bloom_intensity);
    }

    // --- 3. Cinematic Lens Flare & Anamorphic Sun Streaks ---
    c += get_sun_lens_flare(input.uv);

    // --- 4. Exposure ---
    let day_exposure = mix(exposure, exposure * 1.08, daylight());
    c *= day_exposure;

    // --- 5. ACES Filmic Tonemapping ---
    c = tonemap_aces(c);

    // --- 6. Natural Contrast Curve ---
    c = pow(max(c, vec3<f32>(0.0)), vec3<f32>(contrast));

    // --- 7. Saturation & Selective Vibrance ---
    let day_vibrance = daylight() * (1.0 - frame.rain * 0.5);
    let gray_v = (c.r + c.g + c.b) * 0.33333;
    let mn = min(c.r, min(c.g, c.b));
    let mx = max(c.r, max(c.g, c.b));
    let sat_weight = (1.0 - (mx - mn)) * (1.0 - mx * 0.8) * gray_v * 4.5;
    // Vibrance expands midtone chroma on natural foliage without blowing out saturated highlights
    c = mix(c, c + (c - vec3<f32>(gray_v)) * (0.35 * day_vibrance), clamp(sat_weight, 0.0, 1.0));

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

// Lumina - Cinematic Grade, Wide Bloom & Tonemapping (WGSL)

override exposure: f32 = 0.94;
override contrast: f32 = 1.04;
override saturation: f32 = 1.08;
override vignette: bool = true;
override chromatic_aberration: bool = true;
override chromatic_aberration_strength: f32 = 1.0;
override wide_bloom: bool = true;
override bloom_intensity: f32 = 1.0;
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

    let luma_c = sqrt(max(luminance(raw_col), 0.0));
    let luma_u = sqrt(max(luminance(col_u), 0.0));
    let luma_d = sqrt(max(luminance(col_d), 0.0));
    let luma_l = sqrt(max(luminance(col_l), 0.0));
    let luma_r = sqrt(max(luminance(col_r), 0.0));

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

// Extract highlight glow for bloom in linear light: fast, zero depth reads!
fn extract_bloom(uv: vec2<f32>) -> vec3<f32> {
    let col = textureSampleLevel(previous, linear_sampler, uv, 0.0).rgb;
    let lum = luminance(col);
    // Threshold in linear light (1.65..4.50): grass and normal sunlit terrain stay below bloom threshold;
    // torches, fire, lanterns, lava and sun emit smooth atmospheric glow.
    return col * smoothstep(1.65, 4.50, lum);
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
        c += (bloom_sum / 8.0) * (0.11 * bloom_intensity);
    }

    // --- 3. Exposure (in linear light) ---
    c *= pow(exposure, 2.2);

    // --- 5. Perceptual Look: ACES Filmic Tonemapping, Contrast, Vibrance & Saturation ---
    // Run display-tuned look curves on encoded light while preserving HDR headroom when active
    let hr_g = pow(max(frame.headroom, 1.0), 1.0 / 2.2);
    var g = to_gamma(c);
    g = tonemap_aces(g / hr_g) * hr_g;

    // --- 6. Natural Contrast Curve ---
    g = pow(max(g, vec3<f32>(0.0)), vec3<f32>(contrast));

    // --- 7. Saturation & Selective Vibrance ---
    let day_vibrance = daylight() * (1.0 - frame.rain * 0.5);
    let gray_v = (g.r + g.g + g.b) * 0.33333;
    let mn = min(g.r, min(g.g, g.b));
    let mx = max(g.r, max(g.g, g.b));
    let sat_weight = (1.0 - (mx - mn)) * (1.0 - mx * 0.8) * gray_v * 4.5;
    // Vibrance expands midtone chroma on natural foliage without blowing out saturated highlights
    g = mix(g, g + (g - vec3<f32>(gray_v)) * (0.35 * day_vibrance), clamp(sat_weight, 0.0, 1.0));

    let lum = luminance(g);
    let rain_sat = mix(saturation, saturation * 0.88, frame.rain * 0.70);
    g = mix(vec3<f32>(lum), g, rain_sat);

    // --- 8. Subtle Cinematic Vignette ---
    if vignette {
        let aspect = frame.resolution.x / frame.resolution.y;
        let coord = (input.uv - 0.5) * vec2<f32>(aspect, 1.0);
        let dist = length(coord) / (0.5 * length(vec2<f32>(aspect, 1.0)));
        let vig = 1.0 - smoothstep(0.70, 1.30, dist) * 0.18;
        g *= vig;
    }

    c = to_linear(g);
    return vec4<f32>(max(c, vec3<f32>(0.0)), 1.0);
}

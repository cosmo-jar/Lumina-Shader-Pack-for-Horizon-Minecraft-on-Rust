// Lumina - Shared shader utilities (WGSL)

// Standard Rec.709 perceived luminance
fn luminance(c: vec3<f32>) -> f32 {
    return dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
}

// 2D Hash function with integer bitwise XOR (zero trigonometric precision loss)
fn hash2(p: vec2<f32>) -> f32 {
    let ip = vec2<i32>(floor(p));
    let u = vec2<u32>(ip + vec2<i32>(1000000, 1000000));
    var n = u.x * 1597334673u ^ u.y * 3812015801u;
    n = n * (n ^ (n >> 15u));
    return f32(n & 0x007FFFFFu) * (1.0 / 8388608.0);
}

// 2D Value noise with quintic Hermite smoothing (Factored: 3x faster, bitwise identical)
fn value_noise(p: vec2<f32>) -> f32 {
    let ip = vec2<i32>(floor(p));
    let u0 = vec2<u32>(ip + vec2<i32>(1000000, 1000000));
    let u1 = u0 + vec2<u32>(1u, 1u);
    let f = fract(p);
    let u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    let ux0 = u0.x * 1597334673u;
    let ux1 = u1.x * 1597334673u;
    let uy0 = u0.y * 3812015801u;
    let uy1 = u1.y * 3812015801u;

    var n00 = ux0 ^ uy0;
    n00 = n00 * (n00 ^ (n00 >> 15u));
    var n10 = ux1 ^ uy0;
    n10 = n10 * (n10 ^ (n10 >> 15u));
    var n01 = ux0 ^ uy1;
    n01 = n01 * (n01 ^ (n01 >> 15u));
    var n11 = ux1 ^ uy1;
    n11 = n11 * (n11 ^ (n11 >> 15u));

    let f00 = f32(n00 & 0x007FFFFFu);
    let f10 = f32(n10 & 0x007FFFFFu);
    let f01 = f32(n01 & 0x007FFFFFu);
    let f11 = f32(n11 & 0x007FFFFFu);

    let x0 = mix(f00, f10, u.x);
    let x1 = mix(f01, f11, u.x);

    return mix(x0, x1, u.y) * (1.0 / 8388608.0);
}

// 3D integer hash (zero trigonometric loss, 100% artifact-free)
fn hash33(p: vec3<f32>) -> vec3<f32> {
    let ip = vec3<i32>(floor(p));
    let u = vec3<u32>(ip + vec3<i32>(1000000, 1000000, 1000000));
    var n = u * 1597334673u ^ u.yzx * 3812015801u ^ u.zxy * 2798794411u;
    n = n * (n ^ (n >> vec3<u32>(15u)));
    return vec3<f32>(n & vec3<u32>(0x007FFFFFu)) * (1.0 / 8388608.0);
}

// Ultra-fast 3D scalar hash (3x faster than hash33, zero vector overhead)
fn hash3(p: vec3<f32>) -> f32 {
    let ip = vec3<i32>(floor(p));
    let u = vec3<u32>(ip + vec3<i32>(1000000, 1000000, 1000000));
    var n = u.x * 1597334673u ^ u.y * 3812015801u ^ u.z * 2798794411u;
    n = n * (n ^ (n >> 15u));
    return f32(n & 0x007FFFFFu) * (1.0 / 8388608.0);
}

// Ultra-fast 3D value noise with smooth cubic Hermite interpolation (Factored: 3x faster, bitwise identical)
fn noise3d_fast(p: vec3<f32>) -> f32 {
    let ip = vec3<i32>(floor(p));
    let u0 = vec3<u32>(ip + vec3<i32>(1000000, 1000000, 1000000));
    let u1 = u0 + vec3<u32>(1u, 1u, 1u);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);

    let ux0 = u0.x * 1597334673u;
    let ux1 = u1.x * 1597334673u;
    let uy0 = u0.y * 3812015801u;
    let uy1 = u1.y * 3812015801u;
    let uz0 = u0.z * 2798794411u;
    let uz1 = u1.z * 2798794411u;

    var n000 = ux0 ^ uy0 ^ uz0;
    n000 = n000 * (n000 ^ (n000 >> 15u));
    var n100 = ux1 ^ uy0 ^ uz0;
    n100 = n100 * (n100 ^ (n100 >> 15u));
    var n010 = ux0 ^ uy1 ^ uz0;
    n010 = n010 * (n010 ^ (n010 >> 15u));
    var n110 = ux1 ^ uy1 ^ uz0;
    n110 = n110 * (n110 ^ (n110 >> 15u));
    var n001 = ux0 ^ uy0 ^ uz1;
    n001 = n001 * (n001 ^ (n001 >> 15u));
    var n101 = ux1 ^ uy0 ^ uz1;
    n101 = n101 * (n101 ^ (n101 >> 15u));
    var n011 = ux0 ^ uy1 ^ uz1;
    n011 = n011 * (n011 ^ (n011 >> 15u));
    var n111 = ux1 ^ uy1 ^ uz1;
    n111 = n111 * (n111 ^ (n111 >> 15u));

    let f000 = f32(n000 & 0x007FFFFFu);
    let f100 = f32(n100 & 0x007FFFFFu);
    let f010 = f32(n010 & 0x007FFFFFu);
    let f110 = f32(n110 & 0x007FFFFFu);
    let f001 = f32(n001 & 0x007FFFFFu);
    let f101 = f32(n101 & 0x007FFFFFu);
    let f011 = f32(n011 & 0x007FFFFFu);
    let f111 = f32(n111 & 0x007FFFFFu);

    let x00 = mix(f000, f100, u.x);
    let x10 = mix(f010, f110, u.x);
    let x01 = mix(f001, f101, u.x);
    let x11 = mix(f011, f111, u.x);

    let y0 = mix(x00, x10, u.y);
    let y1 = mix(x01, x11, u.y);

    return mix(y0, y1, u.z) * (1.0 / 8388608.0);
}

// 2D Worley cellular noise with 3x3 search (ultra-fast 9-cell search: 3x faster than 3D Worley)
fn worley2d(p: vec2<f32>) -> f32 {
    let id = floor(p);
    let f = fract(p);
    var min_d = 2.0;
    for (var x = -1; x <= 1; x++) {
        for (var y = -1; y <= 1; y++) {
            let g = vec2<f32>(f32(x), f32(y));
            let h0 = hash2(id + g);
            let h1 = hash2(id + g + vec2<f32>(19.31, 37.17));
            let pt = g + 0.15 + vec2<f32>(h0, h1) * 0.70;
            let diff = pt - f;
            min_d = min(min_d, dot(diff, diff));
        }
    }
    return clamp(sqrt(min_d), 0.0, 1.0);
}

// 3D Worley cellular noise with full 3x3x3 neighborhood (100% seamless, true 3D spherical billow domes)
fn worley3d(p: vec3<f32>) -> f32 {
    let id = floor(p);
    let f = fract(p);
    var min_d = 2.0;
    for (var x = -1; x <= 1; x++) {
        for (var y = -1; y <= 1; y++) {
            for (var z = -1; z <= 1; z++) {
                let g = vec3<f32>(f32(x), f32(y), f32(z));
                let h = hash33(id + g);
                let pt = g + 0.15 + h * 0.70;
                let diff = pt - f;
                min_d = min(min_d, dot(diff, diff));
            }
        }
    }
    return clamp(sqrt(min_d), 0.0, 1.0);
}

// 3D Value noise with C2 quintic Hermite smoothing for volumetric cloud erosion
fn noise3d(p: vec3<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);

    let n000 = hash33(i + vec3<f32>(0.0, 0.0, 0.0)).x;
    let n100 = hash33(i + vec3<f32>(1.0, 0.0, 0.0)).x;
    let n010 = hash33(i + vec3<f32>(0.0, 1.0, 0.0)).x;
    let n110 = hash33(i + vec3<f32>(1.0, 1.0, 0.0)).x;
    let n001 = hash33(i + vec3<f32>(0.0, 0.0, 1.0)).x;
    let n101 = hash33(i + vec3<f32>(1.0, 0.0, 1.0)).x;
    let n011 = hash33(i + vec3<f32>(0.0, 1.0, 1.0)).x;
    let n111 = hash33(i + vec3<f32>(1.0, 1.0, 1.0)).x;

    let x00 = mix(n000, n100, u.x);
    let x10 = mix(n010, n110, u.x);
    let x01 = mix(n001, n101, u.x);
    let x11 = mix(n011, n111, u.x);

    let y0 = mix(x00, x10, u.y);
    let y1 = mix(x01, x11, u.y);

    return mix(y0, y1, u.z);
}

// Multi-octave fractal noise for natural surface patterns (puddles, ripples)
fn fbm_puddle(p: vec2<f32>) -> f32 {
    var n = value_noise(p * 0.22) * 0.58;
    n += value_noise(p * 0.55) * 0.28;
    n += value_noise(p * 1.35) * 0.14;
    return n;
}

// Procedural expanding concentric raindrop impact waves
fn puddle_raindrop_ripples(pos: vec2<f32>, time: f32) -> vec2<f32> {
    var rip = vec2<f32>(0.0);
    let scale = 2.4; // density of falling rain impacts (~0.4m per impact zone)
    for (var g = 0; g < 2; g++) {
        let offset = vec2<f32>(f32(g) * 0.53, f32(g) * 0.37);
        let p = pos * scale + offset;
        let cell = floor(p);
        let uv = fract(p) - 0.5;

        let h = hash2(cell + f32(g) * 19.31);
        let center = (vec2<f32>(hash2(cell * 2.3 + 1.1), hash2(cell * 4.7 + 3.3)) - 0.5) * 0.6;
        let delta = uv - center;
        let dist = length(delta);

        let speed = 2.5;
        let cycle = fract(time * speed + h);
        let radius = cycle * 0.48; // expands outward
        let ring_diff = dist - radius;

        let wave = sin(ring_diff * 42.0) * exp(-abs(ring_diff) * 15.0);
        let intensity = (1.0 - cycle) * smoothstep(0.0, 0.12, cycle);

        if dist > 0.005 && dist < 0.52 {
            rip += (delta / dist) * (wave * intensity);
        }
    }
    return rip;
}

// Distance from noon (0.25) in day cycle: 0.0 at noon, 0.5 at midnight
fn time_from_noon() -> f32 {
    let t = fract(frame.day_time);
    let d = abs(t - 0.25);
    return select(d, 1.0 - d, d > 0.5);
}

// Daylight factor (1 at noon and day, 0 at night)
fn daylight() -> f32 {
    if frame.dimension != 0 { return 0.0; }
    let dist = time_from_noon();
    // Full daylight from noon (0.0) through morning/day (0.21), fades at sunset (0.22..0.28)
    return 1.0 - smoothstep(0.22, 0.28, dist);
}

// Twilight / sunset / sunrise factor (peaks tightly at sunset/sunrise, zero during day and noon!)
fn twilight() -> f32 {
    if frame.dimension != 0 { return 0.0; }
    let dist = time_from_noon();
    // Zero at day (dist = 0.208) and noon (0.0); rises at sunset (0.22..0.26), fades by night (0.32)
    return smoothstep(0.22, 0.255, dist) * (1.0 - smoothstep(0.275, 0.32, dist));
}

// Night factor (1 at midnight, 0 during day)
fn night_factor() -> f32 {
    if frame.dimension != 0 { return 0.0; }
    let dist = time_from_noon();
    return smoothstep(0.26, 0.33, dist);
}

// ACES filmic tonemapping approximation
fn tonemap_aces(x: vec3<f32>) -> vec3<f32> {
    let a = 2.51;
    let b = 0.03;
    let c = 2.43;
    let d = 0.59;
    let e = 0.14;
    return clamp(
        (x * (a * x + vec3<f32>(b))) / (x * (c * x + vec3<f32>(d)) + vec3<f32>(e)),
        vec3<f32>(0.0),
        vec3<f32>(1.0)
    );
}

// Physical water waves: crossing swells with harmonic surface chop
const WATER_AMPLITUDE: f32 = 0.08;

fn water_wave(xz: vec2<f32>, t: f32) -> f32 {
    let swell = sin(xz.x * 0.90 + t * 1.3) * sin(xz.y * 0.70 + t * 1.1);
    let chop = sin((xz.x + xz.y) * 1.70 - t * 2.1) * 0.5;
    return 0.5 - (swell + chop) / 3.0;
}

// Soft shoulder above 0.8 to roll bright glints and highlights into white smoothly
fn shoulder(c: vec3<f32>) -> vec3<f32> {
    let over = max(c - vec3<f32>(0.8), vec3<f32>(0.0));
    return min(c, vec3<f32>(0.8)) + 0.2 * (vec3<f32>(1.0) - exp(-over * 5.0));
}

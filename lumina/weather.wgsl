// Lumina - Atmospheric Weather (WGSL)
// Cinematic translucent rain streaks and glowing snow flakes

fn weather(input: WeatherInput) -> vec4<f32> {
    let day = daylight();
    let tw = twilight();
    let night = night_factor();

    // Lighting levels
    let block_light = input.light.x;
    let sky_light = input.light.y;

    // Dynamic sky illumination
    let day_ambient = vec3<f32>(0.72, 0.78, 0.88);
    let tw_ambient = vec3<f32>(0.85, 0.60, 0.50);
    let night_ambient = vec3<f32>(0.18, 0.22, 0.35);

    var ambient = mix(night_ambient, day_ambient, day);
    ambient = mix(ambient, tw_ambient, tw);

    // Warm golden torch light on precipitation near lanterns and torches
    let torch_color = vec3<f32>(1.0, 0.74, 0.38);
    let torch_boost = torch_color * (pow(block_light, 1.6) * 1.5);

    // Thunder flash illumination
    let thunder_flash = frame.thunder * vec3<f32>(0.90, 0.95, 1.20) * 1.5;

    let total_light = ambient * (0.35 + 0.65 * sky_light) + torch_boost + thunder_flash;

    if input.snow {
        // Fluffy glowing snowflakes that catch sunset and moonlight
        let snow_base = vec3<f32>(0.92, 0.96, 1.0);
        let snow_col = snow_base * total_light;
        let alpha = input.color.a * 0.85;
        return vec4<f32>(snow_col, alpha);
    } else {
        // Translucent cinematic rain streaks (silvery-cyan glass-like appearance)
        let rain_base = vec3<f32>(0.74, 0.84, 0.96);
        let rain_col = rain_base * total_light;
        // Soften harsh vanilla rain opacity for delicate, non-intrusive rainfall
        let alpha = input.color.a * 0.42;
        return vec4<f32>(rain_col, alpha);
    }
}

// Lumina - Terrain & Water Vertex Stage (WGSL)
override waving: bool = true;
override wave_strength: f32 = 1.0;
override water_waves: bool = true;

fn vertex(input: VertexInput) -> vec3<f32> {
    var p = input.position;
    let world = p + frame.camera_position;
    let t = frame.time;

    // Physical rolling water waves: top water surface corners sink smoothly
    if water_waves && input.fluid == 1u && input.face == 1u {
        p.y -= water_wave(world.xz, t * 2.5) * WATER_AMPLITUDE;
        return p;
    }

    // High-performance single-sine wind swaying for foliage (leaves, grass, flowers)
    if waving && wave_strength > 0.0 && input.material != 0u {
        let exposed = smoothstep(0.3, 0.9, input.light.y) * (1.0 + frame.rain * 0.5);
        let phase = world.x * 0.55 + world.z * 0.45;
        let w = sin(t * 2.2 + phase) * (0.05 * wave_strength * exposed);
        let top = 1.0 - input.uv.y;
        p.x += w * top;
        p.z += w * (top * 0.5);
    }

    return p;
}

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// MARK: - Refraction

/// How far a round glass rod lying on the page moves what is under it, as a share of its radius, at `u`: the
/// distance from the rod's axis over its radius, 0 to 1. A ray looking straight down enters the rod's curved top,
/// bends toward the surface normal (Snell's law) and crosses the rod's thickness at that angle; the sideways
/// distance it covers is the shift. It is zero on the axis, peaks at 0.231 near u = 0.84 and falls back to zero at
/// the rim, where the rod is thinnest. So the middle magnifies (1.5 times for glass) and the rim squeezes the image
/// into a thin seam: the edge you see without the rod drawing one.
static float rodShift(float u, float index) {
    float thickness = sqrt(1 - u * u);
    float tilt = asin(u);
    float refracted = asin(u / index);
    return thickness * tan(tilt - refracted);
}

// MARK: - Shader

/// A round glass rod, upright, rolled once across a layer of single-color ink on a plain background. It draws only
/// the band the rod covers, opaque, and nothing elsewhere, so it goes over the ink it bends.
///
/// - `bounds`: the layer's rectangle. The rod's axis travels from one radius before its leading edge to one
///   radius past its trailing edge, so the pass starts and ends with the rod off the layer.
/// - `progress`: 0 to 1 along that path.
/// - `radius`: the rod's radius in points.
/// - `dispersion`: how much further blue bends than green, and red less, as a share of the shift.
/// - `background`: the color under the layer.
[[ stitchable ]] half4 glassRod(float2 position, SwiftUI::Layer layer, float4 bounds, float progress, float radius, float dispersion, half4 background) {
    float axis = mix(bounds.x - radius, bounds.x + bounds.z + radius, progress);
    float across = position.x - axis;
    float u = across / radius;
    if (abs(u) >= 1) {
        return half4(0);
    }

    // Crown glass bends light with an index of 1.5. The rod bends sideways only, so letters keep their height
    float shift = sign(u) * radius * rodShift(abs(u), 1.5);
    half4 red = layer.sample(position - float2(shift * (1 - dispersion), 0));
    half4 green = layer.sample(position - float2(shift, 0));
    half4 blue = layer.sample(position - float2(shift * (1 + dispersion), 0));

    // Each channel sees the ink at its own place, so each mixes ink and background by its own coverage: where only
    // red still covers ink, black ink on white shows cyan and white ink on black shows red
    half3 coverage = half3(red.a, green.a, blue.a);
    half total = red.a + green.a + blue.a;
    half3 ink = total > 0 ? (red.rgb + green.rgb + blue.rgb) / total : half3(0);
    half3 color = mix(background.rgb, ink, coverage);

    // A fine highlight down the axis, where the rod's surface faces the light: a spread of a third of a point (a
    // pixel at 3x), strongest halfway up and gone at the ends. At most 40 percent of the way to white (gray 102 on
    // black), so it reads as light on the glass, not as another stroke. It fades in and out over one radius as the
    // axis comes onto the layer and leaves it, so it never appears at an edge
    float along = 2 * (position.y - bounds.y) / bounds.w - 1;
    float onLayer = smoothstep(0.0, radius, axis - bounds.x) * smoothstep(0.0, radius, bounds.x + bounds.z - axis);
    half glint = half(0.4 * exp(-across * across / (2 * 0.33 * 0.33)) * (1 - along * along) * onLayer);
    return half4(mix(color, half3(1), glint), 1);
}

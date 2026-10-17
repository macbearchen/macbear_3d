#version 300 es
// Tonemap shader functions (append after Composite/Fullscreen.es3.frag)

// ACES Filmic curve (Narkowicz fit)
vec3 tonemapACES(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

// Reinhard curve
vec3 tonemapReinhard(vec3 x) {
    return clamp(x / (vec3(1.0) + x), 0.0, 1.0);
}

// Uncharted 2 Filmic curve
vec3 uncharted2Tonemap(vec3 x) {
    const float A = 0.15, B = 0.50, C = 0.10, D = 0.20, E = 0.02, F = 0.30;
    return ((x * (A * x + C * B) + D * E) / (x * (A * x + B) + D * F)) - E / F;
}

// Khronos PBR Neutral Tone Mapper (KHR_materials_pbrNeutral)
// Input color is non-negative and in Linear Rec. 709.
// Note: exposure is pre-applied before this call (color *= uExposure in applyTonemap).
// This matches common engine practice; the KHR spec itself does not prescribe exposure placement.
vec3 tonemapPbrNeutral(vec3 color) {
    const float startCompression = 0.8 - 0.04;
    const float desaturation = 0.15;

    float x = min(color.r, min(color.g, color.b));
    float offset = x < 0.08 ? x - 6.25 * x * x : 0.04;
    color -= offset;

    float peak = max(color.r, max(color.g, color.b));
    if (peak < startCompression) return color;

    const float d = 1.0 - startCompression;
    float newPeak = 1.0 - d * d / (peak + d - startCompression);
    color *= newPeak / peak;

    float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return mix(color, newPeak * vec3(1.0, 1.0, 1.0), g);
}

vec3 applyTonemap(vec3 color) {
    color *= uExposure;
    if (uTonemapMode == 1) {
        return tonemapReinhard(color);
    } else if (uTonemapMode == 2) {
        return tonemapACES(color);
    } else if (uTonemapMode == 3) {
        float W = 11.2;
        vec3 curr = uncharted2Tonemap(color * 2.0);
        vec3 whiteScale = 1.0 / uncharted2Tonemap(vec3(W));
        return clamp(curr * whiteScale, 0.0, 1.0);
    } else if (uTonemapMode == 4) {
        vec3 ldr = tonemapACES(color);
        float gray = dot(ldr, vec3(0.2126, 0.7152, 0.0722));
        return vec3(gray);
    } else if (uTonemapMode == 5) {
        return clamp(tonemapPbrNeutral(color), 0.0, 1.0);
    }
    // Mode 0 (None): clamp exposure-scaled HDR to [0,1] to prevent
    // sRGB gamma encode receiving out-of-range values.
    return clamp(color, 0.0, 1.0);
}
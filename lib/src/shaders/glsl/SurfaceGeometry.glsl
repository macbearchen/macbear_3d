// surface geometry: for pixel/vertex shader
struct SurfaceGeometry {
    highp vec3 Position;
    mediump vec3 Normal;
};

// safe normalize
mediump vec3 safe_normalize(mediump vec3 v) {
    mediump float len2 = max(dot(v, v), 1e-8);
    return v * inversesqrt(len2);
}

mediump float pow5(mediump float x) {
    mediump float x2 = x * x;
    return x2 * x2 * x;
}

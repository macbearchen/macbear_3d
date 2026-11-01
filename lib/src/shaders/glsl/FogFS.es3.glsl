#version 300 es
// Fog frag-shader: ES3 //////////
// must append to fragment shader

// sphere fog base on camera position
in highp float fogDist; // distance to camera

// x: sphereStart, y: sphereDepth, z: planeHeight
uniform mediump vec3 uFogParams;
uniform mediump vec3 uFogColor;

// plane fog
uniform mediump vec4 uPlaneFog;
uniform mediump vec3 uPlaneFogColor;

#ifdef ENABLE_WATER_SPECULAR
// Water shader already declares uLightDir, uLightColor
#elif !defined(ENABLE_PIXEL_LIGHTING)
// When pixel lighting is not active, declare directional light uniforms for fog forward-scattering
uniform mediump vec3 uLightDir;
uniform mediump vec3 uLightColor;
#endif

mediump vec4 ApplyFog(mediump vec4 color)
{
    mediump float fogDensity;
    mediump float fogBlend;
    mediump vec4 result = color;

    // View ray in object space: from surface to eye
    mediump vec3 V = safe_normalize(uEyePos - ObjectspaceV);
    // Forward sun scattering phase: peaks when looking directly towards directional light (dot(V, uLightDir))
    mediump float sunScatter = max(dot(V, uLightDir), 0.0);
    sunScatter = pow5(sunScatter); // sharp forward scattering highlight
    mediump vec3 sunGlow = uLightColor * (sunScatter * 0.75);

    // 1/2: plane fog (ambient modulated + directional sun scattering)
    if (uFogParams.z > 0.0) {
        mediump float planeDist = dot(uPlaneFog.xyz, ObjectspaceV) + uPlaneFog.w;
        fogDensity = clamp(planeDist / uFogParams.z, 0.0, 1.0);
        fogBlend = clamp(fogDensity + 1.0 - color.a, 0.0, 1.0);
        mediump vec3 litPlaneFogColor = uPlaneFogColor + sunGlow;
        result = vec4(mix(result.rgb, litPlaneFogColor, fogBlend), color.a);
    }
    // 2/2: sphere fog (ambient modulated + directional sun scattering)
    if (uFogParams.y > 0.0) {
        fogDensity = clamp((fogDist - uFogParams.x) / uFogParams.y, 0.0, 1.0);
        fogBlend = clamp(fogDensity + 1.0 - color.a, 0.0, 1.0);
        mediump vec3 litSphereFogColor = uFogColor + sunGlow;
        result = vec4(mix(result.rgb, litSphereFogColor, fogBlend), color.a);
    }
    return result;
}

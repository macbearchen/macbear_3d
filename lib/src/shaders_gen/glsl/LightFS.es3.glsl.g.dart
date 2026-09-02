// Generated file – do not edit.
// ignore: constant_identifier_names
const String LightFS_glsl = r"""
#version 300 es

// UE4 windowed inverse-square attenuation (Karis 2013)
// +1.0 避免光源近距離過曝/firefly，rangeFade 讓光照在 radius 邊界平滑歸零
float calcAttenuation(float distSq, float radiusSq) {
    float ratio = distSq / radiusSq;
    float rangeFade = clamp(1.0 - ratio * ratio, 0.0, 1.0);
    return (rangeFade * rangeFade) / (distSq + 1.0);
}

// -------------------------------------------------------
// Point lights
// -------------------------------------------------------
#ifdef ENABLE_POINT_LIGHTS

// uPointLights[0]：light0, light1
// light0: col0: positionRange(xyz:pos,w:range), col1: colorIntensity(rgb:color,a:intensity)
// light1: col2: positionRange(xyz:pos,w:range), col3: colorIntensity(rgb:color,a:intensity)
// same for uPointLights[1,2,3]
// uPointLights[1]：light2, light3
// uPointLights[2]：light4, light5
// uPointLights[3]：light6, light7
uniform mediump mat4 uPointLights[4];
uniform mediump ivec2 uPointLightCounts; // x=lightCount, y=shadowCastingCount

vec3 calcPointLight(int i, vec3 fragPos, vec3 N, bool castShadow) {
    int matIndex = i >> 1;      // i / 2 bit shift
    int localIndex = i & 1;     // i % 2 bitwise AND

    mat4 m = uPointLights[matIndex];
    vec4 positionRangeSq = (localIndex == 0) ? m[0] : m[2];

    vec3 lightPos = positionRangeSq.xyz;
    float radiusSq = positionRangeSq.w;

    vec3 L = (lightPos - fragPos) * uInvObjScale;
    float distSq = dot(L, L);

    // Early exit: 超出光源半徑直接略過所有計算
    if (distSq >= radiusSq) {
        return vec3(0.0);
    }

    float invDist = inversesqrt(max(distSq, 0.0001));
    L *= invDist; // 就地 normalize

    float NdotL = dot(N, L);
    if (NdotL <= 0.0) {
        return vec3(0.0);
    }

    vec4 colorIntensity = (localIndex == 0) ? m[1] : m[3];
    float atten = calcAttenuation(distSq, radiusSq);

    // colorIntensity: rgb -> lightColor, a -> lightIntensity
    vec3 radiance = colorIntensity.rgb * (colorIntensity.a * atten * NdotL);

    if (castShadow) {
        // TODO: DPSM shadow lookup 接進來
        // float shadow = sampleDPSMShadow(i, fragPos, lightPos);
        // radiance *= shadow;
    }

    return radiance;
}

// point lights lighting in object space
lowp vec3 CalculateLighting(vec3 fragPos, vec3 N) {
    int lightCount = uPointLightCounts.x;
    if (lightCount == 0) return vec3(0.0);

    vec3 result = vec3(0.0);
    int shadowCount = uPointLightCounts.y;

    for (int i = 0; i < 8; i++) {
        if (i >= lightCount) break;
        bool castShadow = (i < shadowCount);
        result += calcPointLight(i, fragPos, N, castShadow);
    }
    return result;
}
#endif // ENABLE_POINT_LIGHTS

// -------------------------------------------------------
// Spot lights
// -------------------------------------------------------
#ifdef ENABLE_SPOT_LIGHTS

// Packing: 1 mat4 per spotlight (4 vec4)
//   m[0] xyz: object-space position,  w: range²
//   m[1] rgb: color,                  a: intensity
//   m[2] xyz: object-space direction, w: 0
//   m[3] x:   cos(innerAngle),        y: cos(outerAngle)
uniform mediump mat4 uSpotLights[8];
uniform mediump ivec2 uSpotLightCounts; // x=lightCount, y=shadowCastingBitwise

// Smooth cone falloff: 0 outside outerAngle, 1 inside innerAngle
// cosTheta = dot(-fragToLight_unit, spotDir_unit)
float calcConeAttenuation(float cosTheta, float cosInner, float cosOuter) {
    float t = clamp((cosTheta - cosOuter) / max(cosInner - cosOuter, 0.0001), 0.0, 1.0);
    return t * t; // quadratic for smooth edge
}

vec3 calcSpotLight(int i, vec3 fragPos, vec3 N) {
    mat4 m = uSpotLights[i];
    vec4 posRangeSq = m[0]; // xyz: position, w: range²
    float radiusSq  = posRangeSq.w;

    vec3 lightPos  = posRangeSq.xyz;
    vec3 L = (lightPos - fragPos) * uInvObjScale;
    float distSq = dot(L, L);

    // Early exit: 距離超出半徑
    if (distSq >= radiusSq) {
        return vec3(0.0);
    }

    float invDist = inversesqrt(max(distSq, 0.0001));
    vec3 Lnorm = L * invDist;

    // cone attenuation
    vec4 dir4       = m[2]; // xyz: spotlight direction (object space, pre-normalised)
    float cosTheta  = dot(-Lnorm, dir4.xyz); // dir4.xyz already normalised on CPU
    vec4 coneAngles = m[3]; // x: cos(inner), y: cos(outer)

    // Early exit: 超出聚光錐 outer angle
    if (cosTheta <= coneAngles.y) {
        return vec3(0.0);
    }

    float NdotL = dot(N, Lnorm);
    if (NdotL <= 0.0) {
        return vec3(0.0);
    }

    vec4 colorInt = m[1]; // rgb: color, a: intensity
    float atten = calcAttenuation(distSq, radiusSq);
    float spot  = calcConeAttenuation(cosTheta, coneAngles.x, coneAngles.y);

    return colorInt.rgb * (colorInt.a * atten * spot * NdotL);
}

// Spot lights lighting in object space
lowp vec3 CalculateSpotLighting(vec3 fragPos, vec3 N) {
    int lightCount = uSpotLightCounts.x;
    if (lightCount == 0) return vec3(0.0);

    vec3 result = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        if (i >= lightCount) break;
        result += calcSpotLight(i, fragPos, N);
    }
    return result;
}

#endif // ENABLE_SPOT_LIGHTS

""";

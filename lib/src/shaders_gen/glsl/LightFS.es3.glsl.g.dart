// Generated file – do not edit.
// ignore: constant_identifier_names
const String LightFS_glsl = r"""
#version 300 es

// uPointLights[0]：light0, light1
// light0: col0: positionRange(xyz:pos,w:range), col1: colorIntensity(rgb:color,a:intensity)
// light1: col2: positionRange(xyz:pos,w:range), col3: colorIntensity(rgb:color,a:intensity)
// same for uPointLights[1,2,3]
// uPointLights[1]：light2, light3
// uPointLights[2]：light4, light5
// uPointLights[3]：light6, light7
uniform mediump mat4 uPointLights[4];

uniform mediump ivec2 uPointLightCounts; // x=lightCount, y=shadowCastingCount

// UE4 windowed inverse-square attenuation (Karis 2013)
// +1.0 避免光源近距離過曝/firefly，rangeFade 讓光照在 radius 邊界平滑歸零
float calcAttenuation(float distSq, float radiusSq) {
    float ratio = distSq / radiusSq;
    float rangeFade = clamp(1.0 - ratio * ratio, 0.0, 1.0);
    return (rangeFade * rangeFade) / (distSq + 1.0);
}

vec3 calcPointLight(int i, vec3 fragPos, vec3 N, bool castShadow) {
    int matIndex = i / 2;      // 哪個 mat4
    int localIndex = i % 2;    // 該 mat4 裡的第幾盞燈

    mat4 m = uPointLights[matIndex];
    vec4 positionRangeSq = localIndex == 0 ? m[0] : m[2];
    vec4 colorIntensity = localIndex == 0 ? m[1] : m[3];

    vec3 lightPos = positionRangeSq.xyz;
    float radiusSq = positionRangeSq.w;

    vec3 L = lightPos - fragPos;
    L *= uInvObjScale;
    float distSq = dot(L, L);          // 用它算距離平方
    L = L * inversesqrt(max(distSq, 0.0001)); // 就地 normalize，覆寫成單位向量

    float atten = calcAttenuation(distSq, radiusSq);
    float NdotL = max(dot(N, L), 0.0);

    // colorIntensity: rgb -> lightColor, a -> lightIntensity
    vec3 radiance = colorIntensity.rgb * colorIntensity.a * atten * NdotL;

    if (castShadow) {
        // TODO: DPSM shadow lookup 接進來
        // float shadow = sampleDPSMShadow(i, fragPos, lightPos);
        // radiance *= shadow;
    }

    return radiance;
}

// point lights lighting in object space
lowp vec3 CalculateLighting(vec3 fragPos, vec3 N) {
    vec3 result = vec3(0.0);
    int lightCount = uPointLightCounts.x;
    int shadowCount = uPointLightCounts.y;

    for (int i = 0; i < lightCount; i++) {
        bool castShadow = i < shadowCount;
        result += calcPointLight(i, fragPos, N, castShadow);
    }
    return result;
}

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
uniform mediump int  uSpotLightCount;

// Smooth cone falloff: 0 outside outerAngle, 1 inside innerAngle
// cosTheta = dot(-fragToLight_unit, spotDir_unit)
float calcConeAttenuation(float cosTheta, float cosInner, float cosOuter) {
    float t = clamp((cosTheta - cosOuter) / max(cosInner - cosOuter, 0.0001), 0.0, 1.0);
    return t * t; // quadratic for smooth edge
}

vec3 calcSpotLight(int i, vec3 fragPos, vec3 N) {
    mat4 m = uSpotLights[i];
    vec4 posRangeSq = m[0]; // xyz: position, w: range²
    vec4 colorInt   = m[1]; // rgb: color, a: intensity
    vec4 dir4       = m[2]; // xyz: spotlight direction (object space, pre-normalised)
    vec4 coneAngles = m[3]; // x: cos(inner), y: cos(outer)

    vec3 lightPos  = posRangeSq.xyz;
    float radiusSq = posRangeSq.w;

    vec3 L = lightPos - fragPos;
    L *= uInvObjScale;
    float distSq = dot(L, L);
    vec3 Lnorm = L * inversesqrt(max(distSq, 0.0001));

    // distance attenuation (same UE4 windowed-inverse-square as point light)
    float atten = calcAttenuation(distSq, radiusSq);

    // cone attenuation
    float cosTheta = dot(-Lnorm, dir4.xyz); // dir4.xyz already normalised on CPU
    float spot = calcConeAttenuation(cosTheta, coneAngles.x, coneAngles.y);

    float NdotL = max(dot(N, Lnorm), 0.0);

    return colorInt.rgb * colorInt.a * atten * spot * NdotL;
}

// Spot lights lighting in object space
lowp vec3 CalculateSpotLighting(vec3 fragPos, vec3 N) {
    vec3 result = vec3(0.0);
    for (int i = 0; i < uSpotLightCount; i++) {
        result += calcSpotLight(i, fragPos, N);
    }
    return result;
}

#endif // ENABLE_SPOT_LIGHTS

""";

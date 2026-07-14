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

float calcAttenuation(float dist, float radius) {
    float distSq = dist * dist;
    float rangeSq = radius * radius;
    float atten = 1.0 / max(distSq, 0.0001);
    float ratio = distSq / rangeSq;
    float rangeFade = clamp(1.0 - ratio * ratio, 0.0, 1.0);
    return atten * rangeFade * rangeFade;
}

vec3 calcPointLight(int i, vec3 fragPos, vec3 N, bool castShadow) {
    int matIndex = i / 2;      // 哪個 mat4
    int localIndex = i % 2;    // 該 mat4 裡的第幾盞燈

    mat4 m = uPointLights[matIndex];
    vec4 positionRange  = localIndex == 0 ? m[0] : m[2];
    vec4 colorIntensity = localIndex == 0 ? m[1] : m[3];

    vec3 lightPos = positionRange.xyz;
    float radius   = positionRange.w;
    vec3 lightColor = colorIntensity.rgb;
    float intensity  = colorIntensity.a;

    vec3 L = lightPos - fragPos;
    float dist = length(L);
    L = normalize(L);

    float atten = calcAttenuation(dist, radius);
    float NdotL = max(dot(N, L), 0.0);

    vec3 radiance = lightColor * intensity * atten * NdotL;

    if (castShadow) {
        // TODO: DPSM shadow lookup 接進來
        // float shadow = sampleDPSMShadow(i, fragPos, lightPos);
        // radiance *= shadow;
    }

    return radiance;
}

// point lights lighting in object space
lowp vec3 CalculateLighting() {
    vec3 result = vec3(0.0);
    int lightCount = uPointLightCounts.x;
    int shadowCount = uPointLightCounts.y;

    vec3 fragPos = ObjectspaceV;
    vec3 N = ObjectspaceN;

    for (int i = 0; i < lightCount; i++) {
        bool castShadow = i < shadowCount;
        result += calcPointLight(i, fragPos, N, castShadow);
    }
    return result;
}

/*
in vec3 vWorldPos;
in vec3 vNormal;

out vec4 fragColor;

void main() {
    vec3 N = normalize(vNormal);

    vec3 result = vec3(0.0);
    int lightCount = uPointLightCounts.x;
    int shadowCount = uPointLightCounts.y;

    for (int i = 0; i < lightCount; i++) {
        bool castShadow = i < shadowCount;
        result += calcPointLight(i, vWorldPos, N, castShadow);
    }

    fragColor = vec4(result, 1.0);
}
*/
""";

#version 300 es
// Fog frag-shader: ES3 //////////
// must insert before fragment shader

struct PointLight {
    vec4 positionRange;   // xyz=position, w=range
    vec4 colorIntensity;  // rgb=color, a=intensity
};

layout(std140) uniform uPointLightBlock {
    PointLight lights[4];
};

// x = 總光照數量 (lightCount), y = 投影陰影數量 (shadowCastingCount)
// 保證 lights[0..y-1] 為投影陰影燈，其餘不投影
uniform ivec2 uPointLightCounts;

in vec3 vWorldPos;
in vec3 vNormal;

out vec4 fragColor;

float calcAttenuation(float dist, float radius) {
    float distSq = dist * dist;
    float rangeSq = radius * radius;
    float atten = 1.0 / max(distSq, 0.0001);
    float ratio = distSq / rangeSq;
    float rangeFade = clamp(1.0 - ratio * ratio, 0.0, 1.0);
    return atten * rangeFade * rangeFade;
}

vec3 calcPointLight(int i, vec3 fragPos, vec3 N, bool castShadow) {
    vec3 lightPos   = lights[i].positionRange.xyz;
    float radius     = lights[i].positionRange.w;
    vec3 lightColor  = lights[i].colorIntensity.rgb;
    float intensity   = lights[i].colorIntensity.a;

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

/*
void main() {
    vec3 N = normalize(vNormal);

    vec3 result = vec3(0.0);
    int lightCount = uPointLightCounts.x;
    int shadowCount = uPointLightCounts.y;

    for (int i = 0; i < lightCount; i++) {
        bool castShadow = i < shadowCount; // 排序保證陰影燈在前段
        result += calcPointLight(i, vWorldPos, N, castShadow);
    }

    fragColor = vec4(result, 1.0);
}
*/
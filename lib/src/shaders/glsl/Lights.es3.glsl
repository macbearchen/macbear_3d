struct PointLight {
    vec4 positionRange;   // xyz=position, w=range
    vec4 colorIntensity;  // rgb=color, a=intensity
};

layout(std140) uniform uLightBlock {
    PointLight lights[4];
    ivec4 castShadowFlags;  // 4 盞燈的 shadow on/off
    int lightCount;
};

// calculate point light
void calcPointLight(int i, vec3 fragPos, vec3 N, vec3 V, inout vec3 result) {
    vec3 lightPos = lights[i].positionRange.xyz;
    float radius = lights[i].positionRange.w;
    vec3 lightColor = lights[i].colorIntensity.rgb;
    float intensity = lights[i].colorIntensity.a;

    vec3 L = lightPos - fragPos;
    float dist = length(L);
    L = normalize(L);

    float atten = 1.0 / max(dist * dist, 0.0001);
    float rangeFade = clamp(1.0 - pow((dist*dist) / (radius*radius), 2.0), 0.0, 1.0);
    atten *= rangeFade * rangeFade;

    float NdotL = max(dot(N, L), 0.0);
    result += lightColor * intensity * atten * NdotL;
}
#version 300 es

lowp float ComputeShadowPCF(highp sampler2DShadow sampler, highp vec2 texelSize, highp vec2 uv, highp float refZ);

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

vec3 calcPointLight(int i, SurfaceGeometry geo, bool castShadow) {
    int matIndex = i >> 1;      // i / 2 bit shift
    int localIndex = i & 1;     // i % 2 bitwise AND

    mat4 m = uPointLights[matIndex];
    vec4 positionRangeSq = (localIndex == 0) ? m[0] : m[2];

    vec3 lightPos = positionRangeSq.xyz;
    float radiusSq = positionRangeSq.w;

    vec3 L = (lightPos - geo.Position) * uInvObjScale;
    float distSq = dot(L, L);

    // Early exit: 超出光源半徑直接略過所有計算
    if (distSq >= radiusSq) {
        return vec3(0.0);
    }

    float invDist = inversesqrt(max(distSq, 0.0001));
    L *= invDist; // 就地 normalize

    float NdotL = dot(geo.Normal, L);
    if (NdotL <= 0.0) {
        return vec3(0.0);
    }

    vec4 colorIntensity = (localIndex == 0) ? m[1] : m[3];
    float atten = calcAttenuation(distSq, radiusSq);

    // colorIntensity: rgb -> lightColor, a -> lightIntensity
    vec3 radiance = colorIntensity.rgb * (colorIntensity.a * atten * NdotL);

    if (castShadow) {
        // TODO: DPSM shadow lookup 接進來
        // float shadow = sampleDPSMShadow(i, geo.Position, lightPos);
        // radiance *= shadow;
    }

    return radiance;
}

// point lights lighting in object space
lowp vec3 CalculateLighting(SurfaceGeometry geo) {
    int lightCount = uPointLightCounts.x;
    if (lightCount == 0) return vec3(0.0);

    vec3 result = vec3(0.0);
    int shadowCount = uPointLightCounts.y;

    for (int i = 0; i < 8; i++) {
        if (i >= lightCount) break;
        bool castShadow = (i < shadowCount);
        result += calcPointLight(i, geo, castShadow);
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

#ifdef ENABLE_SPOT_SHADOW
uniform highp sampler2DShadow SamplerSpotShadowmap; // GL_TEXTURE4
uniform highp vec2 SpotShadowmapTexelSize;          // 1.0 / spot shadowmap resolution (pre-computed on CPU)
uniform highp mat4 uMatrixSpotShadowAtlas[8];       // Bias * Projection * View * Model for each spotlight slot
uniform highp float SpotShadowNormalBias;           // normal bias for spotlight shadow acne

// Spot shadow with atlas: project biased fragment position using spotlight i's shadow matrix
lowp float ComputeSpotShadow(int i, SurfaceGeometry geo) {
    vec4 biasedPos = vec4(geo.Position + geo.Normal * SpotShadowNormalBias, 1.0);
    highp vec4 lightCoord = uMatrixSpotShadowAtlas[i] * biasedPos;

    if (lightCoord.w <= 0.0) {
        return 1.0;
    }
    vec3 proj = lightCoord.xyz / lightCoord.w;

    // Viewport bounds in atlas:
    // X in [0, 1], Y in [slotMinY, slotMaxY] where slot is i out of 8 (slot / 8.0 to (slot + 1) / 8.0)
    float slotMinY = float(i) * 0.125; // i / 8.0
    float slotMaxY = slotMinY + 0.125;

    if (proj.x < 0.0 || proj.x > 1.0 || proj.y < slotMinY || proj.y > slotMaxY || proj.z < 0.0 || proj.z > 1.0) {
        return 1.0;
    }
    return ComputeShadowPCF(SamplerSpotShadowmap, SpotShadowmapTexelSize, proj.xy, proj.z - 0.0005);
}
#endif // ENABLE_SPOT_SHADOW

// Smooth cone falloff: 0 outside outerAngle, 1 inside innerAngle
// cosTheta = dot(-fragToLight_unit, spotDir_unit)
float calcConeAttenuation(float cosTheta, float cosInner, float cosOuter) {
    float t = clamp((cosTheta - cosOuter) / max(cosInner - cosOuter, 0.0001), 0.0, 1.0);
    return t * t; // quadratic for smooth edge
}

vec3 calcSpotLight(int i, SurfaceGeometry geo) {
    mat4 m = uSpotLights[i];
    vec4 posRangeSq = m[0]; // xyz: position, w: range²
    float radiusSq  = posRangeSq.w;

    vec3 lightPos  = posRangeSq.xyz;
    vec3 L = (lightPos - geo.Position) * uInvObjScale;
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

    float NdotL = dot(geo.Normal, Lnorm);
    if (NdotL <= 0.0) {
        return vec3(0.0);
    }

    vec4 colorInt = m[1]; // rgb: color, a: intensity
    float atten = calcAttenuation(distSq, radiusSq);
    float spot  = calcConeAttenuation(cosTheta, coneAngles.x, coneAngles.y);

    vec3 radiance = colorInt.rgb * (colorInt.a * atten * spot * NdotL);

    return radiance;
}

// Spot lights lighting in object space
lowp vec3 CalculateSpotLighting(SurfaceGeometry geo) {
    int lightCount = uSpotLightCounts.x;
    if (lightCount == 0) return vec3(0.0);

    vec3 result = vec3(0.0);
    int shadowBitmask = uSpotLightCounts.y;
    for (int i = 0; i < 8; i++) {
        if (i >= lightCount) break;
        vec3 radiance = calcSpotLight(i, geo);
        if (radiance == vec3(0.0)) {
            continue;
        }
#ifdef ENABLE_SPOT_SHADOW
        bool castShadow = ((shadowBitmask & (1 << i)) != 0);
        if (castShadow) {
            radiance *= ComputeSpotShadow(i, geo);
        }
#endif
        result += radiance;
    }
    return result;
}

#endif // ENABLE_SPOT_LIGHTS

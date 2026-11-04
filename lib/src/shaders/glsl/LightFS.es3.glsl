#version 300 es

uniform mediump ivec2 uLightCounts; // x=pointCount, y=spotCount

mediump float ComputeShadowPCF(highp sampler2DShadow sampler, highp vec2 texelSize, highp vec2 uv, highp float refZ);

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
// light0: col0: positionRange(xyz:pos, w:range)
//         col1: colorIntensity(rgb:color * intensity, a: atlasShadowIndex)
// light1: col2: positionRange(xyz:pos, w:range)
//         col3: colorIntensity(rgb:color * intensity, a: atlasShadowIndex)
// same for uPointLights[1,2,3]
// uPointLights[1]：light2, light3
// uPointLights[2]：light4, light5
// uPointLights[3]：light6, light7
uniform mediump mat4 uPointLights[4];

mediump vec3 calcPointLight(int i, SurfaceGeometry geo) {
    int matIndex = i >> 1;      // i / 2 bit shift
    int localIndex = i & 1;     // i % 2 bitwise AND

    mat4 m = uPointLights[matIndex];
    vec4 positionRangeSq = (localIndex == 0) ? m[0] : m[2];

    vec3 lightPos = positionRangeSq.xyz;
    float radiusSq = positionRangeSq.w;

    vec3 L = (lightPos - geo.Position) * uInvObjScale;
    float distSq = dot(L, L);

    // Early exit: outside radius
    if (distSq >= radiusSq) {
        return vec3(0.0);
    }

    float invDist = inversesqrt(max(distSq, 0.0001));
    L *= invDist; // 就地 normalize

    float NdotL = dot(geo.Normal, L);
    if (NdotL <= 0.0) {
        return vec3(0.0);
    }

    // light factor
    mediump float atten = calcAttenuation(distSq, radiusSq);
    mediump float lightFactor = atten * NdotL; 
    if (lightFactor <= 0.0) {
        return vec3(0.0);
    }

    mediump vec4 colorIntensity = (localIndex == 0) ? m[1] : m[3]; // colorIntensity: rgb -> color * intensity
    mediump vec3 radiance = colorIntensity.rgb * lightFactor;

    mediump int shadowIndex = int(colorIntensity.a); // a: atlasShadowIndex
    if (shadowIndex < 3) {
        // TODO: DPSM shadow lookup 接進來
        // float shadow = sampleDPSMShadow(i, geo.Position, lightPos);
        // radiance *= shadow;
    }

    return radiance;
}

// point lights lighting in object space
mediump vec3 CalculatePointLighting(SurfaceGeometry geo) {
    mediump vec3 result = vec3(0.0);
    for (int i = 0; i < uLightCounts.x; i++) {
        result += calcPointLight(i, geo);
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
//   m[1] rgb: color * intensity       a: atlasShadowIndex
//   m[2] xyz: object-space direction, w: 0
//   m[3] x:   cos(innerAngle),        y: cos(outerAngle)
uniform highp mat4 uSpotLights[8];

#ifdef ENABLE_SPOT_SHADOW
uniform highp sampler2DShadow SamplerSpotShadowmap; // GL_TEXTURE4
uniform highp vec2 SpotShadowmapTexelSize;          // 1.0 / spot shadowmap resolution (pre-computed on CPU)
uniform highp mat4 uMatrixSpotShadowAtlas[8];       // Bias * Projection * View * Model for each spotlight slot
uniform highp float SpotShadowNormalBias;           // normal bias for spotlight shadow acne

// Spot shadow with atlas: project biased fragment position using spotlight i's shadow matrix
mediump float ComputeSpotShadow(int i, SurfaceGeometry geo) {
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

mediump vec3 calcSpotLight(int i, SurfaceGeometry geo) {
    mat4 m = uSpotLights[i];
    vec4 posRangeSq = m[0]; // xyz: position, w: range²
    float radiusSq  = posRangeSq.w;

    vec3 lightPos  = posRangeSq.xyz;
    vec3 L = (lightPos - geo.Position) * uInvObjScale;
    float distSq = dot(L, L);

    // Early exit: outside radius
    if (distSq >= radiusSq) {
        return vec3(0.0);
    }

    float invDist = inversesqrt(max(distSq, 0.0001));
    vec3 Lnorm = L * invDist;

    // cone attenuation
    vec4 dir4       = m[2]; // xyz: spotlight direction (object space, pre-normalised)
    float cosTheta  = dot(-Lnorm, dir4.xyz); // dir4.xyz already normalised on CPU
    vec4 coneAngles = m[3]; // x: cos(inner), y: cos(outer)

    // Early exit: outside cone
    if (cosTheta <= coneAngles.y) {
        return vec3(0.0);
    }

    mediump float NdotL = dot(geo.Normal, Lnorm);
    if (NdotL <= 0.0) {
        return vec3(0.0);
    }

    // light factor
    mediump float atten = calcAttenuation(distSq, radiusSq);
    mediump float spot  = calcConeAttenuation(cosTheta, coneAngles.x, coneAngles.y);
    mediump float lightFactor = atten * spot * NdotL; 
    if (lightFactor <= 0.0) {
        return vec3(0.0);
    }

    mediump vec4 colorIntensity = m[1]; // rgb: color * intensity
    mediump vec3 radiance = colorIntensity.rgb * lightFactor;

#ifdef ENABLE_SPOT_SHADOW
    mediump int shadowIndex = int(colorIntensity.a); // a: atlasShadowIndex
    if (shadowIndex <= 7) {
        radiance *= ComputeSpotShadow(shadowIndex, geo);
    }
#endif

    return radiance;
}

// Spot lights lighting in object space
mediump vec3 CalculateSpotLighting(SurfaceGeometry geo) {
    mediump vec3 result = vec3(0.0);
    for (int i = 0; i < uLightCounts.y; i++) {
        result += calcSpotLight(i, geo);
    }
    return result;
}

#endif // ENABLE_SPOT_LIGHTS

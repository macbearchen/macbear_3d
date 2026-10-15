#version 300 es
// Per-pixel lighting shader ES3 //////////
// must append to "TexturedLighting.es3.frag"

uniform mediump vec3 uLightDir; // parallel light
uniform mediump vec3 uLightColor;  // light color RGB

#ifdef ENABLE_PBR
uniform mediump vec4 uParamPBR; // x: Metallic, y: Roughness, z: Mipmap-level, w: Occlusion-strength

// Trowbridge-Reitz GGX
mediump float DistributionGGX(mediump vec3 N, mediump vec3 H, mediump float roughness) {
    mediump float a = roughness * roughness;
    mediump float a2 = a * a;
    mediump float NdotH = max(dot(N, H), 0.0);
    mediump float NdotH2 = NdotH * NdotH;

    mediump float num = a2;
    mediump float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.14159265359 * denom * denom;

    return num / denom;
}

// Smith's method (Schlick-GGX)
mediump float GeometrySchlickGGX(mediump float NdotV, mediump float roughness) {
    mediump float r = (roughness + 1.0);
    mediump float k = (r * r) / 8.0;

    mediump float num = NdotV;
    mediump float denom = NdotV * (1.0 - k) + k;

    return num / denom;
}

mediump float GeometrySmith(mediump float NdotV, mediump float NdotL, mediump float roughness) {
    mediump float ggx2 = GeometrySchlickGGX(NdotV, roughness);
    mediump float ggx1 = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

// Schlick's approximation
mediump vec3 fresnelSchlick(mediump float cosTheta, mediump vec3 F0) {
    return F0 + (1.0 - F0) * pow5(clamp(1.0 - cosTheta, 0.0, 1.0));
}

// ---- Shared PBR helpers ----

// F0 reflectance at normal incidence, blended toward albedo by metallic.
mediump vec3 ComputeF0(mediump vec3 baseColor, mediump float metallic) {
    return mix(vec3(0.04), baseColor, metallic);
}

#endif // ENABLE_PBR

#ifdef ENABLE_IBL
uniform mediump mat4 Model;
uniform samplerCube SamplerEnvironment;

// kS: specular weight for this IBL sample (the Fresnel term computed by the caller).
mediump vec3 ApplyIBL(mediump vec3 ambientDiffuse, mediump vec3 N, mediump vec3 V, mediump vec3 kS, mediump float roughness, mediump float metallic) {
    // IBL: Sample environment map for ambient reflection
    mediump vec3 reflectDir = reflect(-V, N);
    reflectDir = normalize(mat3(Model) * reflectDir).xyz;
    // Swizzle to match skybox-cubemap orientation (rotXNeg90)
    mediump vec3 sampleDir;
    sampleDir.x = -reflectDir.x;
    sampleDir.y = reflectDir.z;
    sampleDir.z = -reflectDir.y;

    // Roughness based Mip-mapping for Specular IBL (ES3 native textureLod)
    mediump float mipLevel = roughness * uParamPBR.z; // Roughness * MaxMipLevel
    mediump vec3 envColor = textureLod(SamplerEnvironment, sampleDir, mipLevel).rgb;
    // envColor = pow(envColor, vec3(2.2));

    // PBR weighting for ambient:
    // kD (diffuse) reduction for energy conservation
    mediump vec3 kD = (vec3(1.0) - kS) * (1.0 - metallic);

    // IBL Specular reflection: attenuated by roughness
    mediump vec3 iblSpecular = envColor * kS;

    return kD * ambientDiffuse + iblSpecular;
}
#endif // ENABLE_IBL

// ShadeLitFactor: single-pass shadow blend — ambient computed once, direct light scaled by litFactor.
mediump vec4 ShadeLitFactor(mediump vec4 diffuse, SurfaceGeometry geo, mediump float litFactor)
{
    mediump vec3 resultColor;
    mediump vec3 N = geo.Normal;
    mediump vec3 L = uLightDir;     // parallel light source
    mediump vec3 V = safe_normalize(uEyePos - geo.Position); // View direction from surface to eye
    mediump vec3 H = safe_normalize(V + L);
    mediump float NdotL = max(dot(N, L), 0.0);

#ifdef ENABLE_PBR
    mediump float NdotV = max(dot(N, V), 0.0);

    // Sample ORM texture: R = Occlusion, G = Roughness, B = Metallic
    mediump vec3 orm = texture(SamplerORM, TextureCoordOut).rgb;
    mediump float occlusion = clamp(1.0 + uParamPBR.w * (orm.r - 1.0), 0.0, 1.0);
    mediump float roughness = clamp(orm.g * uParamPBR.y, 0.04, 1.0);
    mediump float metallic = clamp(orm.b * uParamPBR.x, 0.0, 1.0);

    // PBR calculations should be done in linear space
    // Note: diffuse.rgb is already linear when diffuse/baseColor texture is sampled via GL_SRGB8_ALPHA8.
    mediump vec3 baseColor = diffuse.rgb * uLightColor;
    mediump vec3 F0 = ComputeF0(baseColor, metallic);

    // Reflectance equation
    mediump float NDF = DistributionGGX(N, H, roughness);
    mediump float G = GeometrySmith(NdotV, NdotL, roughness);
    mediump vec3 F = fresnelSchlick(max(dot(H, V), 0.0), F0);
    mediump vec3 kD = (vec3(1.0) - F) * (1.0 - metallic);

    mediump vec3 numerator = NDF * G * F;
    mediump float denominator = 4.0 * NdotV * NdotL + 0.0001;
    mediump vec3 specular = numerator / denominator;

    mediump vec3 ambient = (ColorAmbient * diffuse.rgb) * occlusion;

    #ifdef ENABLE_IBL
    mediump vec3 Fibl = fresnelSchlick(NdotV, F0);
    ambient = ApplyIBL(ambient, N, V, Fibl, roughness, metallic);
    #endif // ENABLE_IBL

    // ambient is unaffected by shadow; only direct light is attenuated by litFactor
    resultColor = ambient + (kD * baseColor + specular) * NdotL * litFactor;
#else // ENABLE_PBR
    mediump float df = NdotL * litFactor;
    mediump float NdotH = max(0.0, dot(N, H));
    mediump float sf = pow(NdotH, ColorSpecular.w) * litFactor;

	#ifdef ENABLE_CARTOON
	// segment: 0___0.1___0.3___0.7___1
	// cartoon:   0    0.3  0.7    1
	df = dot(step(vec3(0.1,0.3,0.7), vec3(df)), vec3(0.3, 0.4, 0.3));
	sf = step(0.5, sf);
	#endif // ENABLE_CARTOON

	// lit = ambient + diffuse + specular * shininess
    resultColor = diffuse.rgb * (ColorAmbient + vec3(df)) + ColorSpecular.rgb * sf;
#endif // ENABLE_PBR

	return vec4(resultColor, diffuse.a);
}

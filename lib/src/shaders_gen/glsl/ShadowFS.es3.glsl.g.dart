// Generated file – do not edit.
// ignore: constant_identifier_names
const String ShadowFS_glsl = r"""
#version 300 es
// Shadow frag-shader: ES3 //////////
// must append after fragment shader

// -------------------------
// Shadow with PCF
// -------------------------
uniform highp sampler2DShadow SamplerShadowmap; // GL_TEXTURE3
uniform highp vec2 ShadowmapTexelSize;			// 1.0 / shadowmap resolution (pre-computed on CPU)
uniform highp float ShadowNormalBias;			// normal bias (for shadow acne)

// Shared PCF kernel — parameterized so both directional and spot shadows can reuse it.
// uv:   projected texture coordinates (already in [0,1])
// refZ: reference depth with depth bias already applied
mediump float ComputeShadowPCF(highp sampler2DShadow sampler, highp vec2 texelSize, highp vec2 uv, highp float refZ)
{
    mediump float factorLit = 0.0;

////////// PCF //////////
#ifdef ENABLE_PCF
    mediump vec4 factor;	// shadow factor by hardware-PCF
    factor.x = texture(sampler, vec3(uv + vec2( 1.0,  0.5) * texelSize, refZ));
    factor.y = texture(sampler, vec3(uv + vec2(-1.0, -0.5) * texelSize, refZ));
    factor.z = texture(sampler, vec3(uv + vec2(-0.5,  1.0) * texelSize, refZ));
    factor.w = texture(sampler, vec3(uv + vec2( 0.5, -1.0) * texelSize, refZ));
    factorLit = dot(factor, vec4(1.0)) / 4.0;
#elif defined(ENABLE_PCF_3x3) || defined(ENABLE_PCF_5x5)
    #if defined(ENABLE_PCF_5x5)
        const float range = 2.0;
        const float samples = 25.0;
    #else
        const float range = 1.0;
        const float samples = 9.0;
    #endif
    for (float y = -range; y <= range; y += 1.0) {
        for (float x = -range; x <= range; x += 1.0) {
            factorLit += texture(sampler, vec3(uv + vec2(x, y) * texelSize, refZ));
        }
    }
    factorLit /= samples;
#else // no PCF
    factorLit = texture(sampler, vec3(uv, refZ));
#endif // ENABLE_PCF
    return factorLit;
}

#if defined(ENABLE_SHADOW_CSM_VS) && defined(ENABLE_SHADOW_CSM_FS)
    #error "ENABLE_SHADOW_CSM_VS and ENABLE_SHADOW_CSM_FS are mutually exclusive - choose one"
#endif

// -------------------------
// Shadow Map or CSM
// -------------------------
#ifdef ENABLE_SHADOW_MAP
in highp vec4 LightcoordShadowmap;  // light-space coordinate-system
#endif // ENABLE_SHADOW_MAP

#ifdef ENABLE_SHADOW_CSM_VS
in highp vec4 LightcoordCSM[4];     // light-space coordinate-system
uniform highp vec4 DepthCSM;        // depth clip-plane
#endif // ENABLE_SHADOW_CSM_VS

#ifdef ENABLE_SHADOW_CSM_FS
uniform mat4 MatrixCSM[4];          // light-space matrix for each cascade
uniform highp vec4 DepthCSM;        // depth clip-plane
#endif // ENABLE_SHADOW_CSM_FS

// compute litFactor with shadow
#ifdef ENABLE_SHADOW_CSM_FS
mediump float ComputeShadowLitFactor(SurfaceGeometry geo)
#else
mediump float ComputeShadowLitFactor()
#endif
{
#ifdef ENABLE_SHADOW_MAP
	highp vec4 lightCoord = LightcoordShadowmap;
#endif // ENABLE_SHADOW_MAP

#ifdef ENABLE_SHADOW_CSM_VS
	highp vec4 lightCoord = LightcoordCSM[3];
	if (gl_FragCoord.z < DepthCSM.x) {
		lightCoord = LightcoordCSM[0];
	}
	else if (gl_FragCoord.z < DepthCSM.y) {
		lightCoord = LightcoordCSM[1];
	}
	else if (gl_FragCoord.z < DepthCSM.z) {
		lightCoord = LightcoordCSM[2];
	}
#endif // ENABLE_SHADOW_CSM_VS

#ifdef ENABLE_SHADOW_CSM_FS
	vec4 biasedPos = vec4(geo.Position + geo.Normal * ShadowNormalBias, 1.0);
	highp vec4 lightCoord;
	if (gl_FragCoord.z < DepthCSM.x) {
		lightCoord = MatrixCSM[0] * biasedPos;
	}
	else if (gl_FragCoord.z < DepthCSM.y) {
		lightCoord = MatrixCSM[1] * biasedPos;
	}
	else if (gl_FragCoord.z < DepthCSM.z) {
		lightCoord = MatrixCSM[2] * biasedPos;
	}
	else {
		lightCoord = MatrixCSM[3] * biasedPos;
	}
#endif // ENABLE_SHADOW_CSM_FS

	if (lightCoord.s < 0.0 || lightCoord.t < 0.0 || lightCoord.s > 1.0 || lightCoord.t > 1.0) {
		return 1.0; // lit area
	} else {
		return ComputeShadowPCF(SamplerShadowmap, ShadowmapTexelSize, lightCoord.st, lightCoord.z - 0.0005);
	}
}

mediump vec4 ShadeLit(mediump vec4 texDiffuse, SurfaceGeometry geo);
mediump vec4 ShadeUnlit(mediump vec4 texDiffuse, SurfaceGeometry geo);
// ShadeLitFactor: computes ambient once; only direct light is scaled by litFactor.
// Avoids the shadow-edge halo that mix(ShadeUnlit, ShadeLit) causes when ambient/IBL
// is evaluated differently on both sides of the penumbra blend.
mediump vec4 ShadeLitFactor(mediump vec4 texDiffuse, SurfaceGeometry geo, mediump float litFactor);

// shade lit/unlit to mix with shadow factor
mediump vec4 ShadeLitShadowMix(mediump vec4 color, SurfaceGeometry geo) {
#ifdef ENABLE_SHADOW_CSM_FS
	mediump float litFactor = ComputeShadowLitFactor(geo);
#else
	mediump float litFactor = ComputeShadowLitFactor();
#endif // ENABLE_SHADOW_CSM_FS

	// Use ShadeLitFactor instead of mix(ShadeUnlit, ShadeLit):
	// ambient/IBL is evaluated once and unaffected by shadow,
	// only the direct light contribution is attenuated by litFactor.
	// This eliminates the bright halo ring at shadow edges on ORM/PBR materials.
	return ShadeLitFactor(color, geo, litFactor);
}

""";

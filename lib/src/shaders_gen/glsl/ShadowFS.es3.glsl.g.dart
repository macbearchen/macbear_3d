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
lowp float ComputeShadowPCF(highp sampler2DShadow sampler, highp vec2 texelSize, highp vec2 uv, highp float refZ)
{
    lowp float factorLit = 0.0;

////////// PCF //////////
#ifdef ENABLE_PCF
    lowp vec4 factor;	// shadow factor by hardware-PCF
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
lowp float ComputeShadowLitFactor(in vec3 fragPos, in vec3 N)
#else
lowp float ComputeShadowLitFactor()
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
	vec4 biasedPos = vec4(fragPos + N * ShadowNormalBias, 1.0);
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

// shade lit/unlit to mix with shadow factor
lowp vec4 ShadeLitShadowMix(in lowp vec4 color) {
#ifdef ENABLE_SHADOW_CSM_FS
	#ifdef ENABLE_PIXEL_LIGHTING
		lowp float litFactor = ComputeShadowLitFactor(ObjectspaceV, normalize(ObjectspaceN));
	#else
		lowp float litFactor = ComputeShadowLitFactor(ObjectspaceV, vec3(0.0));
	#endif // ENABLE_PIXEL_LIGHTING
#else
	lowp float litFactor = ComputeShadowLitFactor();
#endif // ENABLE_SHADOW_CSM_FS

	lowp vec4 result;
	if (litFactor >= 1.0) {
		result = ShadeLit(color);
	} else if (litFactor <= 0.0) {
		result = ShadeUnlit(color);
	} else {
		result = mix(ShadeUnlit(color), ShadeLit(color), litFactor);
	}
	return result;
}

""";

#version 300 es
// PCF (Percentage-Closer Filtering) frag-shader: ES3 //////////
// append to end of TexturedLighting.es3.frag shader

uniform highp sampler2DShadow SamplerShadowmap;	// GL_TEXTURE1
uniform highp vec2 ShadowmapSize;		// shadowmap resolution
uniform highp float NormalBias;			// normal bias (for shadow acne)

// external functions
lowp vec4 ComputePixelLit(in lowp vec4 texDiffuse);
lowp vec4 ComputePixelUnlit(in lowp vec4 texDiffuse);

void ComputeShadowPCF(inout lowp vec4 texResult, in highp vec4 lightCoord)
{
    highp float refZ = lightCoord.z - 0.0005; // apply bias

////////// PCF //////////
#ifdef ENABLE_PCF
    highp vec2 texelSize = vec2(1.0) / ShadowmapSize;
    lowp vec4 factor;	// shadow factor by hardware-PCF
    factor.x = texture(SamplerShadowmap, vec3(lightCoord.st + vec2( 1.0,  0.5) * texelSize, refZ));
    factor.y = texture(SamplerShadowmap, vec3(lightCoord.st + vec2(-1.0, -0.5) * texelSize, refZ));
    factor.z = texture(SamplerShadowmap, vec3(lightCoord.st + vec2(-0.5,  1.0) * texelSize, refZ));
    factor.w = texture(SamplerShadowmap, vec3(lightCoord.st + vec2( 0.5, -1.0) * texelSize, refZ));
    
    lowp float factorLit = dot(factor, vec4(1.0)) / 4.0;
    texResult = mix(ComputePixelUnlit(texResult), ComputePixelLit(texResult), factorLit);
#elif defined(ENABLE_PCF_3x3) || defined(ENABLE_PCF_5x5)
    highp vec2 texelSize = vec2(1.0) / ShadowmapSize;
    lowp float factorLit = 0.0;
    #if defined(ENABLE_PCF_5x5)
        const float range = 2.0;
        const float samples = 25.0;
    #else
        const float range = 1.0;
        const float samples = 9.0;
    #endif

    for (float y = -range; y <= range; y += 1.0) {
        for (float x = -range; x <= range; x += 1.0) {
            factorLit += texture(SamplerShadowmap, vec3(lightCoord.st + vec2(x, y) * texelSize, refZ));
        }
    }
    factorLit /= samples;
    texResult = mix(ComputePixelUnlit(texResult), ComputePixelLit(texResult), factorLit);
#else
    lowp float factorLit = texture(SamplerShadowmap, vec3(lightCoord.st, refZ));
    texResult = mix(ComputePixelUnlit(texResult), ComputePixelLit(texResult), factorLit);
#endif // ENABLE_PCF
}
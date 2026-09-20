#version 300 es
precision mediump float;
// Simple frag-shader ES3 //////////

in mediump vec2 TextureCoordOut;
in lowp vec4 DestinationColor;

#ifdef ENABLE_EXTERNAL_OES
uniform samplerExternalOES SamplerDiffuse;   // GL_TEXTURE0
#else
uniform sampler2D SamplerDiffuse;   // GL_TEXTURE0
#endif

#ifdef ENABLE_ALPHA_TEST
uniform lowp float uAlphaCutoff;	// alpha cutoff
#endif // ENABLE_ALPHA_TEST

out vec4 fragColor;

void main(void)
{
    lowp vec4 texResult = texture(SamplerDiffuse, TextureCoordOut);	// tex-lookup
#ifdef ENABLE_ALPHA_TEST
	if (texResult.a < uAlphaCutoff)
		discard;
#endif // ENABLE_ALPHA_TEST

#ifdef ENABLE_TEXTURE0_BGRA	// iOS, macOS: CVPixelBuffer is BGRA, not RGBA
	texResult = texResult.bgra;
#endif // ENABLE_TEXTURE0_BGRA

    fragColor = texResult * DestinationColor;
}

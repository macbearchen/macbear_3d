#version 300 es
precision mediump float;
// TexturedLighting frag-shader: ES3 //////////

#ifdef ENABLE_PIXEL_LIGHTING
// per pixel lighting: "glsl/Pixel.es3.frag" must append on this shader
lowp vec4 ShadeLit(in lowp vec4 texDiffuse);
lowp vec4 ShadeUnlit(in lowp vec4 texDiffuse);

#else
// per vertex lighting
uniform lowp vec3 ColorAmbient;		// ambient RGB
in lowp vec4 SpecularOut;	// separate specular added
in lowp vec4 DestinationColor;

// no pre-multiply alpha
// lit result by per-vertex
lowp vec4 ShadeLit(in lowp vec4 texDiffuse)
{
	lowp vec4 result = texDiffuse * DestinationColor;
	result.rgb += SpecularOut.rgb;
	return result;
}

lowp vec4 ShadeUnlit(in lowp vec4 texDiffuse)
{
	// unlit = ambient 
	return texDiffuse * vec4(ColorAmbient, DestinationColor.a);
}
#endif // ENABLE_PIXEL_LIGHTING

in mediump vec2 TextureCoordOut;
uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0

out vec4 fragColor;

void main(void)
{
	lowp vec4 texResult = texture(SamplerDiffuse, TextureCoordOut);	// tex-lookup
#ifdef ENABLE_TEXTURE0_BGRA	// iOS, macOS: CVPixelBuffer is BGRA, not RGBA
	texResult = texResult.bgra;
#endif // ENABLE_TEXTURE0_BGRA

#ifdef ENABLE_ALPHA_TEST
	if (texResult.a < 0.5)
		discard;
#endif // ENABLE_ALPHA_TEST
	
	////////// shadow map //////////
#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM)
	texResult = ShadeLitWithShadow(texResult);
#else // no shadow
    texResult = ShadeLit(texResult);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM

#ifdef ENABLE_FOG
	texResult = ApplyFog(texResult);
#endif // ENABLE_FOG

	fragColor = texResult;
}

// Generated file – do not edit.
// ignore: constant_identifier_names
const String TexturedLighting_frag = r"""
#version 300 es

// TexturedLighting frag-shader: ES3 //////////
#ifndef ENABLE_PIXEL_LIGHTING

precision mediump float;

uniform lowp vec3 ColorAmbient;		// ambient RGB 

in lowp vec4 SpecularOut;	// separate specular added
in lowp vec4 DestinationColor;

// no pre-multiply alpha
// lit result by per-vertex
lowp vec4 ComputePixelLit(in lowp vec4 texDiffuse)
{
	lowp vec4 result = texDiffuse * DestinationColor;
	result.rgb += SpecularOut.rgb;
	return result;
}

lowp vec4 ComputePixelUnlit(in lowp vec4 texDiffuse)
{
	// unlit = ambient 
	return texDiffuse * vec4(ColorAmbient, DestinationColor.a);
}
#endif // ENABLE_PIXEL_LIGHTING

in mediump vec2 TextureCoordOut;
uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0

#ifdef ENABLE_FOG
in mediump float FogDensity;		// fog density [0,1]
uniform lowp vec3 FogColor;
#endif // ENABLE_FOG

#ifdef ENABLE_SHADOW_MAP
in highp vec4 LightcoordShadowmap;	// light-space coordinate-system
#endif // ENABLE_SHADOW_MAP

#ifdef ENABLE_SHADOW_CSM
in highp vec4 LightcoordCSM[4];	// light-space coordinate-system
uniform highp vec4 DepthCSM;			// depth clip-plane
#endif // ENABLE_SHADOW_CSM

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM)
void ComputeShadowPCF(inout lowp vec4 texResult, in highp vec4 lightCoord);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM

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
	#ifdef ENABLE_SHADOW_CSM
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
		else {
			lightCoord = LightcoordCSM[3];
		}
	#else
		highp vec4 lightCoord = LightcoordShadowmap;
	#endif // ENABLE_SHADOW_CSM
	
	if (lightCoord.s < 0.0 || lightCoord.t < 0.0 || lightCoord.s > 1.0 || lightCoord.t > 1.0) {
		texResult = ComputePixelLit(texResult);		// lit area
	} else {
		ComputeShadowPCF(texResult, lightCoord); 	// shadow area with PCF
	}

#else
    texResult = ComputePixelLit(texResult);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM

#ifdef ENABLE_FOG
	// Perform depth test and clamp the values
	lowp float fFogBlend = clamp(FogDensity + 1.0 - texResult.a, 0.0, 1.0);
	texResult.rgb = mix(texResult.rgb, FogColor, fFogBlend); 
#endif // ENABLE_FOG

	fragColor = texResult;
}

""";

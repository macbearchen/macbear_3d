// Generated file – do not edit.
// ignore: constant_identifier_names
const String TexturedLighting_frag = r"""
#version 300 es
precision mediump float;
// TexturedLighting frag-shader: ES3 //////////

uniform lowp vec3 ColorAmbient;		// ambient RGB

in mediump vec2 TextureCoordOut;
uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0

#ifdef ENABLE_NORMALMAP
uniform sampler2D SamplerNormal;	// GL_TEXTURE1
uniform mediump float uNormalScale;	// normal scale factor
in mediump vec4 vTangent;           // xyz=tangent, w=handedness (from VS)
#endif // ENABLE_NORMALMAP

#ifdef ENABLE_PBR
uniform sampler2D SamplerORM;		// GL_TEXTURE5: AmbientOcclusion(R), Roughness(G), Metallic(B)
#endif // ENABLE_PBR

uniform mediump vec3 uEyePos;
uniform mediump vec3 uInvObjScale;

in highp vec3 ObjectspaceV;		// Object space Vertex

#ifdef ENABLE_PIXEL_LIGHTING
in mediump vec3 ObjectspaceN;	// Object space Normal

// per pixel lighting: "glsl/Pixel.es3.frag" must append on this shader
lowp vec4 ShadeLit(in lowp vec4 texDiffuse, in SurfaceGeometry geo);
lowp vec4 ShadeUnlit(in lowp vec4 texDiffuse, in SurfaceGeometry geo);

#else
// per vertex lighting
in lowp vec4 SpecularOut;	// separate specular added
in lowp vec4 DestinationColor;

// no pre-multiply alpha
// lit result by per-vertex
lowp vec4 ShadeLit(in lowp vec4 texDiffuse, in SurfaceGeometry geo)
{
	lowp vec4 result = texDiffuse * DestinationColor;
	result.rgb += SpecularOut.rgb;
	return result;
}

lowp vec4 ShadeUnlit(in lowp vec4 texDiffuse, in SurfaceGeometry geo)
{
	// unlit = ambient 
	return texDiffuse * vec4(ColorAmbient, DestinationColor.a);
}
#endif // ENABLE_PIXEL_LIGHTING

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM_VS) || defined(ENABLE_SHADOW_CSM_FS)
lowp vec4 ShadeLitShadowMix(in lowp vec4 color, in SurfaceGeometry geo);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM_VS or ENABLE_SHADOW_CSM_FS

#ifdef ENABLE_FOG
lowp vec4 ApplyFog(in lowp vec4 texResult);
#endif // ENABLE_FOG

#ifdef ENABLE_ALPHA_TEST
uniform lowp float uAlphaCutoff;	// alpha cutoff
#endif // ENABLE_ALPHA_TEST

out vec4 fragColor;

void main(void)
{
	lowp vec4 texResult = texture(SamplerDiffuse, TextureCoordOut);	// tex-lookup
#ifdef ENABLE_TEXTURE0_BGRA	// iOS, macOS: CVPixelBuffer is BGRA, not RGBA
	texResult = texResult.bgra;
#endif // ENABLE_TEXTURE0_BGRA

#ifdef ENABLE_ALPHA_TEST
	if (texResult.a < uAlphaCutoff)
		discard;
#endif // ENABLE_ALPHA_TEST

#ifdef ENABLE_PIXEL_LIGHTING
	mediump vec3 N = safe_normalize(ObjectspaceN);
	N = gl_FrontFacing ? N : -N;

#ifdef ENABLE_NORMALMAP
	// TBN from vertex tangent (xyz=tangent, w=handedness)
	mediump vec3 T = safe_normalize(vTangent.xyz);
	mediump float handedness = gl_FrontFacing ? vTangent.w : -vTangent.w;
	mediump vec3 B = safe_normalize(cross(N, T) * handedness);
	mediump mat3 tbn = mat3(T, B, N);

	mediump vec3 mapN = texture(SamplerNormal, TextureCoordOut).xyz * 2.0 - 1.0;
	mapN.z = gl_FrontFacing ? mapN.z : -mapN.z;
	mapN.xy *= uNormalScale;
	N = safe_normalize(tbn * mapN);
#endif // ENABLE_NORMALMAP

#else
	mediump vec3 N = vec3(0.0, 0.0, 1.0);
#endif // ENABLE_PIXEL_LIGHTING
	SurfaceGeometry geo = SurfaceGeometry(ObjectspaceV, N);

	////////// shadow map //////////
#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM_VS) || defined(ENABLE_SHADOW_CSM_FS)
	texResult = ShadeLitShadowMix(texResult, geo);
#else // no shadow
    texResult = ShadeLit(texResult, geo);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM_VS or ENABLE_SHADOW_CSM_FS

#ifdef ENABLE_FOG
	texResult = ApplyFog(texResult);
#endif // ENABLE_FOG

	fragColor = texResult;
}

""";

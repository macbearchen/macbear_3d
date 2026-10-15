// Generated file – do not edit.
// ignore: constant_identifier_names
const String TexturedLighting_frag = r"""
#version 300 es
precision mediump float;
// TexturedLighting frag-shader: ES3 //////////

uniform mediump vec3 ColorAmbient;	// ambient RGB
// material color: diffuse and specular
uniform mediump vec4 ColorDiffuse;	// diffuse RGBA
uniform mediump vec4 ColorSpecular;	// specular RGB, w: shininess

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
in mediump vec3 ObjectspaceN;	// Object space Normal

#ifdef ENABLE_PIXEL_LIGHTING

// per pixel lighting: "glsl/Pixel.es3.frag" must append on this shader
mediump vec4 ShadeLitFactor(mediump vec4 diffuse, SurfaceGeometry geo, mediump float litFactor);

#else
// per-vertex lighting
in mediump vec4 SpecularOut;	// separate specular added
in mediump vec4 DestinationColor;

// no pre-multiply alpha
// lit result by per-vertex
mediump vec4 ShadeLitFactor(mediump vec4 diffuse, SurfaceGeometry geo, mediump float litFactor)
{
	// unlit = ambient only
	mediump vec4 ambient = diffuse * vec4(ColorAmbient, DestinationColor.a);
	// lit = diffuse + specular
	mediump vec4 resultLit = diffuse * DestinationColor;
	resultLit.rgb += SpecularOut.rgb;
	return mix(ambient, resultLit, litFactor);
}
#endif // ENABLE_PIXEL_LIGHTING

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM_VS) || defined(ENABLE_SHADOW_CSM_FS)
mediump vec4 ShadeLitShadowMix(mediump vec4 color, SurfaceGeometry geo);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM_VS or ENABLE_SHADOW_CSM_FS

#ifdef ENABLE_POINT_LIGHTS  // multi-point-lights
mediump vec3 CalculatePointLighting(SurfaceGeometry geo);
#endif // ENABLE_POINT_LIGHTS

#ifdef ENABLE_SPOT_LIGHTS   // spot lights
mediump vec3 CalculateSpotLighting(SurfaceGeometry geo);
#endif // ENABLE_SPOT_LIGHTS

#ifdef ENABLE_FOG
mediump vec4 ApplyFog(mediump vec4 texResult);
#endif // ENABLE_FOG

#ifdef ENABLE_ALPHA_TEST
uniform lowp float uAlphaCutoff;	// alpha cutoff
#endif // ENABLE_ALPHA_TEST

out vec4 fragColor;

void main(void)
{
	mediump vec4 texResult = texture(SamplerDiffuse, TextureCoordOut);	// tex-lookup
#ifdef ENABLE_TEXTURE0_BGRA	// iOS, macOS: CVPixelBuffer is BGRA, not RGBA
	texResult = texResult.bgra;
#endif // ENABLE_TEXTURE0_BGRA

#ifdef ENABLE_ALPHA_TEST
	if (texResult.a < uAlphaCutoff)
		discard;
#endif // ENABLE_ALPHA_TEST

	mediump vec3 N = safe_normalize(ObjectspaceN);
	N = gl_FrontFacing ? N : -N;

#ifdef ENABLE_NORMALMAP
	// TBN from vertex tangent (xyz=tangent, w=handedness)
	mediump vec3 T = safe_normalize(vTangent.xyz);
	mediump float handedness = gl_FrontFacing ? vTangent.w : -vTangent.w;
	mediump vec3 B = safe_normalize(cross(N, T) * handedness);

	T = gl_FrontFacing ? T : -T;
	B = gl_FrontFacing ? B : -B;

	mediump mat3 tbn = mat3(T, B, N);

	mediump vec3 mapN = texture(SamplerNormal, TextureCoordOut).xyz * 2.0 - 1.0;
	mapN.xy *= uNormalScale;
	N = safe_normalize(tbn * mapN);
#endif // ENABLE_NORMALMAP

	SurfaceGeometry geo = SurfaceGeometry(ObjectspaceV, N);
    mediump vec4 diffuse = ColorDiffuse * texResult;

	////////// shadow map //////////
#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM_VS) || defined(ENABLE_SHADOW_CSM_FS)
	texResult = ShadeLitShadowMix(diffuse, geo);
#else // no shadow
    texResult = ShadeLitFactor(diffuse, geo, 1.0);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM_VS or ENABLE_SHADOW_CSM_FS

#ifdef ENABLE_POINT_LIGHTS
    texResult.rgb += CalculatePointLighting(geo) * diffuse.rgb;
#endif

#ifdef ENABLE_SPOT_LIGHTS
    texResult.rgb += CalculateSpotLighting(geo) * diffuse.rgb;
#endif

#ifdef ENABLE_FOG
	texResult = ApplyFog(texResult);
#endif // ENABLE_FOG

	fragColor = texResult;
}

""";

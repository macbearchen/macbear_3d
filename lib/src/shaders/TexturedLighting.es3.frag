#version 300 es
precision mediump float;
// TexturedLighting frag-shader: ES3 //////////

uniform mediump vec3 ColorAmbient;	// ambient RGB

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
mediump vec4 ShadeLit(mediump vec4 texDiffuse, SurfaceGeometry geo);
mediump vec4 ShadeLitFactor(mediump vec4 texDiffuse, SurfaceGeometry geo, mediump float litFactor);
mediump vec4 ShadeUnlit(mediump vec4 texDiffuse, SurfaceGeometry geo);

#else
// per-vertex lighting
in mediump vec4 SpecularOut;	// separate specular added
in mediump vec4 DestinationColor;

// no pre-multiply alpha
// lit result by per-vertex
mediump vec4 ShadeLit(mediump vec4 texDiffuse, SurfaceGeometry geo)
{
	mediump vec4 result = texDiffuse * DestinationColor;
	result.rgb += SpecularOut.rgb;
	return result;
}

mediump vec4 ShadeLitFactor(mediump vec4 texDiffuse, SurfaceGeometry geo, mediump float litFactor)
{
	mediump vec4 litColor = ShadeLit(texDiffuse, geo);
	mediump vec4 unlitColor = ShadeUnlit(texDiffuse, geo);
	return mix(unlitColor, litColor, litFactor);
}

mediump vec4 ShadeUnlit(mediump vec4 texDiffuse, SurfaceGeometry geo)
{
	// unlit = ambient 
	return texDiffuse * vec4(ColorAmbient, DestinationColor.a);
}
#endif // ENABLE_PIXEL_LIGHTING

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM_VS) || defined(ENABLE_SHADOW_CSM_FS)
mediump vec4 ShadeLitShadowMix(mediump vec4 color, SurfaceGeometry geo);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM_VS or ENABLE_SHADOW_CSM_FS

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

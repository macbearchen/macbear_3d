#version 300 es
precision mediump float;
// Water frag-shader ES3 //////////

// water distortion (noise effect)
in mediump vec2 BumpCoord0;
in mediump vec2 BumpCoord1;
in highp vec3 eyeToObj;		// interpolate from vert to frag: must be highp in iPad3 
in highp float eyeToObjDist;
in highp vec3 ObjectspaceV;    // Object space Vertex
uniform mediump vec3 uInvObjScale;

uniform mediump float WaveDistortion;

uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0: reflection as diffuse
uniform sampler2D NormalTex;		// GL_TEXTURE1: normalmap (Normal map uses z-axis major)
uniform sampler2D RefractionTex;	// GL_TEXTURE2: refraction
uniform mediump vec4 CameraViewport; // xyzw for (x,y,width,height)

// uniform lowp vec4 uColor;

// blend reflection and refraction
mediump vec4 BlendReflectionRefraction(mediump vec3 vAccumulatedNormal, mediump vec3 eyeToObjNormal)
{
	// Calculate the Fresnel term to determine amount of reflection for each fragment
	mediump float fresnel = clamp(dot(eyeToObjNormal, vAccumulatedNormal), 0.0, 1.0);
	fresnel = 1.0 - fresnel;
	fresnel = pow5(fresnel);
	fresnel = (0.9 * fresnel) + 0.1;	// R(0)-1 = ~0.98 , R(0)= ~0.02
	
	// Calculate the tex coords of the fragment (using it's position on the screen), normal map is z-axis major.
	mediump vec2 vTexCoord = (gl_FragCoord.xy - CameraViewport.xy) / CameraViewport.zw;

	// Divide by eyeToObjDist to scale down the distortion
	// of fragments based on their distance from the camera 
	vTexCoord.xy -= vAccumulatedNormal.xy * (WaveDistortion / eyeToObjDist);

	// reflection, refraction
	mediump vec4 ReflectionColor = texture(SamplerDiffuse, vTexCoord);
	mediump vec4 RefractionColor = texture(RefractionTex, vTexCoord);
	// Blend reflection and refraction
	mediump vec4 result;
	result = mix(RefractionColor, ReflectionColor, fresnel);
//	result = mix(ReflectionColor, RefractionColor, 0.4);	// Constant mix
	// result = RefractionColor;			// ReflectionColor, RefractionColor only
	return result;
}

#ifdef ENABLE_WATER_SPECULAR
// tangent-space by light
uniform mediump vec3 uLightDir; // parallel light
uniform mediump vec3 uLightColor;  // light color RGB
#endif // ENABLE_WATER_SPECULAR

// ShadeLitFactor for water: blend reflection/refraction + optional specular scaled by litFactor.
mediump vec4 ShadeLitFactor(mediump vec4 diffuse, SurfaceGeometry geo, mediump float litFactor)
{
	mediump vec3 eyeToObjNormal = eyeToObj / eyeToObjDist; // as normalize: increase little FPS, but seem lost precision

	// blend reflection and refraction
	mediump vec4 resultColor;
	resultColor = BlendReflectionRefraction(geo.Normal, eyeToObjNormal);

	if (litFactor < 0.0) {
		return resultColor;
	}
	
#ifdef ENABLE_WATER_SPECULAR
	// specular part:
	mediump vec3 H = normalize(eyeToObjNormal + uLightDir);
	highp float sf = clamp(dot(H, geo.Normal), 0.0, 1.0);
	sf = pow(sf, 120.0);
	
	resultColor = vec4(resultColor.rgb + uLightColor * (sf * litFactor), 1.0);
	// resultColor = vec4(uLightColor, 1.0); // for debug
#endif // ENABLE_WATER_SPECULAR

	return resultColor;
}

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM_VS) || defined(ENABLE_SHADOW_CSM_FS)
mediump vec4 ShadeLitShadowMix(mediump vec4 color, SurfaceGeometry geo);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM_VS or ENABLE_SHADOW_CSM_FS

#ifdef ENABLE_POINT_LIGHTS	// multi-point-lights
mediump vec3 CalculatePointLighting(SurfaceGeometry geo);
#endif // ENABLE_POINT_LIGHTS

#ifdef ENABLE_SPOT_LIGHTS   // spot lights
mediump vec3 CalculateSpotLighting(SurfaceGeometry geo);
#endif // ENABLE_SPOT_LIGHTS

#ifdef ENABLE_FOG
mediump vec4 ApplyFog(mediump vec4 texResult);
#endif // ENABLE_FOG

// output color
out vec4 fragColor;

void main(void)
{
	// When distortion is enabled, use the normal map to calculate perturbation
	// Same as * 2.0 - 1.0
	mediump vec3 vAccumulatedNormal = texture(NormalTex, BumpCoord0).rgb + texture(NormalTex, BumpCoord1).rgb - 1.0;
	SurfaceGeometry geo = SurfaceGeometry(ObjectspaceV, safe_normalize(vAccumulatedNormal));
	mediump vec4 resultColor = vec4(1.0, 0.0, 0.0, 1.0);

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM_VS) || defined(ENABLE_SHADOW_CSM_FS)
	// ObjectspaceV, vAccumulatedNormal
	resultColor = ShadeLitShadowMix(resultColor, geo);
#else
	resultColor = ShadeLitFactor(resultColor, geo, 1.0);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM_VS or ENABLE_SHADOW_CSM_FS

#ifdef ENABLE_POINT_LIGHTS
	resultColor.rgb += CalculatePointLighting(geo);
#endif

#ifdef ENABLE_SPOT_LIGHTS
    resultColor.rgb += CalculateSpotLighting(geo);
#endif

#ifdef ENABLE_FOG
	resultColor = ApplyFog(resultColor);
#endif // ENABLE_FOG

	fragColor = resultColor;
}

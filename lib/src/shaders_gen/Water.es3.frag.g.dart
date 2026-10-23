// Generated file – do not edit.
// ignore: constant_identifier_names
const String Water_frag = r"""
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
uniform sampler2D SceneDepthTex;	// GL_TEXTURE7: scene depth texture
uniform mediump vec4 CameraViewport; // xyzw for (x,y,width,height)
uniform mediump vec2 CameraNearFar;  // xy: nearClip, farClip
uniform mediump vec4 BumpTranslateScale0;	// xy: translate, zw: scale
uniform mediump vec4 FoamParams;     // x: foamDistance, y: foamFalloff, z: foamIntensity, w: edgeDistortionDistance
uniform mediump vec4 FoamColor;      // rgba: foam color

// Linearize standard 0~1 depth buffer value to eye-space distance
highp float LinearizeDepth(highp float depth, highp float near, highp float far)
{
	return (near * far) / (far - depth * (far - near));
}

// blend reflection and refraction, with shoreline foam and edge distortion reduction
mediump vec4 BlendReflectionRefraction(mediump vec3 vAccumulatedNormal, mediump vec3 eyeToObjNormal)
{
	// Calculate the Fresnel term to determine amount of reflection for each fragment
	mediump float fresnel = clamp(dot(eyeToObjNormal, vAccumulatedNormal), 0.0, 1.0);
	fresnel = 1.0 - fresnel;
	fresnel = pow5(fresnel);
	fresnel = (0.9 * fresnel) + 0.1;	// R(0)-1 = ~0.98 , R(0)= ~0.02
	
	// Calculate the screen-space tex coords of the fragment
	mediump vec2 screenUV = (gl_FragCoord.xy - CameraViewport.xy) / CameraViewport.zw;

	// Scene depth & water depth comparison for edge effects
	highp float near = CameraNearFar.x;
	highp float far = CameraNearFar.y;
	highp float sceneDepthRaw = texture(SceneDepthTex, screenUV).r;
	highp float sceneEyeZ = LinearizeDepth(sceneDepthRaw, near, far);
	highp float waterEyeZ = LinearizeDepth(gl_FragCoord.z, near, far);
	highp float waterDepth = max(0.0, sceneEyeZ - waterEyeZ);

	// Reduce distortion near edges / shorelines to prevent edge bleeding / ghosting
	highp float edgeDistLimit = max(FoamParams.w, 0.001);
	mediump float distortionFade = clamp(waterDepth / edgeDistLimit, 0.0, 1.0);

	// Distort refraction UV
	mediump vec2 vTexCoord = screenUV;
	vTexCoord.xy -= vAccumulatedNormal.xy * (WaveDistortion / eyeToObjDist) * distortionFade;

	// Sample reflection and refraction
	mediump vec4 ReflectionColor = texture(SamplerDiffuse, vTexCoord);
	mediump vec4 RefractionColor = texture(RefractionTex, vTexCoord);
	// Blend reflection and refraction
	mediump vec4 result = mix(RefractionColor, ReflectionColor, fresnel);

	// Shoreline edge foam & dynamic wave wash/splash
	highp float foamDist = FoamParams.x;
	if (foamDist > 0.0) {
		// Base depth gradient (1.0 at waterline, 0.0 at foamDist)
		highp float shoreFactor = clamp(1.0 - (waterDepth / foamDist), 0.0, 1.0);

		// Time progression derived strictly from uniform offset animation
		highp float animTime = (BumpTranslateScale0.x - BumpTranslateScale0.y) * 35.0;

		// 1. Static shoreline contact foam (right at the edge)
		highp float edgeContact = pow(shoreFactor, 2.5);

		// 2. Incoming wave surge: waves travel toward waterDepth = 0
		highp float wavePhase = waterDepth * (6.0 / max(foamDist, 0.5)) - animTime;
		// Sharp wave crest that steepens as it reaches shore
		highp float waveCrest = clamp(sin(wavePhase) * 1.5 - 0.3, 0.0, 1.0);
		// Waves break and expand in shallow water
		highp float waveWash = waveCrest * shoreFactor;

		// 3. Normal map perturbation for bubbly, ragged edges
		highp float wavePerturb = (vAccumulatedNormal.x + vAccumulatedNormal.y) * 0.25;

		// Combine contact foam + incoming surging waves
		highp float foamShape = max(edgeContact, waveWash) + wavePerturb;
		highp float foamAmount = clamp(foamShape, 0.0, 1.0);
		foamAmount = pow(foamAmount, FoamParams.y) * FoamParams.z;

		// Blend foam over water
		result = mix(result, FoamColor, foamAmount);
	}

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

""";

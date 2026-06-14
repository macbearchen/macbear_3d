#version 300 es
// Water frag-shader ES3 //////////

// water distortion (noise effect)
in mediump vec2 BumpCoord0;
in mediump vec2 BumpCoord1;
in highp vec3 WaterToEye;		// interpolate from vert to frag: must be highp in iPad3 
in highp float WaterToEyeLength;

uniform mediump float	WaveDistortion;

uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0: diffuse as reflection
uniform sampler2D NormalTex;		// GL_TEXTURE1: normalmap (Normal map uses z-axis major)
uniform sampler2D RefractionTex;	// GL_TEXTURE2: refraction
uniform mediump vec4 CameraViewport; // xyzw for (x,y,width,height)

// shade lit/unlit functions
lowp vec4 ShadeLit(in lowp vec4 texDiffuse)
{
	return texDiffuse;
}

lowp vec4 ShadeUnlit(in lowp vec4 texDiffuse)
{
	return texDiffuse * 0.5;
}

// output color
out vec4 fragColor;

// blend reflection and refraction
lowp vec4 BlendReflectionRefraction(in lowp vec3 vAccumulatedNormal, in lowp vec3 WaterToEyeNormal)
{
	// Calculate the Fresnel term to determine amount of reflection for each fragment
	mediump float fAirWaterFresnel = clamp(dot(WaterToEyeNormal,vAccumulatedNormal),0.0,1.0);
	fAirWaterFresnel = 1.0 - fAirWaterFresnel;
	fAirWaterFresnel = pow(fAirWaterFresnel, 5.0);
	fAirWaterFresnel = (0.9 * fAirWaterFresnel) + 0.1;	// R(0)-1 = ~0.98 , R(0)= ~0.02
	lowp float fTemp = fAirWaterFresnel;
	
	// Calculate the tex coords of the fragment (using it's position on the screen), normal map is z-axis major.
	mediump vec2 vTexCoord = (gl_FragCoord.xy - CameraViewport.xy) / CameraViewport.zw;

	// Divide by WaterToEyeLength to scale down the distortion
	// of fragments based on their distance from the camera 
//	vTexCoord.xy -= vAccumulatedNormal.xy * (WaveDistortion / WaterToEyeLength);

	// reflection, refraction
	lowp vec4 ReflectionColor = texture(SamplerDiffuse, vTexCoord);
	lowp vec4 RefractionColor = texture(RefractionTex, vTexCoord);
	// Blend reflection and refraction
	lowp vec4 result;
	result = mix(RefractionColor, ReflectionColor, fTemp);
//	result = mix(ReflectionColor, RefractionColor, 0.4);	// Constant mix
//	result = RefractionColor;			// ReflectionColor, RefractionColor only
	return result;
}

#ifdef ENABLE_WATER_SPECULAR
// tangent-space by light
uniform lowp vec3 LightDiffuse;		// diffuse of light
uniform mediump vec3 LightPosition;	// parallel light
#endif // ENABLE_WATER_SPECULAR
		  
void main(void)
{
	// Use normalisation cube map instead of normalize() - See section 3.3.1 of white paper for more info
	// Macbear note: no need at new hardward
	// - See section 6.5 of PowerVR SGX.OpenGL ES 2.0 Application Development Recommendations
	lowp vec3 WaterToEyeNormal = normalize(WaterToEye);
//	lowp vec3 WaterToEyeNormal = WaterToEye / WaterToEyeLength;		// as normalize: increase little FPS, but seem lost precision
	
	// When distortion is enabled, use the normal map to calculate perturbation
	// Same as * 2.0 - 1.0
	lowp vec3 vAccumulatedNormal = texture(NormalTex, BumpCoord0).rgb + texture(NormalTex, BumpCoord1).rgb - 1.0;

	// blend reflection and refraction
	lowp vec4 resultColor;
	resultColor = BlendReflectionRefraction(vAccumulatedNormal, WaterToEyeNormal);

#ifdef ENABLE_WATER_SPECULAR
	// specular part:
	mediump vec3 WaterHalf = normalize(WaterToEyeNormal + LightPosition);
	mediump float sf = max(0.0, dot(WaterHalf, vAccumulatedNormal));
//	mediump float sf = clamp(dot(WaterHalf, vAccumulatedNormal), 0.0, 1.0);
	sf = pow(sf, 120.0);
	
	lowp float fTemp = sf;
//	resultColor = vec4(LightDiffuse * fTemp, 1.0);		// for debug purpose
	resultColor = vec4(resultColor.rgb + LightDiffuse * fTemp, 1.0);
#endif // ENABLE_WATER_SPECULAR

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM)
	resultColor = ShadeLitWithShadow(resultColor);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM

#ifdef ENABLE_FOG
	resultColor = ApplyFog(resultColor);
#endif // ENABLE_FOG

	fragColor = resultColor;
}

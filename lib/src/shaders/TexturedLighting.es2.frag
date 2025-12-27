// TexturedLighting frag-shader: fog //////////

// color combined by light and material
uniform lowp vec3 ColorAmbient;		// ambient RGB 
uniform lowp vec4 ColorDiffuse;		// diffuse RGBA
uniform lowp vec3 ColorSpecular;	// specular RGB
uniform mediump float Shininess;	// shiness of material

#ifdef ENABLE_PIXEL_LIGHTING
uniform mediump vec3 LightPosition;		// parallel light
varying mediump vec3 ObjectspaceN;
varying mediump vec3 ObjectspaceH;		// LightVector + EyeVector
#else
varying lowp vec4 SpecularOut;	// separate specular added
#endif // ENABLE_PIXEL_LIGHTING

varying lowp vec4 DestinationColor;
varying mediump vec2 TextureCoordOut;

uniform sampler2D SamplerDiffuse;		// GL_TEXTURE0

#ifdef ENABLE_FOG
varying mediump float FogDensity;		// fog density [0,1]
uniform lowp vec3 FogColor;
#endif // ENABLE_FOG

#ifdef ENABLE_SHADOW_MAP
varying highp vec4 LightcoordShadowmap;	// light-space coordinate-system
#endif // ENABLE_SHADOW_MAP

#ifdef ENABLE_SHADOW_CSM
varying highp vec4 LightcoordCSM[4];	// light-space coordinate-system
uniform highp vec4 DepthCSM;			// depth clip-plane
#endif // ENABLE_SHADOW_CSM

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM)
uniform highp sampler2D SamplerShadowmap;		// GL_TEXTURE1
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM

// lit result by per-vertex/per-pixel
lowp vec4 ComputePixelLit(in lowp vec4 texDiffuse)
{
	lowp vec4 litResult;
#ifdef ENABLE_PIXEL_LIGHTING
    mediump vec3 L = LightPosition;		// parallel light source
    mediump vec3 N = normalize(ObjectspaceN);
    mediump vec3 H = normalize(ObjectspaceH);
    
    lowp float df = max(0.0, dot(N, L));
    lowp float sf = pow(max(0.0, dot(N, H)), Shininess);
	
	#ifdef ENABLE_CARTOON
	// segment: 0___0.1___0.3___0.7___1
	// cartoon:   0    0.3  0.7    1
	df = dot(step(vec3(0.1,0.3,0.7), vec3(df)), vec3(0.3, 0.4, 0.3));
	sf = step(0.5, sf);
	#endif // ENABLE_CARTOON
	
	// lit = ambient + diffuse + specular * shininess
	litResult = texDiffuse * vec4((ColorAmbient + ColorDiffuse.rgb * df), ColorDiffuse.a);
	litResult.rgb += (ColorSpecular * (sf * litResult.a));
#else
	litResult = texDiffuse * DestinationColor;
	litResult.rgb += (SpecularOut.rgb * litResult.a);
#endif // ENABLE_PIXEL_LIGHTING
	return litResult;
}

void main(void)
{
	lowp vec4 texResult = texture2D(SamplerDiffuse, TextureCoordOut);	// tex-lookup
#ifdef ENABLE_ALPHA_TEST
	if (texResult.a < 0.5)
		discard;
#endif // ENABLE_ALPHA_TEST
	
	////////// shadow map //////////
#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM)
	#ifdef ENABLE_SHADOW_CSM
	lowp vec4 cascade = vec4(greaterThanEqual(gl_FragCoord.zzzz, DepthCSM));
	lowp int altas = int(dot(cascade, lowp vec4(1.0,1.0,1.0,0.0)));	// altas-index of shadowmap
	highp vec4 LightcoordShadowmap = LightcoordCSM[altas];
	#endif // ENABLE_SHADOW_CSM
	
	if (LightcoordShadowmap.s < 0.0 || LightcoordShadowmap.t < 0.0 || LightcoordShadowmap.s > 1.0 || LightcoordShadowmap.t > 1.0) {
		texResult = ComputePixelLit(texResult);					// lit-area
	}
	else {

	////////// PCF //////////
	#ifdef ENABLE_PCF
	highp vec4 depthPCF;	// depth-shadow by PCF
	depthPCF.x = texture2D(SamplerShadowmap, LightcoordShadowmap.st + vec2( 0.0009, 0.0003)).r;
	depthPCF.y = texture2D(SamplerShadowmap, LightcoordShadowmap.st + vec2(-0.0009,-0.0003)).r;
	depthPCF.z = texture2D(SamplerShadowmap, LightcoordShadowmap.st + vec2(-0.0003, 0.0009)).r;
	depthPCF.w = texture2D(SamplerShadowmap, LightcoordShadowmap.st + vec2( 0.0003,-0.0009)).r;
	
	depthPCF = step(vec4(LightcoordShadowmap.z), depthPCF);
	lowp float factorLit = dot(depthPCF, depthPCF) / 4.0;
	
	lowp vec4 areaShadow = texResult * vec4(ColorAmbient, 1.0);	// shadow-area
	texResult = mix(areaShadow, ComputePixelLit(texResult), factorLit);
	#else

	highp float depthShadow;
	depthShadow = texture2D(SamplerShadowmap, LightcoordShadowmap.st).r;
	//	depthShadow = texture2DProj(SamplerShadowmap, LightcoordShadowmap).r;	// palallel-projection, so w = 1 
	if (depthShadow < LightcoordShadowmap.z)
		texResult = texResult * vec4(ColorAmbient, 1.0);		// shadow-area
	else
		texResult = ComputePixelLit(texResult);					// lit-area
	#endif // ENABLE_PCF

	// texResult = vec4(vec3(LightcoordShadowmap.z), 1.0);	// debug shadowmap
	}
#else
    texResult = ComputePixelLit(texResult);
#endif // ENABLE_SHADOW_MAP or ENABLE_SHADOW_CSM

#ifdef ENABLE_FOG
	// Perform depth test and clamp the values
	lowp float fFogBlend = clamp(FogDensity + 1.0 - texResult.a, 0.0, 1.0);
	texResult.rgb = mix(texResult.rgb, FogColor, fFogBlend); 
#endif // ENABLE_FOG

	gl_FragColor = texResult;
}

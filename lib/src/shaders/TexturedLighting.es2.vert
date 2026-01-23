// NOTICE 1: WITH_NORMAL must be defined before "Skinning.es2.vert"
// NOTICE 2: "Skinning.es2.vert" must be added before this file

// Lighting function //////////
attribute mediump vec2 inTexCoord;
//attribute mediump vec4 inColor;		// as diffuse-ambient material
uniform lowp vec4 uColor;

#ifdef ENABLE_PIXEL_LIGHTING
varying mediump vec3 ObjectspaceH;	// LightPos + EyePos
varying mediump vec3 ObjectspaceN;
#else
// color combined by light and material
uniform lowp vec4 ColorDiffuse;		// diffuse RGBA
uniform lowp vec3 ColorSpecular;	// specular RGB
uniform mediump float Shininess;	// shiness of material
varying lowp vec4 SpecularOut;		// separate specular added
#endif // ENABLE_PIXEL_LIGHTING
uniform lowp vec3 ColorAmbient;		// ambient RGB 

// object space
uniform mediump vec3 EyePosition;	// eye as camera origin
uniform mediump vec3 LightPosition;	// parallel light

// shader variable: from vert to frag
varying lowp vec4 DestinationColor;
varying mediump vec2 TextureCoordOut;

// eye-space for camera-viewer
//uniform mat4 Projection;
//uniform mat4 Modelview;
uniform mat4 ModelviewProjection;

#ifdef ENABLE_SHADOW_MAP
// light-space matrix for shadowmap in texture-space
uniform mat4 MatrixShadowmap;
varying highp vec4 LightcoordShadowmap;	// light-space coordinate-system
#endif // ENABLE_SHADOW_MAP

#ifdef ENABLE_SHADOW_CSM
// light-space matrix for shadowmap in texture-space
uniform mat4 MatrixCSM[4];
varying highp vec4 LightcoordCSM[4];	// light-space coordinate-system
#endif // ENABLE_SHADOW_CSM

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM)
uniform highp float NormalBias;			// normal bias (for shadow acne)
#endif

#ifdef ENABLE_FOG
// fog depth on water
uniform mediump vec4 FogPlane;		// fog-plane in object-space
uniform mediump float FogDepth;		// max depth of fog
varying mediump float FogDensity;	// fog density [0,1]
#endif // ENABLE_FOG

void main(void)
{
	highp vec4 objVert = vec4(inVertex, 1.0);
	mediump vec3 objNormal = inNormal;
	
	if (BoneCount > 0)
	{
		ComputeSkinningVertex(objVert, objNormal);
	}

	// object-space: normal, light-position, eye-position
	mediump vec3 L = LightPosition;							// parallel light source
	mediump vec3 E = normalize(EyePosition - objVert.xyz);	// vertex to eye
#ifdef ENABLE_PIXEL_LIGHTING
	ObjectspaceH = normalize(L + E);
	ObjectspaceN = objNormal;
#else
#ifdef BLINN_PHONG_SPECULAR
	mediump vec3 H = normalize(L + E);
	mediump float sf = max(0.0, dot(objNormal, H));
#else // regular Phong shader
	mediump vec3 R = reflect(-L, objNormal);	// 2N(N.L) - L
	mediump float sf = max(0.0, dot(R, E));
#endif
	sf = pow(sf, Shininess);
	// lighting = ambient + diffuse + specular * shininess
	SpecularOut = vec4(ColorSpecular * sf, 0.0);
	
	mediump float df = max(0.0, dot(objNormal, L));
	DestinationColor = vec4(ColorAmbient + ColorDiffuse.rgb * df, ColorDiffuse.a);
#endif // ENABLE_PIXEL_LIGHTING
	
	
#ifdef ENABLE_SHADOW_MAP
	vec3 biasedVertMap = objVert.xyz + objNormal * NormalBias;
	LightcoordShadowmap = MatrixShadowmap * vec4(biasedVertMap, 1.0);
#endif // ENABLE_SHADOW_MAP
	
#ifdef ENABLE_SHADOW_CSM
	// cascaded shadowmap
	vec3 biasedVertCSM = objVert.xyz + objNormal * NormalBias;
	LightcoordCSM[0] = MatrixCSM[0] * vec4(biasedVertCSM, 1.0);
	LightcoordCSM[1] = MatrixCSM[1] * vec4(biasedVertCSM, 1.0);
	LightcoordCSM[2] = MatrixCSM[2] * vec4(biasedVertCSM, 1.0);
	LightcoordCSM[3] = MatrixCSM[3] * vec4(biasedVertCSM, 1.0);
#endif // ENABLE_SHADOW_CSM

#ifdef ENABLE_FOG
	// for fog density
	mediump float DepthInFog = dot(FogPlane.xyz, objVert.xyz) + FogPlane.w;
	FogDensity = DepthInFog / FogDepth;
#endif // ENABLE_FOG
	
	TextureCoordOut = inTexCoord;
    gl_Position = ModelviewProjection * objVert;	// pre-compute Projection * Modelview
}

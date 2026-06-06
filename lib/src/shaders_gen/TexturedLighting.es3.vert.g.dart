// Generated file – do not edit.
// ignore: constant_identifier_names
const String TexturedLighting_vert = r"""
#version 300 es
// TexturedLighting vert-shader: ES3 //////////
#ifndef ENABLE_SKINNING
layout(location = 0) in highp vec3 inVertex;
layout(location = 2) in mediump vec3 inNormal;
#endif // ENABLE_SKINNING

layout(location = 3) in mediump vec2 inTexCoord;
uniform lowp vec4 uColor;

#ifdef ENABLE_PIXEL_LIGHTING
out mediump vec3 ObjectspaceH;
#ifdef ENABLE_PBR
out mediump vec3 ObjectspaceV;
#endif // ENABLE_PBR
out mediump vec3 ObjectspaceN;
#else
uniform lowp vec4 ColorDiffuse;
uniform mediump vec4 ColorSpecular;
out lowp vec4 SpecularOut;
#endif // ENABLE_PIXEL_LIGHTING

uniform lowp vec3 ColorAmbient;
uniform mediump vec3 EyePosition;
uniform mediump vec3 LightPosition;

out lowp vec4 DestinationColor;
out mediump vec2 TextureCoordOut;

uniform mat4 ModelviewProjection;

#ifdef ENABLE_SHADOW_MAP
uniform mat4 MatrixShadowmap;
out highp vec4 LightcoordShadowmap;
#endif

#ifdef ENABLE_SHADOW_CSM
uniform mat4 MatrixCSM[4];
out highp vec4 LightcoordCSM[4];
#endif

#if defined(ENABLE_SHADOW_MAP) || defined(ENABLE_SHADOW_CSM)
uniform highp float NormalBias;
#endif

#ifdef ENABLE_FOG
uniform mediump vec4 FogPlane;
uniform mediump float FogDepth;
out mediump float FogDensity;
#endif

void main(void)
{
    highp vec4 objVert = vec4(inVertex, 1.0);
    mediump vec3 objNormal = inNormal;
    
#ifdef ENABLE_SKINNING
    if (BoneCount > 0)
    {
        ComputeSkinningVertex(objVert, objNormal);
    }
#endif

    mediump vec3 L = LightPosition;
    mediump vec3 E = normalize(EyePosition - objVert.xyz);
#ifdef ENABLE_PIXEL_LIGHTING
    ObjectspaceH = normalize(L + E);
    #ifdef ENABLE_PBR
    ObjectspaceV = E;
    #endif
    ObjectspaceN = objNormal;
#else
    #ifdef BLINN_PHONG_SPECULAR
    mediump vec3 H = normalize(L + E);
    mediump float sf = max(0.0, dot(objNormal, H));
    #else
    mediump vec3 R = reflect(-L, objNormal);
    mediump float sf = max(0.0, dot(R, E));
    #endif

    sf = pow(sf, ColorSpecular.w);
    SpecularOut = vec4(ColorSpecular.rgb * sf, 0.0);
    
    mediump float df = max(0.0, dot(objNormal, L));
    DestinationColor = vec4(ColorAmbient + ColorDiffuse.rgb * df, ColorDiffuse.a);
#endif
    
#ifdef ENABLE_SHADOW_MAP
    vec3 biasedVertMap = objVert.xyz + objNormal * NormalBias;
    LightcoordShadowmap = MatrixShadowmap * vec4(biasedVertMap, 1.0);
#endif
    
#ifdef ENABLE_SHADOW_CSM
    vec3 biasedVertCSM = objVert.xyz + objNormal * NormalBias;
    LightcoordCSM[0] = MatrixCSM[0] * vec4(biasedVertCSM, 1.0);
    LightcoordCSM[1] = MatrixCSM[1] * vec4(biasedVertCSM, 1.0);
    LightcoordCSM[2] = MatrixCSM[2] * vec4(biasedVertCSM, 1.0);
    LightcoordCSM[3] = MatrixCSM[3] * vec4(biasedVertCSM, 1.0);
#endif

#ifdef ENABLE_FOG
    mediump float DepthInFog = dot(FogPlane.xyz, objVert.xyz) + FogPlane.w;
    FogDensity = clamp(DepthInFog / FogDepth, 0.0, 1.0);
#endif
    
    TextureCoordOut = inTexCoord;
    gl_Position = ModelviewProjection * objVert;
}

""";

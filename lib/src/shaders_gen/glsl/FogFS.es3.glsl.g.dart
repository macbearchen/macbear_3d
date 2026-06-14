// Generated file – do not edit.
// ignore: constant_identifier_names
const String FogFS_glsl = r"""
#version 300 es
// Fog frag-shader: ES3 //////////
// must insert before fragment shader

#define ENABLE_FOG

in highp vec3 fogVert;
uniform mediump vec4 FogPlane;
uniform mediump float FogDepth;
uniform lowp vec3 FogColor;

lowp vec4 ApplyFog(in lowp vec4 texResult)
{
    mediump float DepthInFog = dot(FogPlane.xyz, fogVert) + FogPlane.w;
    mediump float FogDensity = clamp(DepthInFog / FogDepth, 0.0, 1.0);
    lowp float fFogBlend = clamp(FogDensity + 1.0 - texResult.a, 0.0, 1.0);
    return vec4(mix(texResult.rgb, FogColor, fFogBlend), texResult.a);
}

""";

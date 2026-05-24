#version 300 es
// Water vert-shader ES3 //////////

layout(location = 0) in highp vec3 inVertex;		// vertex-data
layout(location = 1) in lowp vec4 inColor;		// for water-color as fog in water
layout(location = 3) in mediump vec2 inTexCoord;

// eye-space for camera-viewer
uniform highp mat4 ModelviewProjection;
// object-space (same as world-space here)
uniform mediump vec3 EyePosition;	// eye as camera origin

uniform mediump vec4 BumpTranslateScale0;	// xy: translate, zw: scale
uniform mediump vec4 BumpTranslateScale1;	// xy: translate, zw: scale

// tangent-space by plane
uniform lowp vec3 AxisTangent;		// as X-axis
uniform lowp vec3 AxisBinormal;		// as Y-axis
uniform lowp vec3 AxisNormal;		// as Z-axis

// shader variable: from vert to frag
out mediump vec2 BumpCoord0;
out mediump vec2 BumpCoord1;
out highp vec3 WaterToEye;		// interpolate from vert to frag: must be highp in iPad3 
out highp float WaterToEyeLength;

out lowp vec4 DestinationColor;

void main(void)
{
	DestinationColor = inColor;
    gl_Position = ModelviewProjection * vec4(inVertex, 1.0);	// pre-compute Projection * Modelview
	
	// Scale and translate texture coordinates used to sample the normal map - section 2.2 of white paper
	BumpCoord0 = (inTexCoord * BumpTranslateScale0.zw) + BumpTranslateScale0.xy;
	BumpCoord1 = (inTexCoord * BumpTranslateScale1.zw) + BumpTranslateScale1.xy;
	
	// The water to eye vector is used to calculate the Fresnel term
	// and to fade out perturbations based on distance from the viewer
	WaterToEye = EyePosition - inVertex;
	WaterToEyeLength = length(WaterToEye);
	
	// tangent-space
	WaterToEye = vec3(dot(AxisTangent, WaterToEye), dot(AxisBinormal, WaterToEye), dot(AxisNormal, WaterToEye));
}

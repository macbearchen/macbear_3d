// Generated file – do not edit.
// ignore: constant_identifier_names
const String SimpleLighting_es2_vert = r"""
// Simple-lighting vert-shader //////////
attribute vec3 inVertex;
//attribute vec4 inColor;		// as diffuse-ambient material
attribute vec3 inNormal;
//attribute vec2 inTexCoord;

uniform lowp vec4 uColor;

// eye-space for camera-viewer
//uniform mat4 Projection;
//uniform mat4 Modelview;
uniform mat4 ModelviewProjection;

// color combined by light and material
uniform lowp vec3 ColorAmbient;		// ambient RGB 
uniform lowp vec4 ColorDiffuse;		// diffuse RGBA
uniform lowp vec3 ColorSpecular;	// specular RGB
uniform mediump float Shininess;	// shiness of material

// object-space
uniform vec3 EyePosition;		// eye as camera origin
uniform vec3 LightPosition;		// parallel light

// shader variable: from vert to frag
varying lowp vec4 DestinationColor;

void main(void) {
	highp vec4 objVert = vec4(inVertex, 1.0);
	mediump vec3 objNormal = inNormal;

	// object-space: normal, light-position, eye-position
	vec3 N = objNormal;
	vec3 L = LightPosition;							// parallel light source
	vec3 E = normalize(EyePosition - objVert.xyz);	// vertex to eye
	vec3 H = normalize(L + E);

	float df = max(0.0, dot(N, L));
	float sf = max(0.0, dot(N, H));
	sf = pow(sf, Shininess);

	lowp vec3 AmbientDiffuseSpecular = (ColorAmbient + ColorDiffuse.rgb * df) + ColorSpecular * sf;

	DestinationColor = vec4(AmbientDiffuseSpecular, uColor.a);
	// DestinationColor = vec4((N + vec3(1.0) / 2.0), uColor.a);		// normal
	// DestinationColor = uColor;

//	gl_Position = Projection * Modelview * objVert;	// pre-compute Projection * Modelview
	gl_Position = ModelviewProjection * objVert;	// pre-compute Projection * Modelview
}

""";

// Skybox vert-shader: reflect //////////
attribute highp vec3 inVertex;
//attribute mediump vec4 inColor;		// as diffuse-ambient material
		  
#ifdef ENABLE_REFLECT_SKYBOX
// object space
attribute mediump vec3 inNormal;
uniform mediump vec3 EyePosition;			// eye as camera origin
uniform highp mat4 Modelview;				// model-matrix (by object)
#endif // ENABLE_REFLECT_SKYBOX

uniform lowp vec4 uColor;
varying lowp vec4 DestinationColor;
varying mediump vec3 TexCoordDirOut;
// eye-space for camera-viewer
uniform highp mat4 ModelviewProjection;

void main(void)
{
#ifdef ENABLE_REFLECT_SKYBOX
	mediump vec3 eyeDir = normalize(inVertex - EyePosition);	// by object-space
	mediump vec3 reflectDir = reflect(eyeDir, inNormal);		// by object-space
	reflectDir = mat3(Modelview) * reflectDir;					// by world-space
	
	TexCoordDirOut.xz = reflectDir.xy;
	TexCoordDirOut.y = -reflectDir.z;
#else
	TexCoordDirOut = inVertex;
#endif // ENABLE_REFLECT_SKYBOX
	
    DestinationColor = uColor;
    gl_Position = ModelviewProjection * vec4(inVertex, 1.0);	// pre-compute Projection * Modelview
}

// Generated file – do not edit.
// ignore: constant_identifier_names
const String Skybox_es2_frag = r"""
// Skybox frag-shader //////////
varying lowp vec4 DestinationColor;
varying mediump vec3 TexCoordDirOut;
uniform samplerCube SamplerDiffuse;	// GL_TEXTURE0 by skybox-cubemap
	  
void main(void)
{
    gl_FragColor = textureCube(SamplerDiffuse, TexCoordDirOut) * DestinationColor;
}


""";

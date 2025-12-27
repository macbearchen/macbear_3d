// Generated file – do not edit.
// ignore: constant_identifier_names
const String EarthNight_es2_frag = r"""
// Simple frag-shader //////////
varying mediump vec2 TextureCoordOut;
varying lowp vec4 DestinationColor;

uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0

void main(void)
{
	gl_FragColor = texture2D(SamplerDiffuse, TextureCoordOut) * DestinationColor;
//    gl_FragColor = DestinationColor;
}

""";

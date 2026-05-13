#version 300 es
// Mirror frag-shader //////////
precision mediump float;
in lowp vec4 DestinationColor;

uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0
uniform mediump vec4 CameraViewport;		// xyzw for (x,y,width,height)
out vec4 fragColor;

void main(void)
{
	mediump vec2 vTexCoord = (gl_FragCoord.xy - CameraViewport.xy) / CameraViewport.zw;
    fragColor = texture(SamplerDiffuse, vTexCoord) * DestinationColor;
}

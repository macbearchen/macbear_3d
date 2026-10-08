// Generated file – do not edit.
// ignore: constant_identifier_names
const String Fullscreen_frag = r"""
#version 300 es
precision mediump float;
// Fullscreen frag-shader //////////

in vec2 vUV;

uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0

out vec4 fragColor;

void main() {
    vec4 linearColor = texture(SamplerDiffuse, vUV);
    linearColor.rgb = pow(max(linearColor.rgb, 0.0), vec3(1.0 / 2.2));
    fragColor = linearColor;
}
""";

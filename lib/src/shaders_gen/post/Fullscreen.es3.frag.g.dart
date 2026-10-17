// Generated file – do not edit.
// ignore: constant_identifier_names
const String Fullscreen_frag = r"""
#version 300 es
precision mediump float;
// Fullscreen frag-shader //////////

in vec2 vUV;

uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0
uniform int uTonemapMode;         // 0: None, 1: Reinhard, 2: ACES, 3: Filmic, 4: Grayscale, 5: PBR Neutral
uniform float uExposure;          // Exposure multiplier (e.g. 1.0)

out vec4 fragColor;

// Tonemap declarations (will be defined at the end of file)
vec3 applyTonemap(vec3 color);

void main() {
    vec4 baseColor = texture(SamplerDiffuse, vUV);

    // Tonemapping (HDR -> LDR)
    vec3 color = applyTonemap(baseColor.rgb);

    // Encode linear to sRGB
    color = pow(max(color, 0.0), vec3(1.0 / 2.2));

    fragColor = vec4(color, baseColor.a);
}
""";

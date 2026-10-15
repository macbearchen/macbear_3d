// Generated file – do not edit.
// ignore: constant_identifier_names
const String Composite_frag = r"""
#version 300 es
precision mediump float;
// Composite Pass frag-shader //////////

in vec2 vUV;

uniform sampler2D SamplerDiffuse; // GL_TEXTURE0: Base scene texture (linear HDR)
uniform sampler2D SamplerBloom;   // GL_TEXTURE1: Blurred Bloom texture
uniform float uBloomIntensity;    // Bloom additive strength (e.g. 0.8 ~ 1.0)

out vec4 fragColor;

void main() {
    vec4 baseColor = texture(SamplerDiffuse, vUV);
    vec3 bloomColor = texture(SamplerBloom, vUV).rgb;

    // Additive blend in linear space
    vec3 color = baseColor.rgb + bloomColor * uBloomIntensity;

    // Encode linear to sRGB
    color = pow(max(color, 0.0), vec3(1.0 / 2.2));

    fragColor = vec4(color, baseColor.a);
}

""";

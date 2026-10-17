#version 300 es
precision mediump float;
// Composite Pass frag-shader //////////

in vec2 vUV;

uniform sampler2D SamplerDiffuse; // GL_TEXTURE0: Base scene texture (linear HDR)
uniform sampler2D SamplerBloom;   // GL_TEXTURE1: Blurred Bloom texture
uniform float uBloomIntensity;    // Bloom additive strength (e.g. 0.8 ~ 1.0)
uniform int uTonemapMode;         // 0: None, 1: Reinhard, 2: ACES, 3: Filmic, 4: Grayscale, 5: PBR Neutral
uniform float uExposure;          // Exposure multiplier (e.g. 1.0)

out vec4 fragColor;

// Tonemap declarations (will be defined at the end of file)
vec3 applyTonemap(vec3 color);

void main() {
    vec4 baseColor = texture(SamplerDiffuse, vUV);
    vec3 bloomColor = texture(SamplerBloom, vUV).rgb;

    // Additive blend in linear space
    vec3 color = baseColor.rgb + bloomColor * uBloomIntensity;

    // Tonemapping (HDR -> LDR)
    color = applyTonemap(color);

    // Encode linear to sRGB
    color = pow(max(color, 0.0), vec3(1.0 / 2.2));

    fragColor = vec4(color, baseColor.a);
}

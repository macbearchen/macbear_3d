#version 300 es
precision mediump float;
// Blur separable 9-tap Gaussian frag-shader //////////

in vec2 vUV;

uniform sampler2D SamplerDiffuse; // GL_TEXTURE0
uniform vec2 uTexelSize;          // 1.0 / textureSize
uniform vec2 uDirection;          // (1.0, 0.0) horizontal or (0.0, 1.0) vertical

out vec4 fragColor;

// 9-tap Gaussian weights & offsets (linear sampling with 5 taps)
// weights: [0.227027, 0.3162162, 0.070270]
void main() {
    vec2 offset = uTexelSize * uDirection;
    vec3 result = texture(SamplerDiffuse, vUV).rgb * 0.227027;

    result += texture(SamplerDiffuse, vUV + offset * 1.3846153846).rgb * 0.3162162162;
    result += texture(SamplerDiffuse, vUV - offset * 1.3846153846).rgb * 0.3162162162;

    result += texture(SamplerDiffuse, vUV + offset * 3.2307692308).rgb * 0.0702702703;
    result += texture(SamplerDiffuse, vUV - offset * 3.2307692308).rgb * 0.0702702703;

    fragColor = vec4(result, 1.0);
}

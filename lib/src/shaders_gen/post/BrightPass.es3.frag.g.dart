// Generated file – do not edit.
// ignore: constant_identifier_names
const String BrightPass_frag = r"""
#version 300 es
precision mediump float;
// BrightPass (High-pass filter) frag-shader //////////

in vec2 vUV;

uniform sampler2D SamplerDiffuse; // GL_TEXTURE0 (HDR Scene Texture)
uniform float uThreshold;         // Luminance threshold (e.g. 1.0)
uniform float uSoftKnee;          // Soft knee range (e.g. 0.5)

out vec4 fragColor;

void main() {
    vec4 color = texture(SamplerDiffuse, vUV);
    // Relative luminance calculation for RGB (Rec. 709)
    float brightness = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

    // Soft knee thresholding
    float knee = uThreshold * uSoftKnee;
    float soft = brightness - uThreshold + knee;
    soft = clamp(soft, 0.0, 2.0 * knee);
    soft = (soft * soft) / (4.0 * max(knee, 0.0001));

    float contribution = max(soft, brightness - uThreshold);
    contribution /= max(brightness, 0.0001);

    fragColor = vec4(color.rgb * max(contribution, 0.0), color.a);
}

""";

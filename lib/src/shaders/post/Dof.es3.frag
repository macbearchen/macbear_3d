#version 300 es
precision mediump float;
// Depth of Field (DOF) frag-shader //////////

in vec2 vUV;

uniform sampler2D SamplerDiffuse; // GL_TEXTURE0: scene color (HDR/LDR)
uniform sampler2D SamplerDepth;   // GL_TEXTURE1: scene depth texture (non-linear 0~1)

uniform vec2 uCameraNearFar;      // x: near, y: far
// x: focusDistance (eye-space z), y: focusRange (sharp zone depth), z: bokehRadius (max blur radius in pixels)
uniform vec4 uDofParams;
uniform vec2 uTexelSize;          // 1.0 / resolution

out vec4 fragColor;

// Linearize standard 0~1 depth buffer value to eye-space positive distance
float linearizeDepth(float depth, float near, float far) {
    return (near * far) / (far - depth * (far - near));
}

// Compute Circle of Confusion (CoC) in range [-1.0, 1.0]
// negative: near-field blur, positive: far-field blur, 0: in-focus sharp
float computeCoC(float linearZ) {
    float focusDist = uDofParams.x;
    float focusRange = uDofParams.y;
    float diff = linearZ - focusDist;

    // Inside deadband focus range: CoC is zero
    if (abs(diff) <= focusRange) {
        return 0.0;
    }

    // Scale blur smoothly away from the focus range
    float signedDist = diff > 0.0 ? (diff - focusRange) : (diff + focusRange);
    return clamp(signedDist / max(focusDist * 0.5, 1.0), -1.0, 1.0);
}

// 16-sample Vogel disk (Fibonacci spiral) for smooth circular bokeh
const int SAMPLE_COUNT = 16;
const float GOLDEN_ANGLE = 2.39996323; // radians

void main() {
    float centerDepthRaw = texture(SamplerDepth, vUV).r;
    float centerLinearZ = linearizeDepth(centerDepthRaw, uCameraNearFar.x, uCameraNearFar.y);
    float centerCoC = computeCoC(centerLinearZ);

    float maxRadius = uDofParams.z;
    float centerRadius = abs(centerCoC) * maxRadius;

    vec4 accumColor = texture(SamplerDiffuse, vUV);
    float accumWeight = 1.0;

    // If center pixel has a non-negligible blur radius, perform disk convolution
    if (centerRadius > 0.2) {
        for (int i = 0; i < SAMPLE_COUNT; i++) {
            float fi = float(i) + 0.5;
            float r = sqrt(fi / float(SAMPLE_COUNT));
            float theta = fi * GOLDEN_ANGLE;
            vec2 offsetDir = vec2(cos(theta), sin(theta));

            vec2 sampleUV = vUV + offsetDir * (uTexelSize * centerRadius * r);
            float sampleDepthRaw = texture(SamplerDepth, sampleUV).r;
            float sampleLinearZ = linearizeDepth(sampleDepthRaw, uCameraNearFar.x, uCameraNearFar.y);
            float sampleCoC = computeCoC(sampleLinearZ);
            float sampleRadius = abs(sampleCoC) * maxRadius;

            // Bilateral-style weighting:
            // A blurred background sample shouldn't bleed onto a sharp in-focus foreground object.
            // If the sample is in the background (sampleLinearZ > centerLinearZ), scale weight by sampleRadius.
            float weight = 1.0;
            if (sampleLinearZ > centerLinearZ) {
                weight = clamp(sampleRadius / max(centerRadius, 1e-4), 0.0, 1.0);
            }

            accumColor += texture(SamplerDiffuse, sampleUV) * weight;
            accumWeight += weight;
        }
        accumColor /= accumWeight;
    }

    fragColor = accumColor;
}


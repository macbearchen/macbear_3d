// Generated file – do not edit.
// ignore: constant_identifier_names
const String FXAA_frag = r"""
#version 300 es
precision mediump float;
// FXAA 3.11 Quality frag-shader //////////

in vec2 vUV;

uniform sampler2D SamplerDiffuse; // GL_TEXTURE0: LDR tonemapped texture
uniform vec2 uTexelSize;          // vec2(1.0 / width, 1.0 / height)

out vec4 fragColor;

// Settings for FXAA Quality
#define FXAA_EDGE_THRESHOLD_MIN 0.0312  // Visible edge threshold
#define FXAA_EDGE_THRESHOLD_MAX 0.125   // Minimum edge contrast to apply FXAA
#define FXAA_SUBPIX_QUALITY 0.75        // Sub-pixel antialiasing quality (0.0 to 1.0)
#define FXAA_ITERATIONS 8               // Search steps along edge

// Relative luminance based on sRGB
float rgb2luma(vec3 rgb) {
    return dot(rgb, vec3(0.299, 0.587, 0.114));
}

void main() {
    vec4 centerColor = texture(SamplerDiffuse, vUV);
    float lumaM = rgb2luma(centerColor.rgb);

    // Sample 4 cross neighbors
    float lumaN = rgb2luma(texture(SamplerDiffuse, vUV + vec2(0.0, -uTexelSize.y)).rgb);
    float lumaS = rgb2luma(texture(SamplerDiffuse, vUV + vec2(0.0,  uTexelSize.y)).rgb);
    float lumaW = rgb2luma(texture(SamplerDiffuse, vUV + vec2(-uTexelSize.x, 0.0)).rgb);
    float lumaE = rgb2luma(texture(SamplerDiffuse, vUV + vec2( uTexelSize.x, 0.0)).rgb);

    // Local contrast
    float lumaMin = min(lumaM, min(min(lumaN, lumaS), min(lumaW, lumaE)));
    float lumaMax = max(lumaM, max(max(lumaN, lumaS), max(lumaW, lumaE)));
    float lumaRange = lumaMax - lumaMin;

    // Early exit if contrast is below edge detection threshold
    if (lumaRange < max(FXAA_EDGE_THRESHOLD_MIN, lumaMax * FXAA_EDGE_THRESHOLD_MAX)) {
        fragColor = centerColor;
        return;
    }

    // Sample 4 diagonal corners
    float lumaNW = rgb2luma(texture(SamplerDiffuse, vUV + vec2(-uTexelSize.x, -uTexelSize.y)).rgb);
    float lumaNE = rgb2luma(texture(SamplerDiffuse, vUV + vec2( uTexelSize.x, -uTexelSize.y)).rgb);
    float lumaSW = rgb2luma(texture(SamplerDiffuse, vUV + vec2(-uTexelSize.x,  uTexelSize.y)).rgb);
    float lumaSE = rgb2luma(texture(SamplerDiffuse, vUV + vec2( uTexelSize.x,  uTexelSize.y)).rgb);

    // Compute edge orientation (horizontal vs vertical)
    float edgeVert = abs((0.25 * lumaNW) + (-0.5 * lumaN) + (0.25 * lumaNE)) +
                     abs((0.50 * lumaW ) + (-1.0 * lumaM) + (0.50 * lumaE )) +
                     abs((0.25 * lumaSW) + (-0.5 * lumaS) + (0.25 * lumaSE));

    float edgeHori = abs((0.25 * lumaNW) + (-0.5 * lumaW) + (0.25 * lumaSW)) +
                     abs((0.50 * lumaN ) + (-1.0 * lumaM) + (0.50 * lumaS )) +
                     abs((0.25 * lumaNE) + (-0.5 * lumaE) + (0.25 * lumaSE));

    bool isHorizontal = (edgeHori >= edgeVert);

    // Select step direction perpendicular to edge
    float luma1 = isHorizontal ? lumaN : lumaW;
    float luma2 = isHorizontal ? lumaS : lumaE;
    float gradient1 = abs(luma1 - lumaM);
    float gradient2 = abs(luma2 - lumaM);

    float stepLength = isHorizontal ? uTexelSize.y : uTexelSize.x;
    float lumaLocalAverage;

    if (gradient1 >= gradient2) {
        stepLength = -stepLength;
        lumaLocalAverage = 0.5 * (luma1 + lumaM);
    } else {
        lumaLocalAverage = 0.5 * (luma2 + lumaM);
    }

    // UV shifted by half-pixel in direction of gradient
    vec2 currentUV = vUV;
    if (isHorizontal) {
        currentUV.y += stepLength * 0.5;
    } else {
        currentUV.x += stepLength * 0.5;
    }

    // Step along the edge
    vec2 offset = isHorizontal ? vec2(uTexelSize.x, 0.0) : vec2(0.0, uTexelSize.y);
    vec2 uvPos = currentUV + offset;
    vec2 uvNeg = currentUV - offset;

    float lumaEndPos = rgb2luma(texture(SamplerDiffuse, uvPos).rgb) - lumaLocalAverage;
    float lumaEndNeg = rgb2luma(texture(SamplerDiffuse, uvNeg).rgb) - lumaLocalAverage;

    float gradientScaled = 0.25 * max(gradient1, gradient2);
    bool reachedPos = abs(lumaEndPos) >= gradientScaled;
    bool reachedNeg = abs(lumaEndNeg) >= gradientScaled;

    for (int i = 2; i < FXAA_ITERATIONS; i++) {
        if (!reachedPos) {
            uvPos += offset;
            lumaEndPos = rgb2luma(texture(SamplerDiffuse, uvPos).rgb) - lumaLocalAverage;
            reachedPos = abs(lumaEndPos) >= gradientScaled;
        }
        if (!reachedNeg) {
            uvNeg -= offset;
            lumaEndNeg = rgb2luma(texture(SamplerDiffuse, uvNeg).rgb) - lumaLocalAverage;
            reachedNeg = abs(lumaEndNeg) >= gradientScaled;
        }
        if (reachedPos && reachedNeg) break;
    }

    // Calculate distance to ends
    float distPos = isHorizontal ? (uvPos.x - vUV.x) : (uvPos.y - vUV.y);
    float distNeg = isHorizontal ? (vUV.x - uvNeg.x) : (vUV.y - uvNeg.y);

    bool isPosCloser = distPos < distNeg;
    float distClosest = min(distPos, distNeg);
    float edgeLength = distPos + distNeg;

    // Sub-pixel offset based on distance along edge
    float edgeOffset = -2.0 * (distClosest / edgeLength) + 1.0;
    float edgeLuma = isPosCloser ? lumaEndPos : lumaEndNeg;
    bool isDifferentSide = (edgeLuma < 0.0) != ((lumaM - lumaLocalAverage) < 0.0);
    float finalOffset = isDifferentSide ? (edgeOffset * abs(stepLength)) : 0.0;

    // Sub-pixel antialiasing calculation (for standalone points/fine lines)
    float lumaFullRange = (2.0 * (lumaN + lumaS + lumaW + lumaE) + (lumaNW + lumaNE + lumaSW + lumaSE)) * (1.0 / 12.0);
    float subpixOffset = clamp(abs(lumaFullRange - lumaM) / lumaRange, 0.0, 1.0);
    subpixOffset = smoothstep(0.0, 1.0, subpixOffset);
    float subpixBlend = subpixOffset * subpixOffset * FXAA_SUBPIX_QUALITY;

    finalOffset = max(finalOffset, subpixBlend * abs(stepLength));

    vec2 finalUV = vUV;
    if (isHorizontal) {
        finalUV.y += finalOffset * sign(stepLength);
    } else {
        finalUV.x += finalOffset * sign(stepLength);
    }

    fragColor = vec4(texture(SamplerDiffuse, finalUV).rgb, centerColor.a);
}
""";

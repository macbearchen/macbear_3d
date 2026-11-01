#version 300 es
precision mediump float;
// Fullscreen frag-shader //////////

in vec2 vUV;

uniform sampler2D SamplerDiffuse;	// GL_TEXTURE0

out vec4 fragColor;

void main() {
    float depth = texture(SamplerDiffuse, vUV).r;

    fragColor = vec4(depth, depth, depth, 1.0);
}
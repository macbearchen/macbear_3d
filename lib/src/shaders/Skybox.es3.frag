#version 300 es
precision mediump float;
// Skybox frag-shader ES3 //////////

in lowp vec4 DestinationColor;
in mediump vec3 TexCoordDirOut;
uniform samplerCube SamplerEnvironment; // cubemap texture
uniform mediump vec4 uParamPBR; // x: Metallic, y: Roughness, z: Mipmap-level, w: Occlusion-strength
out vec4 fragColor;

void main(void)
{
    mediump float mipLevel = uParamPBR.y * uParamPBR.z; // Roughness * MaxMipLevel
    mediump vec4 linearColor = textureLod(SamplerEnvironment, TexCoordDirOut, mipLevel) * DestinationColor;
    // gamma correction
    linearColor.rgb = pow(max(linearColor.rgb, 0.0), vec3(1.0 / 2.2));
    fragColor = linearColor;
}

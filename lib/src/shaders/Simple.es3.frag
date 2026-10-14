#version 300 es
precision mediump float;
// Simple frag-shader ES3 //////////

in mediump vec4 DestinationColor;
out vec4 fragColor;

void main(void)
{
    fragColor = DestinationColor;
}

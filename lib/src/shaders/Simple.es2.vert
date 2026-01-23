// NOTICE: "Skinning.es2.vert" must be added before this file

// Simple vert-shader //////////
// attribute mediump vec4 inColor;		// as diffuse-ambient material
		  
uniform lowp vec4 uColor;
varying lowp vec4 DestinationColor;
// eye-space for camera-viewer
//uniform mat4 Projection;
//uniform mat4 Modelview;
uniform highp mat4 ModelviewProjection;
		  
void main(void)
{
	highp vec4 objVert = vec4(inVertex, 1.0);

	if (BoneCount > 0)
	{
		ComputeSkinningVertex(objVert);
	}

	//DestinationColor = vec4(1,1,1, 1); // use white color
    DestinationColor = uColor; // use uniform color
    gl_Position = ModelviewProjection * objVert;	// pre-compute Projection * Modelview
}

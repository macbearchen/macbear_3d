// Generated file – do not edit.
// ignore: constant_identifier_names
const String Simple_es2_vert = r"""
// Simple vert-shader //////////
attribute highp vec3 inVertex;
// attribute mediump vec4 inColor;		// as diffuse-ambient material
		  
// skinning mesh part: bone
uniform mediump int BoneCount;
uniform highp   mat4 BoneMatrixArray[8];
attribute mediump vec4 inBoneIndex;
attribute mediump vec4 inBoneWeight;
		  
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
		highp vec4 srcVert = objVert;
		mediump ivec4 boneIndex = ivec4(inBoneIndex);
		// discard for-loop, so extend to whole code
		// (ps: iPad2 has some problem when using for-loop (4 times) in shader)
/*		
		mediump vec4 boneWeight = inBoneWeight;
		highp mat4 boneMatrix = BoneMatrixArray[boneIndex.x];
		
		objVert = boneMatrix * srcVert * boneWeight.x;
		for (lowp int i = 1; i < BoneCount; i++)
		{
			// "rotate" the vector components
			boneIndex = boneIndex.yzwx;
			boneWeight = boneWeight.yzwx;
			
			boneMatrix = BoneMatrixArray[boneIndex.x];
			
			objVert += boneMatrix * srcVert * boneWeight.x;
		}
*/
		objVert = BoneMatrixArray[boneIndex.x] * srcVert * inBoneWeight.x;
		if (BoneCount > 1)
		{
			objVert += BoneMatrixArray[boneIndex.y] * srcVert * inBoneWeight.y;
			if (BoneCount > 2)
			{
				objVert += BoneMatrixArray[boneIndex.z] * srcVert * inBoneWeight.z;
				if (BoneCount > 3)
				{
					objVert += BoneMatrixArray[boneIndex.w] * srcVert * inBoneWeight.w;
				}
			}
		}
	}

	//DestinationColor = vec4(1,1,1, 1); // use white color
    DestinationColor = uColor; // use uniform color
    gl_Position = ModelviewProjection * objVert;	// pre-compute Projection * Modelview
}

""";

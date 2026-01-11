// Macbear3D engine
import '../../macbear_3d.dart';

class M3Resources {
  // debug geom
  static final debugAxis = M3DebugAxisGeom(size: 0.5);
  static final debugSphere = M3DebugSphereGeom(radius: 1.0);
  static final debugFrustum = M3BoxGeom(2.0, 2.0, 2.0);
  static final debugDot = M3SphereGeom(0.1, widthSegments: 4, heightSegments: 2);
  static final debugView = M3PlaneGeom(1.6, 1.6, widthSegments: 5, heightSegments: 4);

  // for dynamic draw: line, triangle
  static M3Shape2D? _line;
  static M3Shape2D? _triangle;

  // text2D from sprite, rectUnit for image
  static M3Text2D? _text2D;
  static M3Rectangle2D? _rectUnit;

  static Future<M3Text2D> get text2D async {
    _text2D ??= await M3Text2D.createText2D(fontSize: 30);
    return _text2D!;
  }

  static M3Shape2D get line {
    _line ??= M3Shape2D(WebGL.LINES, 2)..createVBO(WebGL.DYNAMIC_DRAW);
    return _line!;
  }

  static M3Shape2D get triangle {
    _triangle ??= M3Shape2D(WebGL.TRIANGLES, 3)..createVBO(WebGL.DYNAMIC_DRAW);
    debugPrint('triangle: $_triangle');
    return _triangle!;
  }

  static M3Rectangle2D get rectUnit {
    _rectUnit ??= M3Rectangle2D()
      ..setRectangle(0, 0, 1, 1)
      ..createVBO(WebGL.STATIC_DRAW);
    return _rectUnit!;
  }

  static Future<void> init() async {
    line;
    triangle;
    rectUnit;
    await text2D;
  }
}

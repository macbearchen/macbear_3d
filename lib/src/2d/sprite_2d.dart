// Macbear3D engine
import '../../macbear_3d.dart';
import '../texture/text_texture.dart';

part 'text_2d.dart';

class M3Sprite2D {
  final M3Rectangle2D _rect = M3Rectangle2D();
  M3Material mtr = M3Material();

  late double _spriteW;
  late double _spriteH;

  // sample: row x col = (4 x 3)
  // 0 1 2 3
  // 4 5 6 7
  // 8 9 10 11
  int rowCount = 1;
  int colCount = 1;

  M3Sprite2D(M3Texture tex, {this.rowCount = 1, this.colCount = 1}) {
    mtr.texDiffuse = tex;
    _spriteW = tex.texW.toDouble() / rowCount;
    _spriteH = tex.texH.toDouble() / colCount;

    if (rowCount > 1) {
      _spriteW -= 1;
    }

    if (colCount > 1) {
      _spriteH -= 1;
    }

    _rect.setRectangle(0, 0, _spriteW, _spriteH);
    _rect.mappingUV(0, 0, tex.texW.toDouble(), tex.texH.toDouble());
    _rect.createVBO(WebGL.STATIC_DRAW);
    debugPrint(_rect.toString());
  }

  void dispose() {
    mtr.texDiffuse.dispose();
  }

  void draw(Matrix4 mvMatrix, {int index = 0, Vector4? color}) {
    final row = index % rowCount;
    final col = (index ~/ rowCount) % colCount;

    final offsetX = row.toDouble() / rowCount;
    final offsetY = col.toDouble() / colCount;
    mtr.texMatrix[6] = offsetX;
    mtr.texMatrix[7] = offsetY;

    M3Shape2D.prog2D.setMaterial(mtr, color ?? Colors.white);
    M3Shape2D.prog2D.setModelViewMatrix(mvMatrix);

    // draw shape2D
    _rect.draw();
  }
}

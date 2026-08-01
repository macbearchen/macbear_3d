import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:vector_math/vector_math.dart';

/// Height field data for physics.
/// Can be created from [M3PlaneGeom.toHeightField], [M3TerrainGeom], or directly
/// from a heightmap image via [M3HeightField.fromHeightmap].
class M3HeightField {
  Float32List data;
  Vector2 cellSize;
  double heightScale;
  int widthSegments;
  int heightSegments;

  M3HeightField({
    required this.data,
    required this.cellSize,
    required this.heightScale,
    required this.widthSegments,
    required this.heightSegments,
  });

  /// Create a height field by sampling an [img.Image] heightmap with bilinear
  /// interpolation. Works transparently for both 8-bit and 16-bit source images.
  factory M3HeightField.fromHeightmap(
    img.Image image,
    double width,
    double height, {
    int widthSegments = 64,
    int heightSegments = 64,
    double maxHeight = 5.0,
  }) {
    final numPoints = (widthSegments + 1) * (heightSegments + 1);
    final data = Float32List(numPoints);
    int index = 0;

    for (int i = 0; i <= heightSegments; i++) {
      final double ratioY = i / heightSegments;
      for (int j = 0; j <= widthSegments; j++) {
        final double ratioX = j / widthSegments;
        data[index++] = _sampleHeight(image, ratioX, ratioY, maxHeight);
      }
    }

    return M3HeightField(
      data: data,
      cellSize: Vector2(width / widthSegments, height / heightSegments),
      heightScale: 1.0,
      widthSegments: widthSegments,
      heightSegments: heightSegments,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers (mirror of M3TerrainGeom sampling logic)
  // ---------------------------------------------------------------------------

  static double _sampleHeight(img.Image image, double u, double v, double maxHeight) {
    final imgW = image.width;
    final imgH = image.height;

    final double px = u * (imgW - 1);
    final double py = v * (imgH - 1);
    final int x0 = px.floor().clamp(0, imgW - 1);
    final int x1 = (x0 + 1).clamp(0, imgW - 1);
    final int y0 = py.floor().clamp(0, imgH - 1);
    final int y1 = (y0 + 1).clamp(0, imgH - 1);

    final double tx = px - x0;
    final double ty = py - y0;

    final double h00 = _getPixelHeight(image, x0, y0);
    final double h10 = _getPixelHeight(image, x1, y0);
    final double h01 = _getPixelHeight(image, x0, y1);
    final double h11 = _getPixelHeight(image, x1, y1);

    final double h0 = h00 * (1.0 - tx) + h10 * tx;
    final double h1 = h01 * (1.0 - tx) + h11 * tx;

    return (h0 * (1.0 - ty) + h1 * ty) * maxHeight;
  }

  static double _getPixelHeight(img.Image image, int x, int y) {
    final pixel = image.getPixel(x, y);
    // Average RGB; normalised by maxChannelValue → works for 8-bit and 16-bit
    return (pixel.r + pixel.g + pixel.b) / (3 * image.maxChannelValue);
  }
}

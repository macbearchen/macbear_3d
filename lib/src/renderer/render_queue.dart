// Macbear3D engine
import '../m3_internal.dart';

abstract final class M3ShaderVariantBits {
  // 影響深度（shadow caster 保留）
  // static const int enableSkinning = 1 << 0; // 0b0001
  static const int enableAlphaTest = 1 << 1; // 0b0010

  // 只影響著色（shadow caster 去除）
  static const int enableNormalMap = 1 << 2; // 0b0100
  static const int enableShadowReceive = 1 << 3; // 0b1000

  static const int casterMask = enableAlphaTest; // 0b0011
}

/// Represents a single sub-mesh draw call data for sorting and batching.
class M3RenderItem {
  final M3Entity entity;
  final M3SubMesh subMesh;
  final Matrix4 worldMatrix;
  late Matrix4 worldMatrixInv;
  final double depth;
  int variantKey = 0;
  List<M3PointLight> pointLights = [];
  List<M3SpotLight> spotLights = [];

  M3RenderItem({required this.entity, required this.subMesh, required this.worldMatrix, required this.depth}) {
    worldMatrixInv = Matrix4.inverted(worldMatrix);
    variantKey = buildVariantKey();
  }

  /// Priority for sorting opaque objects.
  /// Group by Material (program + texture) then by proximity.
  int get opaqueSortKey {
    // We could use program.id and texture.id if they were available
    // For now, we use material hash or just basic distance.
    return subMesh.mtr.renderOrder;
  }

  int buildVariantKey() {
    int bits = 0;

    if (subMesh.mtr.alphaMode == M3AlphaMode.mask) {
      bits |= M3ShaderVariantBits.enableAlphaTest;
    }

    // check normal map
    final frameUseNormalMap = M3AppEngine.instance.renderEngine.options.useNormalMap;
    if (subMesh.mtr.normalTexture != null && frameUseNormalMap) {
      bits |= M3ShaderVariantBits.enableNormalMap;
    }

    final frameUseShadow = M3AppEngine.instance.renderEngine.isShadowEnabled;
    if (subMesh.mtr.receiveShadow && frameUseShadow) {
      bits |= M3ShaderVariantBits.enableShadowReceive;
    }

    return bits;
  }
}

/// A queue of render items to be processed in a specific order.
class M3RenderQueue {
  final List<M3RenderItem> items = [];

  void clear() => items.clear();

  void add(M3RenderItem item) => items.add(item);

  bool get isEmpty => items.isEmpty;

  /// Sort opaque items:
  /// 1. User specified render order
  /// 2. Variant key (group by shader variant: normalmap, shadow, etc. to minimize state changes)
  /// 3. Proximity (Front-to-Back for Early-Z optimization)
  void sortOpaque() {
    items.sort((a, b) {
      // 1. User specified render order
      if (a.subMesh.mtr.renderOrder != b.subMesh.mtr.renderOrder) {
        return a.subMesh.mtr.renderOrder.compareTo(b.subMesh.mtr.renderOrder);
      }
      // 2. Shader variant key (batch by program variant)
      if (a.variantKey != b.variantKey) {
        return a.variantKey.compareTo(b.variantKey);
      }
      // 3. Proximity (Front-to-Back)
      return a.depth.compareTo(b.depth);
    });
  }

  /// Sort transparent items:
  /// 1. User specified render order
  /// 2. Proximity (Back-to-Front for correct alpha blending)
  /// 3. Variant key (secondary batching if at the same depth)
  void sortTransparent() {
    items.sort((a, b) {
      // 1. User specified render order
      if (a.subMesh.mtr.renderOrder != b.subMesh.mtr.renderOrder) {
        return a.subMesh.mtr.renderOrder.compareTo(b.subMesh.mtr.renderOrder);
      }
      // 2. Proximity (Back-to-Front)
      final depthCompare = b.depth.compareTo(a.depth);
      if (depthCompare != 0) {
        return depthCompare;
      }
      // 3. Shader variant key
      return a.variantKey.compareTo(b.variantKey);
    });
  }
}

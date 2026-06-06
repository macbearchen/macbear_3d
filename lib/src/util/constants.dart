import 'package:flutter/material.dart' hide Matrix4;

// Macbear3D engine
import '../m3_internal.dart' hide Colors;

enum M3Axis { x, y, z }

class M3Constants {
  // POD should rotate axisX 90 degree: up from axisY(POD) to axisZ(3dsmax); POD(x,y,z) to 3dsmax(x,-z,y)
  // matrix rotate by X-axis: rotationX(-PI_HALF)
  static final Matrix3 rotXNeg90 = Matrix3.columns(
    Vector3(1, 0, 0), // X
    Vector3(0, 0, -1), // -Z
    Vector3(0, 1, 0), // Y
  );

  // matrix rotate by X-axis: rotationX(PI_HALF)
  static final Matrix3 rotXPos90 = Matrix3.columns(
    Vector3(1, 0, 0), // X
    Vector3(0, 0, 1), // Z
    Vector3(0, -1, 0), // Y
  );

  static final biasMatrix = Matrix4.columns(
    Vector4(0.5, 0, 0, 0),
    Vector4(0, 0.5, 0, 0),
    Vector4(0, 0, 0.5, 0),
    Vector4(0.5, 0.5, 0.5, 1),
  );

  // default material
  static final M3Material mtrDefault = M3Material()
    ..diffuse = Vector4(0.75, 0.75, 0.75, 1.0)
    ..specular = Vector3(0.2, 0.2, 0.2)
    ..shininess = 32;

  // 高反射、高光集中的銀色金屬
  static final M3Material mtrMetal = M3Material()
    ..diffuse = Vector4(0.4, 0.4, 0.4, 1.0)
    ..specular = Vector3(0.6, 0.6, 0.6)
    ..shininess = 128
    ..reflection = 0.8;

  static final M3Material mtrWood = M3Material()
    ..diffuse = Vector4(0.65, 0.45, 0.25, 1.0)
    ..specular = Vector3(0.2, 0.2, 0.2)
    ..shininess = 32;

  // blinn plastic
  static final M3Material mtrPlastic = M3Material()
    ..diffuse = Vector4(0.65, 0.65, 0.65, 1.0)
    ..specular = Vector3(0.2, 0.2, 0.2)
    ..shininess = 64
    ..reflection = 0.4;

  // 半透明、高反射的清玻璃
  static final M3Material mtrGlass = M3Material()
    ..diffuse = Vector4(0.0, 0.0, 0.0, 0.2)
    ..specular = Vector3(0.5, 0.5, 0.5)
    ..shininess = 64
    ..reflection = 0.9;

  static final Vector3 colorLake = Vector3(0.30, 0.45, 0.40);
  static final Vector3 colorMountainLake = Vector3(0.35, 0.55, 0.60);
  static final Vector3 colorBeach = Vector3(0.31, 0.75, 0.78);
  static final Vector3 colorOcean = Vector3(0.23, 0.44, 0.48);
  static final Vector3 colorNight = Vector3(0.12, 0.15, 0.20);
  static final Vector3 colorDusk = Vector3(0.85, 0.70, 0.55);
  static final Vector3 colorGray = Vector3(0.70, 0.72, 0.75);
  static final Vector3 colorSkyBlue = Vector3(0.78, 0.85, 0.91);
}

// package: local font asset
class M3Package {
  static String? name = "macbear_3d";

  // fixed width font
  static TextStyle textStyleRobotoMono({double fontSize = 32}) {
    TextStyle style = TextStyle(
      fontFamily: 'RobotoMono',
      package: name, // 強制使用 package 命名空間
      fontSize: fontSize,
      color: Colors.white,
      letterSpacing: 1.1, // 這裡設定字距，數值越大間隔越開
      height: 1.1,
      // shadows: const [Shadow(blurRadius: 1, offset: Offset(1, 1))],
    );

    return style;
  }

  static String asset(String path) {
    return 'packages/$name/$path';
  }
}

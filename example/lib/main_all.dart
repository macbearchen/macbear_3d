// ignore_for_file: unused_import, unused_local_variable
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math.dart' hide Colors;

// Macbear3D engine
import 'package:macbear_3d/macbear_3d.dart';
export 'package:macbear_3d/src/m3_internal.dart';

import 'demos/00_starter.dart';
import 'demos/01_cube.dart';
import 'demos/02_skybox.dart';
import 'demos/03_primitives.dart';
import 'demos/04_obj_teapot.dart';
import 'demos/05_animated.dart';
import 'demos/06_shadowmap.dart';
import 'demos/07_physics.dart';
import 'demos/08_text_3d.dart';
import 'demos/09_pbr_test.dart';
import 'demos/10_terrain.dart';
import 'demos/11_bvh.dart';
import 'demos/12_video_texture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // M3Package.name = null; // remove it when release
  M3AppEngine.instance.onDidInit = onDidInit;
  M3AppEngine.backgroundColor = Vector3(0.1, 0.2, 0.6);

  final shaderOptions = M3AppEngine.instance.renderEngine.options.shader;
  shaderOptions.pcf = 2;
  shaderOptions.perPixel = true;
  shaderOptions.pbr = true;
  shaderOptions.ibl = true;
  runApp(MainApp());
}

Future<void> onDidInit() async {
  debugPrint('main_all.dart: onDidInit');
  final appEngine = M3AppEngine.instance;
  appEngine.renderEngine.createShadowMap(width: 2048, height: 4096);

  // final scene00 = StarterScene_00();
  // final scene03 = PrimitivesScene_03();
  // final scene09 = PbrTestScene_09();
  // final testScene = SampleScene();
  final initScene = CubeScene_01();
  final testScene = BaseScene();
  await appEngine.setScene(testScene);
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const MainPage());
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // 0 - no shadow
  // 1 - shadowmap
  // 2 - csm
  int shadowMode = 2;
  int _selectedSceneIndex = 1; // 00 starter, 01-08 scenes, 9 sample

  @override
  void initState() {
    super.initState();
    M3AppEngine.instance.addListener(_onEngineChanged);
  }

  @override
  void dispose() {
    M3AppEngine.instance.removeListener(_onEngineChanged);
    super.dispose();
  }

  void _onEngineChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadScene(M3Scene scene) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.black54,
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.lightGreen),
                const SizedBox(width: 20),
                const Text("Loading 3D Scene...", style: TextStyle(color: Colors.white)),
              ],
            ),
          ),
        );
      },
    );

    try {
      await M3AppEngine.instance.setScene(scene);
    } finally {
      // Close the dialog
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        setState(() {
          setShadowMode(shadowMode);
        }); // Refresh UI
      }
    }
  }

  void setShadowMode(int mode) {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final scene = M3AppEngine.instance.activeScene;
    if (scene == null) return;

    shadowMode = mode;
    switch (shadowMode) {
      case 0: // no shadow
        renderEngine.options.shadows = false;
        scene.camera.csmCount = 0;
        break;
      case 1: // shadowmap
        renderEngine.options.shadows = true;
        scene.camera.csmCount = 0;
        final halfView = 8;
        scene.light.target = Vector3.zero();
        scene.light.setViewport(-halfView, -halfView, halfView * 2, halfView * 2, fovy: 0, far: 50);
        scene.light.setEuler(pi / 5, -pi / 3, 0, distance: 30); // rotate light
        scene.light.refreshProjectionMatrix();
        break;
      case 2: // cascade shadow map
        renderEngine.options.shadows = true;
        scene.camera.csmCount = 4;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('Macbear 3D Engine - Powered by ANGLE')),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          getHelperWidget(),
          const SizedBox(height: 10),
          getShaderWidget(),
          const SizedBox(height: 10),
          getTutorialWidget(),
        ],
      ),
      body: Stack(
        children: [
          const M3View(),
          Positioned(top: 10, right: 5, child: getTimeScaleWidget()),
          if (M3AppEngine.instance.activeScene != null)
            M3AppEngine.instance.activeScene!.buildUI(context) ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  final _timeScaleValues = [0.0, 0.1, 0.5, 1.0, 1.25, 1.5, 2.0, 5.0];

  Widget getTimeScaleWidget() {
    final engine = M3AppEngine.instance;
    // Find closest index
    int index = _timeScaleValues.indexWhere((v) => (v - engine.timeScale).abs() < 0.01);
    if (index == -1) index = 4; // default to 1.0

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            "${engine.timeScale.toStringAsFixed(2)}x",
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          SizedBox(
            width: 150,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              ),
              child: Slider(
                value: index.toDouble(),
                min: 0,
                max: (_timeScaleValues.length - 1).toDouble(),
                divisions: _timeScaleValues.length - 1,
                activeColor: Colors.lightGreen,
                inactiveColor: Colors.white24,
                onChanged: (val) {
                  setState(() {
                    engine.timeScale = _timeScaleValues[val.toInt()];
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget getShaderWidget() {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final shaderOptions = renderEngine.options.shader;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'shadow',
          backgroundColor: shadowMode > 0 ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              setShadowMode((shadowMode + 1) % 3);
            });
          },
          child: Icon(
            shadowMode == 2 ? Icons.layers : (shadowMode == 1 ? Icons.light_mode : Icons.light_mode_outlined),
          ),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'pcf',
          backgroundColor: shaderOptions.pcf > 0 ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              shaderOptions.pcf = (shaderOptions.pcf + 1) % 4;
            });
          },
          child: Text('PCF ${shaderOptions.pcf}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 20),
        FloatingActionButton(
          heroTag: 'per_pixel',
          backgroundColor: shaderOptions.perPixel ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              shaderOptions.perPixel = !shaderOptions.perPixel;
            });
          },
          child: const Icon(Icons.draw),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'cartoon',
          backgroundColor: shaderOptions.cartoon ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              shaderOptions.cartoon = !shaderOptions.cartoon;
            });
          },
          child: const Text('toon'),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'pbr',
          backgroundColor: shaderOptions.pbr ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              shaderOptions.pbr = !shaderOptions.pbr;
            });
          },
          child: const Text('PBR'),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'ibl',
          backgroundColor: shaderOptions.ibl ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              shaderOptions.ibl = !shaderOptions.ibl;
            });
          },
          child: const Text('IBL'),
        ),
      ],
    );
  }

  Widget getHelperWidget() {
    final renderEngine = M3AppEngine.instance.renderEngine;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'wireframe',
          backgroundColor: renderEngine.options.debug.wireframe ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              renderEngine.options.debug.wireframe = !renderEngine.options.debug.wireframe;
            });
          },
          child: const Icon(Icons.grid_4x4_sharp),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'info',
          backgroundColor: renderEngine.options.debug.showHelpers ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              renderEngine.options.debug.showHelpers = !renderEngine.options.debug.showHelpers;
            });
          },
          child: const Icon(Icons.info),
        ),
      ],
    );
  }

  Widget getTutorialWidget() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'scene_01',
            backgroundColor: _selectedSceneIndex == 1 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 1;
              _loadScene(CubeScene_01());
            },
            child: const Icon(Icons.filter_1),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_02',
            backgroundColor: _selectedSceneIndex == 2 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 2;
              _loadScene(SkyboxScene_02());
            },
            child: const Icon(Icons.filter_2),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_03',
            backgroundColor: _selectedSceneIndex == 3 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 3;
              _loadScene(PrimitivesScene_03());
            },
            child: const Icon(Icons.filter_3),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_04',
            backgroundColor: _selectedSceneIndex == 4 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 4;
              _loadScene(ObjTeapotScene_04());
            },
            child: const Icon(Icons.filter_4),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_05',
            backgroundColor: _selectedSceneIndex == 5 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 5;
              _loadScene(AnimatedScene_05());
            },
            child: const Icon(Icons.filter_5),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_06',
            backgroundColor: _selectedSceneIndex == 6 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 6;
              _loadScene(ShadowmapScene_06());
            },
            child: const Icon(Icons.looks_6),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_07',
            backgroundColor: _selectedSceneIndex == 7 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 7;
              _loadScene(PhysicsScene_07());
            },
            child: const Icon(Icons.filter_7),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_08',
            backgroundColor: _selectedSceneIndex == 8 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 8;
              _loadScene(Text3DScene_08());
            },
            child: const Icon(Icons.filter_8),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_09',
            backgroundColor: _selectedSceneIndex == 9 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 9;
              _loadScene(PbrTestScene_09());
            },
            child: const Icon(Icons.filter_9),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_12',
            backgroundColor: _selectedSceneIndex == 12 ? Colors.lightGreen : null,
            onPressed: () {
              _selectedSceneIndex = 12;
              _loadScene(VideoTextureScene_12());
            },
            child: const Icon(Icons.video_library),
          ),
        ],
      ),
    );
  }
}

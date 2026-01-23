import 'package:flutter/material.dart';

// Macbear3D engine
import 'package:macbear_3d/macbear_3d.dart' hide Colors;
export 'package:macbear_3d/macbear_3d.dart';

import '00_starter.dart';
import '01_cube.dart';
import '02_skybox.dart';
import '03_primitives.dart';
import '04_obj_teapot.dart';
import '05_gltf.dart';
import '06_shadowmap.dart';
import '07_physics.dart';
import '08_text_3d.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  M3AppEngine.instance.onDidInit = onDidInit;
  runApp(MainApp());
}

Future<void> onDidInit() async {
  debugPrint('main_example.dart: onDidInit');
  final renderEngine = M3AppEngine.instance.renderEngine;
  renderEngine.createShadowMap(width: 2048, height: 4096);
  await M3AppEngine.instance.setScene(StarterScene_00());
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
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Macbear 3D Engine - Powered by ANGLE')),
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
          Positioned(top: 3, right: 3, child: getTimeScaleWidget()),
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
          onPressed: () {
            final scene = M3AppEngine.instance.activeScene!;
            shadowMode = (shadowMode + 1) % 3;
            switch (shadowMode) {
              case 0: // no shadow
                renderEngine.options.shadows = false;
                scene.camera.csmCount = 0;
                break;
              case 1: // shadowmap
                renderEngine.options.shadows = true;
                scene.camera.csmCount = 0;
                scene.light.refreshProjectionMatrix();
                scene.light.setLookat(Vector3(2, 0, 8), Vector3.zero(), Vector3(0, 0, 1));
                break;
              case 2: // cascade shadow map
                renderEngine.options.shadows = true;
                scene.camera.csmCount = 4;
                break;
            }
          },
          child: const Icon(Icons.light_mode_rounded),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'pcf',
          onPressed: () {
            shaderOptions.pcf = !shaderOptions.pcf;
            renderEngine.setLightingProgram();
          },
          child: const Icon(Icons.blur_on_rounded),
        ),
        const SizedBox(width: 16),
        FloatingActionButton(
          heroTag: 'per_pixel',
          onPressed: () {
            shaderOptions.perPixel = !shaderOptions.perPixel;
            renderEngine.setLightingProgram();
          },
          child: const Icon(Icons.draw),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'cartoon',
          onPressed: () {
            shaderOptions.cartoon = !shaderOptions.cartoon;
            renderEngine.setLightingProgram();
          },
          child: const Icon(Icons.draw_outlined),
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
          onPressed: () {
            renderEngine.options.debug.wireframe = !renderEngine.options.debug.wireframe;
          },
          child: const Icon(Icons.grid_4x4_sharp),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'info',
          onPressed: () {
            renderEngine.options.debug.showHelpers = !renderEngine.options.debug.showHelpers;
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
            onPressed: () => _loadScene(CubeScene_01()),
            child: const Icon(Icons.filter_1),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_02',
            onPressed: () => _loadScene(SkyboxScene_02()),
            child: const Icon(Icons.filter_2),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_03',
            onPressed: () => _loadScene(PrimitivesScene_03()),
            child: const Icon(Icons.filter_3),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_04',
            onPressed: () => _loadScene(ObjTeapotScene_04()),
            child: const Icon(Icons.filter_4),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_05',
            onPressed: () => _loadScene(GlftScene_05()),
            child: const Icon(Icons.filter_5),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_06',
            onPressed: () => _loadScene(ShadowmapScene_06()),
            child: const Icon(Icons.looks_6),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_07',
            onPressed: () => _loadScene(PhysicsScene_07()),
            child: const Icon(Icons.filter_7),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'scene_08',
            onPressed: () => _loadScene(Text3DScene_08()),
            child: const Icon(Icons.filter_8),
          ),
          const SizedBox(width: 6),
          FloatingActionButton(
            heroTag: 'sample',
            onPressed: () => _loadScene(SampleScene()),
            child: const Icon(Icons.desktop_mac_sharp),
          ),
        ],
      ),
    );
  }
}

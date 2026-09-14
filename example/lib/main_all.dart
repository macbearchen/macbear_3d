// ignore_for_file: unused_import, unused_local_variable
import 'package:material_ui/material_ui.dart';

// Macbear3D engine
export 'package:macbear_3d/src/m3_internal.dart';
// physics engine
export 'rapier/rapier_physics_engine.dart';
// rapier scenes
import 'rapier/base_scene.dart' hide Colors;
import 'rapier/physics_scene.dart';
import 'rapier/compound_scene.dart';
import 'rapier/double_pendulum.dart';
import 'rapier/newton_cradle.dart';
import 'rapier/character_controller_scene.dart';
import 'rapier/scene_query_scene.dart';
import 'demos/demo_scene.dart';
export 'demos/demo_scene.dart';

import 'demos/00_starter.dart';
import 'demos/01_cube.dart';
import 'demos/02_skybox.dart';
import 'demos/03_primitives.dart';
import 'demos/04_obj_teapot.dart';
import 'demos/05_animated.dart';
import 'demos/06_terrain.dart';
import 'demos/07_physics.dart';
import 'demos/08_text_3d.dart';
import 'demos/09_pbr_test.dart';
import 'demos/11_bvh.dart';
import 'demos/12_video_texture.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final renderOptions = M3AppEngine.instance.renderEngine.options;
  final shaderOptions = renderOptions.shader;
  final debugOptions = renderOptions.debug;
  // debugOptions.showLight = true;
  // debugOptions.showCamera = true;
  renderOptions.dprScale = 0.0;
  shaderOptions.pcf = 2;
  shaderOptions.perPixel = true;
  shaderOptions.pbr = true;
  shaderOptions.ibl = true;

  M3AppEngine.instance.onDidInit = onDidInit;
  M3AppEngine.backgroundColor = Vector3(0.1, 0.2, 0.6);

  runApp(MainApp());
}

Future<void> onDidInit() async {
  M3Log.h('example/main_all.dart', 'onDidInit');
  final appEngine = M3AppEngine.instance;

  final scene00 = StarterScene_00();
  final scene06 = TerrainScene_06();
  // final testScene = SampleScene(physics: M3PhysicsSystem(M3RapierPhysicsEngine()));
  final initScene = CubeScene_01();
  await appEngine.setScene(initScene);
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
  int _selectedPhysicsSubIndex = 0; // cycles 0-5 through the 6 physics scenes
  bool _showSettings = true;
  final separateWidget = SizedBox(width: 2, height: 2);

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
            padding: EdgeInsets.all(12.0),
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
        renderEngine.options.useShadow = false;
        scene.camera.csmCount = 0;
        break;
      case 1: // shadowmap
        renderEngine.options.useShadow = true;
        scene.camera.csmCount = 0;
        final halfView = 12;
        final lightViewer = scene.dirLight.lightViewer;
        lightViewer.target = Vector3.zero();
        lightViewer.setViewport(-halfView, -halfView, halfView * 2, halfView * 2, fovy: 0, far: 100);
        lightViewer.setEuler(pi / 4, -pi / 4, 0, distance: 30); // rotate light
        lightViewer.refreshProjectionMatrix();
        break;
      case 2: // cascade shadow map
        renderEngine.options.useShadow = true;
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
          if (_showSettings) ...[
            getHelperWidget(),
            const SizedBox(height: 8),
            getFogWidget(),
            separateWidget,
            getShaderWidget(),
            const SizedBox(height: 8),
          ],
          getTutorialWidget(),
        ],
      ),
      body: Stack(
        children: [
          const M3View(),
          Positioned(top: 2, right: 2, child: SafeArea(bottom: false, child: getTimeScaleWidget())),
          if (_showSettings && M3AppEngine.instance.activeScene != null)
            M3AppEngine.instance.activeScene!.buildUI(context) ?? const SizedBox.shrink(),
        ],
      ),
    );
  }

  final _timeScaleValues = [0.0, 0.25, 0.5, 1.0, 1.25, 1.5, 2.0, 4.0];

  /// Time Scale Widget
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
          Text("${engine.timeScale.toStringAsFixed(2)}x", style: const TextStyle(color: Colors.white, fontSize: 10)),
          SizedBox(
            width: 100,
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
          separateWidget,
          Container(width: 1, height: 16, color: Colors.white24),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              setState(() {
                _showSettings = !_showSettings;
              });
            },
            child: Icon(
              _showSettings ? Icons.settings : Icons.settings_outlined,
              color: _showSettings ? Colors.lightGreen : Colors.white70,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  /// Shader Widget
  Widget getShaderWidget() {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final shaderOptions = renderEngine.options.shader;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'shadow',
          backgroundColor: shadowMode > 0 ? Colors.amber : null,
          onPressed: () {
            setState(() {
              setShadowMode((shadowMode + 1) % 3);
            });
          },
          child: Icon(
            shadowMode == 2 ? Icons.layers : (shadowMode == 1 ? Icons.light_mode : Icons.light_mode_outlined),
          ),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'pcf',
          backgroundColor: shaderOptions.pcf > 0 ? Colors.amber : null,
          onPressed: () {
            setState(() {
              shaderOptions.pcf = (shaderOptions.pcf + 1) % 4;
            });
          },
          child: Text('PCF ${shaderOptions.pcf}', style: const TextStyle(fontSize: 10)),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'csm_vs_fs',
          backgroundColor: shaderOptions.csmOnFS ? Colors.amber : null,
          onPressed: () {
            setState(() {
              shaderOptions.csmOnFS = !shaderOptions.csmOnFS;
            });
          },
          child: Text(shaderOptions.csmOnFS ? 'CSM FS' : 'CSM VS', style: const TextStyle(fontSize: 10)),
        ),
        const SizedBox(width: 8),
        FloatingActionButton.small(
          heroTag: 'per_pixel',
          backgroundColor: shaderOptions.perPixel ? Colors.amber : null,
          onPressed: () {
            setState(() {
              shaderOptions.perPixel = !shaderOptions.perPixel;
            });
          },
          child: const Icon(Icons.draw),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'cartoon',
          backgroundColor: shaderOptions.cartoon ? Colors.amber : null,
          onPressed: () {
            setState(() {
              shaderOptions.cartoon = !shaderOptions.cartoon;
            });
          },
          child: const Text('toon'),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'pbr',
          backgroundColor: shaderOptions.pbr ? Colors.amber : null,
          onPressed: () {
            setState(() {
              shaderOptions.pbr = !shaderOptions.pbr;
            });
          },
          child: const Text('PBR'),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'ibl',
          backgroundColor: shaderOptions.ibl ? Colors.amber : null,
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

  /// Helper
  Widget getHelperWidget() {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final scene = M3AppEngine.instance.activeScene;
    if (scene == null) {
      return SizedBox.shrink();
    }

    final lightBrightness = ((scene.dirLight.color.x + scene.dirLight.color.y + scene.dirLight.color.z) / 3.0).clamp(
      0.0,
      1.0,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FloatingActionButton.small(
          heroTag: 'wireframe',
          backgroundColor: renderEngine.options.debug.wireframe ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              renderEngine.options.debug.wireframe = !renderEngine.options.debug.wireframe;
            });
          },
          child: const Icon(Icons.grid_4x4_sharp),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'map',
          backgroundColor: renderEngine.options.debug.showMaps ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              renderEngine.options.debug.showMaps = !renderEngine.options.debug.showMaps;
            });
          },
          child: const Icon(Icons.map),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'info',
          backgroundColor: renderEngine.options.debug.showHelpers != M3HelperType.none ? Colors.cyan : null,
          onPressed: () {
            setState(() {
              final current = renderEngine.options.debug.showHelpers;
              final next = M3HelperType.values[(current.index + 1) % M3HelperType.values.length];
              renderEngine.options.debug.showHelpers = next;
            });
          },
          child: renderEngine.options.debug.showHelpers == M3HelperType.none
              ? const Icon(Icons.info)
              : Text(
                  renderEngine.options.debug.showHelpers == M3HelperType.entity
                      ? 'Ent'
                      : (renderEngine.options.debug.showHelpers == M3HelperType.subMesh ? 'Sub' : 'Both'),
                  style: const TextStyle(fontSize: 10),
                ),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'camera',
          backgroundColor: renderEngine.options.debug.showCamera ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              renderEngine.options.debug.showCamera = !renderEngine.options.debug.showCamera;
            });
          },
          child: const Icon(Icons.videocam_outlined),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'light',
          backgroundColor: renderEngine.options.debug.showLight ? Colors.lightGreen : null,
          onPressed: () {
            setState(() {
              renderEngine.options.debug.showLight = !renderEngine.options.debug.showLight;
            });
          },
          child: Icon(renderEngine.options.debug.showLight ? Icons.lightbulb_sharp : Icons.lightbulb_outline),
        ),
        separateWidget,
        // ── Directional light brightness slider ──
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u2600', style: TextStyle(fontSize: 11, color: Colors.amber)),
              SizedBox(
                width: 60,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                  ),
                  child: Slider(
                    value: lightBrightness,
                    min: 0.0,
                    max: 1.0,
                    activeColor: Colors.amber,
                    inactiveColor: Colors.white24,
                    onChanged: (val) {
                      setState(() {
                        scene.dirLight.color = Vector3.all(val);
                      });
                    },
                  ),
                ),
              ),
              Text(lightBrightness.toStringAsFixed(2), style: const TextStyle(fontSize: 9, color: Colors.white70)),
            ],
          ),
        ),
      ],
    );
  }

  /// Fog Widget
  Widget getFogWidget() {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final shaderOptions = renderEngine.options.shader;
    final scene = M3AppEngine.instance.activeScene;
    if (scene == null) return const SizedBox.shrink();

    final far = scene.camera.farClip;
    final fogStartPct = far > 0 ? (scene.fog.start / far * 100.0).clamp(10.0, 95.0) : 10.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (shaderOptions.fog) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(24)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("fog: ", style: TextStyle(color: Colors.white70, fontSize: 12)),
                Text("${fogStartPct.toStringAsFixed(0)}%", style: const TextStyle(color: Colors.white, fontSize: 10)),
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    ),
                    child: Slider(
                      value: fogStartPct,
                      min: 10.0,
                      max: 95.0,
                      activeColor: Colors.lime,
                      inactiveColor: Colors.white24,
                      onChanged: (val) {
                        setState(() {
                          final far = scene.camera.farClip;
                          final depthPct = min(100.0 - val, 25.0);
                          scene.fog.start = far * (val / 100.0);
                          scene.fog.depth = far * (depthPct / 100.0);
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        FloatingActionButton.small(
          heroTag: 'fog',
          backgroundColor: shaderOptions.fog ? Colors.lime : null,
          onPressed: () {
            setState(() {
              shaderOptions.fog = !shaderOptions.fog;
            });
          },
          child: Icon(shaderOptions.fog ? Icons.cloud : Icons.cloud_queue),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'point_lights',
          backgroundColor: shaderOptions.pointLights ? Colors.amber : null,
          onPressed: () {
            setState(() {
              shaderOptions.pointLights = !shaderOptions.pointLights;
            });
          },
          child: const Icon(Icons.lightbulb_circle),
        ),
        separateWidget,
        FloatingActionButton.small(
          heroTag: 'spot_lights',
          backgroundColor: shaderOptions.spotLights ? Colors.amber : null,
          onPressed: () {
            setState(() {
              shaderOptions.spotLights = !shaderOptions.spotLights;
            });
          },
          child: const Icon(Icons.highlight),
        ),
      ],
    );
  }

  /// Tutorial Scene
  Widget getTutorialWidget() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'scene_01',
            backgroundColor: _selectedSceneIndex == 1 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 1;
              _loadScene(CubeScene_01());
            },
            child: const Icon(Icons.filter_1),
          ),
          const SizedBox(width: 4),
          FloatingActionButton.small(
            heroTag: 'scene_02',
            backgroundColor: _selectedSceneIndex == 2 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 2;
              _loadScene(SkyboxScene_02());
            },
            child: const Icon(Icons.filter_2),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'scene_03',
            backgroundColor: _selectedSceneIndex == 3 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 3;
              _loadScene(PrimitivesScene_03());
            },
            child: const Icon(Icons.filter_3),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'scene_04',
            backgroundColor: _selectedSceneIndex == 4 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 4;
              _loadScene(ObjTeapotScene_04());
            },
            child: const Icon(Icons.filter_4),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'scene_05',
            backgroundColor: _selectedSceneIndex == 5 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 5;
              _loadScene(AnimatedScene_05());
            },
            child: const Icon(Icons.filter_5),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'scene_06',
            backgroundColor: _selectedSceneIndex == 6 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 6;
              _loadScene(TerrainScene_06());
            },
            child: const Icon(Icons.terrain),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'scene_07',
            backgroundColor: _selectedSceneIndex == 7 ? Colors.cyan : null,
            onPressed: () {
              setState(() {
                _selectedSceneIndex = 7;
                _selectedPhysicsSubIndex = (_selectedPhysicsSubIndex + 1) % 7;
              });
              final M3Scene physicsScene;
              switch (_selectedPhysicsSubIndex) {
                case 0:
                  physicsScene = PhysicsScene_07();
                case 1:
                  physicsScene = BaseScene.createPhysicsScene((p) => PhysicsScene(physics: p));
                case 2:
                  physicsScene = BaseScene.createPhysicsScene((p) => CompoundScene(physics: p));
                case 3:
                  physicsScene = BaseScene.createPhysicsScene((p) => DoublePendulumScene(physics: p));
                case 4:
                  physicsScene = BaseScene.createPhysicsScene((p) => NewtonCradleScene(physics: p));
                case 5:
                  physicsScene = BaseScene.createPhysicsScene((p) => CharacterControllerScene(physics: p));
                case _:
                  physicsScene = BaseScene.createPhysicsScene((p) => SceneQueryScene(physics: p));
              }
              _loadScene(physicsScene);
            },
            child: Text(
              'Phys$_selectedPhysicsSubIndex',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'scene_08',
            backgroundColor: _selectedSceneIndex == 8 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 8;
              _loadScene(Text3DScene_08());
            },
            child: const Icon(Icons.filter_8),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'scene_09',
            backgroundColor: _selectedSceneIndex == 9 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 9;
              _loadScene(PbrTestScene_09());
            },
            child: const Icon(Icons.filter_9),
          ),
          separateWidget,
          /*          FloatingActionButton(
            heroTag: 'scene_10',
            backgroundColor: _selectedSceneIndex == 10 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 10;
              _loadScene(TerrainScene_06());
            },
            child: const Icon(Icons.terrain),
          ),
          const SizedBox(width: 4), */
          FloatingActionButton.small(
            heroTag: 'scene_12',
            backgroundColor: _selectedSceneIndex == 12 ? Colors.cyan : null,
            onPressed: () {
              _selectedSceneIndex = 12;
              // final testScene = SampleScene(physics: M3PhysicsSystem(M3RapierPhysicsEngine()));
              final testScene = VideoTextureScene_12();

              _loadScene(testScene);
            },
            child: const Icon(Icons.video_library),
          ),
        ],
      ),
    );
  }
}

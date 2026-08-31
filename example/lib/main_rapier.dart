// ignore_for_file: unused_import

import 'package:material_ui/material_ui.dart';

import 'rapier/base_scene.dart' hide Colors;
import 'rapier/physics_scene.dart';
import 'rapier/compound_scene.dart';
import 'rapier/double_pendulum.dart';
import 'rapier/newton_cradle.dart';
import 'rapier/character_controller_scene.dart';
import 'rapier/scene_query_scene.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  M3Package.name = null; // remove it when release

  M3AppEngine.instance.onDidInit = onDidInit;

  runApp(MyApp());
}

Future<void> onDidInit() async {
  M3Log.i('main.dart', 'onDidInit');
  final appEngine = M3AppEngine.instance;

  // final testScene = BaseScene.createPhysicsScene((physicsSystem) => PhysicsScene(physics: physicsSystem));
  final testScene = BaseScene.createPhysicsScene((physicsSystem) => NewtonCradleScene(physics: physicsSystem));
  // final testScene = BaseScene();
  await appEngine.setScene(testScene);
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 0 - no shadow
  // 1 - shadowmap
  // 2 - csm
  int shadowMode = 2;

  @override
  Widget build(BuildContext context) {
    final renderOptions = M3AppEngine.instance.renderEngine.options;
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(RapierPhysics.version),
          actions: [
            IconButton(
              icon: renderOptions.debug.showHelpers == M3HelperType.none
                  ? const Icon(Icons.info)
                  : Text(
                      renderOptions.debug.showHelpers == M3HelperType.entity
                          ? 'Ent'
                          : (renderOptions.debug.showHelpers == M3HelperType.subMesh ? 'Sub' : 'Both'),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
              onPressed: () async {
                setState(() {
                  final current = renderOptions.debug.showHelpers;
                  final next = M3HelperType.values[(current.index + 1) % M3HelperType.values.length];
                  renderOptions.debug.showHelpers = next;
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.grid_3x3_outlined),
              onPressed: () async {
                renderOptions.debug.wireframe = !renderOptions.debug.wireframe;
              },
            ),
            IconButton(
              icon: const Icon(Icons.light_mode),
              onPressed: () async {
                final scene = M3AppEngine.instance.activeScene!;
                shadowMode = (shadowMode + 1) % 3;
                if (shadowMode == 0) {
                  renderOptions.shadows = false;
                } else if (shadowMode == 1) {
                  renderOptions.shadows = true;
                  scene.camera.csmCount = 0;
                  final halfView = 8;
                  final lightViewer = scene.dirLight.lightViewer;
                  lightViewer.target = Vector3.zero();
                  lightViewer.setViewport(-halfView, -halfView, halfView * 2, halfView * 2, fovy: 0, far: 50);
                  lightViewer.setEuler(pi / 5, -pi / 3, 0, distance: 30); // rotate light
                  lightViewer.refreshProjectionMatrix();
                } else {
                  renderOptions.shadows = true;
                  scene.camera.csmCount = 4;
                }
              },
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: M3AppEngine.instance,
          builder: (context, _) {
            final activeScene = M3AppEngine.instance.activeScene;
            final sceneUi = activeScene?.buildUI(context);
            return Stack(
              children: [
                const M3View(),
                if (sceneUi != null) IgnorePointer(ignoring: false, child: sceneUi),
              ],
            );
          },
        ),
        floatingActionButton: const PanelWidget(),
      ),
    );
  }
}

/// panel for select physics scene
class PanelWidget extends StatefulWidget {
  const PanelWidget({super.key});

  @override
  _PanelWidgetState createState() => _PanelWidgetState();
}

class _PanelWidgetState extends State<PanelWidget> {
  int _selectedIndex = 0;

  Future<void> _loadScene(int index) async {
    setState(() {
      _selectedIndex = index;
    });

    M3Scene scene;
    if (index == 0) {
      scene = BaseScene.createPhysicsScene((physicsSystem) => PhysicsScene(physics: physicsSystem));
    } else if (index == 1) {
      scene = BaseScene.createPhysicsScene((physicsSystem) => NewtonCradleScene(physics: physicsSystem));
    } else if (index == 2) {
      scene = BaseScene.createPhysicsScene((physicsSystem) => DoublePendulumScene(physics: physicsSystem));
    } else if (index == 3) {
      scene = BaseScene.createPhysicsScene((physicsSystem) => CompoundScene(physics: physicsSystem));
    } else if (index == 4) {
      scene = BaseScene.createPhysicsScene((physicsSystem) => CharacterControllerScene(physics: physicsSystem));
    } else {
      scene = BaseScene.createPhysicsScene((physicsSystem) => SceneQueryScene(physics: physicsSystem));
    }
    await M3AppEngine.instance.setScene(scene);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'scene_01',
          backgroundColor: _selectedIndex == 0 ? Colors.lightGreen : Colors.grey,
          onPressed: () => _loadScene(0),
          child: const Icon(Icons.filter_1),
        ),
        const SizedBox(width: 10),
        FloatingActionButton(
          heroTag: 'scene_02',
          backgroundColor: _selectedIndex == 1 ? Colors.lightGreen : Colors.grey,
          onPressed: () => _loadScene(1),
          child: const Icon(Icons.filter_2),
        ),
        const SizedBox(width: 10),
        FloatingActionButton(
          heroTag: 'scene_03',
          backgroundColor: _selectedIndex == 2 ? Colors.lightGreen : Colors.grey,
          onPressed: () => _loadScene(2),
          child: const Icon(Icons.filter_3),
        ),
        const SizedBox(width: 10),
        FloatingActionButton(
          heroTag: 'scene_04',
          backgroundColor: _selectedIndex == 3 ? Colors.lightGreen : Colors.grey,
          onPressed: () => _loadScene(3),
          child: const Icon(Icons.filter_4),
        ),
        const SizedBox(width: 10),
        FloatingActionButton(
          heroTag: 'scene_05',
          backgroundColor: _selectedIndex == 4 ? Colors.lightGreen : Colors.grey,
          onPressed: () => _loadScene(4),
          child: const Icon(Icons.filter_5),
        ),
        const SizedBox(width: 10),
        FloatingActionButton(
          heroTag: 'scene_06',
          backgroundColor: _selectedIndex == 5 ? Colors.lightGreen : Colors.grey,
          onPressed: () => _loadScene(5),
          child: const Icon(Icons.filter_6),
        ),
      ],
    );
  }
}

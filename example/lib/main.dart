import 'package:flutter/material.dart';
import 'package:macbear_3d/macbear_3d.dart';

export 'package:macbear_3d/macbear_3d.dart';

import '00_starter.dart';
import '01_cube.dart';
import '02_skybox.dart';
import '03_primitives.dart';
import '04_obj_teapot.dart';
import '05_gltf.dart';
import '06_shadowmap.dart';
import '07_physics.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  M3AppEngine.instance.onDidInit = onDidInit;
  runApp(MainApp());
}

Future<void> onDidInit() async {
  debugPrint('main_example.dart: onDidInit');
  await M3AppEngine.instance.setScene(StarterScene_00());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Macbear 3D powered by ANGLE')),
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [getHelperWidget(), const SizedBox(height: 10), getTutorialWidget()],
        ),
        body: M3View(),
      ),
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
            renderEngine.options.wireframe = !renderEngine.options.wireframe;
          },
          child: const Icon(Icons.grid_4x4_sharp),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'info',
          onPressed: () {
            renderEngine.options.helpers = !renderEngine.options.helpers;
          },
          child: const Icon(Icons.info),
        ),
      ],
    );
  }

  Widget getTutorialWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'scene_01',
          onPressed: () async {
            await M3AppEngine.instance.setScene(CubeScene_01());
          },
          child: const Icon(Icons.filter_1),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'scene_02',
          onPressed: () async {
            await M3AppEngine.instance.setScene(SkyboxScene_02());
          },
          child: const Icon(Icons.filter_2),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'scene_03',
          onPressed: () async {
            await M3AppEngine.instance.setScene(PrimitivesScene_03());
          },
          child: const Icon(Icons.filter_3),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'scene_04',
          onPressed: () async {
            await M3AppEngine.instance.setScene(ObjTeapotScene_04());
          },
          child: const Icon(Icons.filter_4),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'scene_05',
          onPressed: () async {
            await M3AppEngine.instance.setScene(GlftScene_05());
          },
          child: const Icon(Icons.filter_5),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'scene_06',
          onPressed: () async {
            shadowmapScene_06();
          },
          child: const Icon(Icons.looks_6),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'scene_07',
          onPressed: () async {
            await M3AppEngine.instance.setScene(PhysicsScene_07());
          },
          child: const Icon(Icons.filter_7),
        ),
        const SizedBox(width: 6),
        FloatingActionButton(
          heroTag: 'sample',
          onPressed: () async {
            await M3AppEngine.instance.setScene(SampleScene());
          },
          child: const Icon(Icons.desktop_mac_sharp),
        ),
      ],
    );
  }
}

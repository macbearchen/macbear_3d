import 'package:flutter/material.dart';

import 'cube_scene.dart';
import 'minimal_scene.dart';
import 'package:macbear_3d/macbear_3d.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  MainApp({Key? key}) : super(key: key);

  @override
  _MainAppState createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _isPause = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final renderEngine = M3AppEngine.instance.renderEngine;

    return MaterialApp(
      home: Scaffold(
        floatingActionButton: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: 'decrement',
              onPressed: () {
                debugPrint('Decrement pressed -----');
                renderEngine.bRenderHelper = !renderEngine.bRenderHelper;
              },
              child: const Icon(Icons.remove),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'increment',
              onPressed: () async {
                debugPrint('increment pressed -----');
                renderEngine.bRenderWireframe = !renderEngine.bRenderWireframe;
              },
              child: const Icon(Icons.add),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'increment',
              onPressed: () async {
                debugPrint('increment pressed -----');
                renderEngine.bRenderShadowmap = !renderEngine.bRenderShadowmap;
              },
              child: const Icon(Icons.lightbulb),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'testScene',
              onPressed: () async {
                // await M3AppEngine.instance.setScene(TestScene());

                setState(() {
                  _isPause = !_isPause;
                });
              },
              child: Icon(_isPause ? Icons.filter_1_sharp : Icons.looks_one),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'cubeScene',
              onPressed: () async {
                await M3AppEngine.instance.setScene(CubeScene());

                setState(() {
                  _isPause = !_isPause;
                });
              },
              child: Icon(_isPause ? Icons.filter_2_sharp : Icons.looks_two),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              heroTag: 'minimalScene',
              onPressed: () async {
                await M3AppEngine.instance.setScene(MinimalScene());

                setState(() {
                  _isPause = !_isPause;
                });
              },
              child: Icon(_isPause ? Icons.filter_3_sharp : Icons.looks_3),
            ),
          ],
        ),
        body: M3View(),
      ),
    );
  }
}

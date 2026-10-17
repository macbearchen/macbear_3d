import 'package:material_ui/material_ui.dart';
import 'package:macbear_3d/macbear_3d.dart';

/// Helper controls toolbar (wireframe, maps, info/helpers, normal map, occlusion, camera, light, brightness slider)
class M3HelperControlWidget extends StatefulWidget {
  const M3HelperControlWidget({super.key});

  @override
  State<M3HelperControlWidget> createState() => _M3HelperControlWidgetState();
}

class _M3HelperControlWidgetState extends State<M3HelperControlWidget> {
  static const separateWidget = SizedBox(width: 2, height: 2);

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

  @override
  Widget build(BuildContext context) {
    final renderEngine = M3AppEngine.instance.renderEngine;
    final debugOptions = renderEngine.options.debug;
    final scene = M3AppEngine.instance.activeScene;
    if (scene == null) {
      return const SizedBox.shrink();
    }

    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          FloatingActionButton.small(
            heroTag: 'wireframe',
            backgroundColor: debugOptions.wireframe ? Colors.lightGreen : null,
            onPressed: () {
              setState(() {
                debugOptions.wireframe = !debugOptions.wireframe;
              });
            },
            child: const Icon(Icons.grid_4x4_sharp),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'map',
            backgroundColor: debugOptions.showMaps ? Colors.lightGreen : null,
            onPressed: () {
              setState(() {
                debugOptions.showMaps = !debugOptions.showMaps;
              });
            },
            child: const Icon(Icons.map),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'info',
            backgroundColor: debugOptions.showHelpers != M3HelperType.none ? Colors.cyan : null,
            onPressed: () {
              setState(() {
                final current = debugOptions.showHelpers;
                final next = M3HelperType.values[(current.index + 1) % M3HelperType.values.length];
                debugOptions.showHelpers = next;
              });
            },
            child: debugOptions.showHelpers == M3HelperType.none
                ? const Icon(Icons.info)
                : Text(
                    debugOptions.showHelpers == M3HelperType.entity
                        ? 'Ent'
                        : (debugOptions.showHelpers == M3HelperType.subMesh ? 'Sub' : 'Both'),
                    style: const TextStyle(fontSize: 10),
                  ),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'normalmap',
            backgroundColor: renderEngine.options.useNormalMap ? Colors.tealAccent.shade700 : null,
            onPressed: () {
              setState(() {
                renderEngine.options.useNormalMap = !renderEngine.options.useNormalMap;
              });
            },
            child: const Text('NRM', style: TextStyle(fontSize: 10)),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'occlusion',
            backgroundColor: renderEngine.options.useOcclusion ? Colors.tealAccent.shade700 : null,
            onPressed: () {
              setState(() {
                renderEngine.options.useOcclusion = !renderEngine.options.useOcclusion;
              });
            },
            child: const Text('AO', style: TextStyle(fontSize: 10)),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'camera',
            backgroundColor: debugOptions.showCamera ? Colors.lightGreen : null,
            onPressed: () {
              setState(() {
                debugOptions.showCamera = !debugOptions.showCamera;
              });
            },
            child: const Icon(Icons.videocam_outlined),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'light',
            backgroundColor: debugOptions.showLight ? Colors.lightGreen : null,
            onPressed: () {
              setState(() {
                debugOptions.showLight = !debugOptions.showLight;
              });
            },
            child: Icon(debugOptions.showLight ? Icons.lightbulb_sharp : Icons.lightbulb_outline),
          ),
        ],
      ),
    );
  }
}

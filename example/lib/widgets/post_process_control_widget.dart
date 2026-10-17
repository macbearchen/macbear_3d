import 'package:material_ui/material_ui.dart';
import 'package:macbear_3d/macbear_3d.dart';

/// Post-processing controls toolbar (FXAA, Bloom, Tonemap)
class M3PostProcessControlWidget extends StatefulWidget {
  const M3PostProcessControlWidget({super.key});

  @override
  State<M3PostProcessControlWidget> createState() => _M3PostProcessControlWidgetState();
}

class _M3PostProcessControlWidgetState extends State<M3PostProcessControlWidget> {
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
    final options = renderEngine.options;

    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'planar',
            backgroundColor: options.usePlanarReflection ? Colors.amber : null,
            onPressed: () {
              setState(() {
                options.usePlanarReflection = !options.usePlanarReflection;
              });
            },
            child: const Text('refl', style: TextStyle(fontSize: 10)),
          ),
          SizedBox(width: 8, height: 8),
          FloatingActionButton.small(
            heroTag: 'fxaa',
            backgroundColor: options.useFxaa ? Colors.amber : null,
            onPressed: () {
              setState(() {
                options.useFxaa = !options.useFxaa;
              });
            },
            child: const Text('fxaa', style: TextStyle(fontSize: 10)),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'bloom',
            backgroundColor: options.useBloom ? Colors.amber : null,
            onPressed: () {
              setState(() {
                options.useBloom = !options.useBloom;
              });
            },
            child: const Text('bloom', style: TextStyle(fontSize: 10)),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'tonemap',
            backgroundColor: options.tonemapMode != M3TonemapMode.none ? Colors.amber : null,
            onPressed: () {
              setState(() {
                final nextIndex = (options.tonemapMode.index + 1) % M3TonemapMode.values.length;
                options.tonemapMode = M3TonemapMode.values[nextIndex];
              });
            },
            child: Text(options.tonemapMode.name, style: const TextStyle(fontSize: 10)),
          ),
        ],
      ),
    );
  }
}

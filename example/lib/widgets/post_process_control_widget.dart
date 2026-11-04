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
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (options.useDof) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSliderRow(
                    context: context,
                    label: 'd',
                    valueStr: options.dofFocusDistance.toStringAsFixed(1),
                    value: options.dofFocusDistance.clamp(0.5, 100.0),
                    min: 0.5,
                    max: 100.0,
                    onChanged: (val) {
                      setState(() {
                        options.dofFocusDistance = val;
                      });
                    },
                  ),
                  _buildSliderRow(
                    context: context,
                    label: 'r',
                    valueStr: options.dofFocusRange.toStringAsFixed(1),
                    value: options.dofFocusRange.clamp(0.1, 50.0),
                    min: 0.1,
                    max: 50.0,
                    onChanged: (val) {
                      setState(() {
                        options.dofFocusRange = val;
                      });
                    },
                  ),
                  _buildSliderRow(
                    context: context,
                    label: 'bokeh',
                    valueStr: options.dofBokehRadius.toStringAsFixed(1),
                    value: options.dofBokehRadius.clamp(0.0, 30.0),
                    min: 0.0,
                    max: 30.0,
                    onChanged: (val) {
                      setState(() {
                        options.dofBokehRadius = val;
                      });
                    },
                  ),
                ],
              ),
            ),
            separateWidget,
          ],
          FloatingActionButton.small(
            heroTag: 'dof',
            backgroundColor: options.useDof ? Colors.amber : null,
            onPressed: () {
              setState(() {
                options.useDof = !options.useDof;
              });
            },
            child: const Text('DOF', style: TextStyle(fontSize: 10)),
          ),
          SizedBox(width: 8, height: 8),
          FloatingActionButton.small(
            heroTag: 'postprocess',
            backgroundColor: options.usePostProcess ? Colors.yellow : null,
            onPressed: () {
              setState(() {
                options.usePostProcess = !options.usePostProcess;
              });
            },
            child: const Text('post', style: TextStyle(fontSize: 12)),
          ),
          separateWidget,
          FloatingActionButton.small(
            heroTag: 'planar',
            backgroundColor: options.usePlanarReflection ? Colors.purpleAccent : null,
            onPressed: () {
              setState(() {
                options.usePlanarReflection = !options.usePlanarReflection;
              });
            },
            child: const Text('reflect', style: TextStyle(fontSize: 8)),
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
            child: const Text('FXAA', style: TextStyle(fontSize: 10)),
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

  Widget _buildSliderRow({
    required BuildContext context,
    required String label,
    required String valueStr,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return SizedBox(
      height: 12,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 50,
            child: Text('$label=$valueStr', style: const TextStyle(color: Colors.white, fontSize: 9)),
          ),
          SizedBox(
            width: 50,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
              ),
              child: Slider(
                value: value,
                min: min,
                max: max,
                activeColor: Colors.amber,
                inactiveColor: Colors.white24,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

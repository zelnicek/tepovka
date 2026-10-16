import 'package:flutter/material.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/widgets/info_widgets.dart';

/// Where a heart rate falls between 30 and 220 bpm, on a red–green–red bar.
///
/// The marker is placed from the bar's own width. The older bars used the
/// screen width, which put the marker in the wrong spot inside padding or a
/// dialog, and printed the value in the middle of the bar regardless of where
/// the marker was.
class BpmScale extends StatelessWidget {
  const BpmScale({super.key, required this.bpm});

  final double bpm;

  static const double _lo = 30;
  static const double _hi = 220;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final double fraction =
        ((bpm.clamp(_lo, _hi) - _lo) / (_hi - _lo)).toDouble();
    final TextStyle labelStyle =
        TextStyle(fontSize: r.fontCaption, color: kInfoSecondaryText);
    return ExcludeSemantics(
      child: LayoutBuilder(builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double marker = 6;
        final double x =
            (fraction * width).clamp(marker / 2, width - marker / 2);
        return Column(
          children: [
            SizedBox(
              height: 12,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.red,
                            Colors.orange,
                            Colors.green,
                            Colors.orange,
                            Colors.red,
                          ],
                          stops: [0.0, 0.11, 0.20, 0.55, 0.75],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x - marker / 2,
                    top: -4,
                    bottom: -4,
                    child: Container(
                      width: marker,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.black87, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.spaceXs + 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_lo.toInt()}', style: labelStyle),
                Text('${_hi.toInt()}', style: labelStyle),
              ],
            ),
          ],
        );
      }),
    );
  }
}

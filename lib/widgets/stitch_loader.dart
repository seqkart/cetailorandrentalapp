import 'package:flutter/material.dart';

import '../theme_colors.dart';
import 'stitch_ring_painter.dart';

/// Small reusable loading indicator: a glow travels around the stitched ring.
/// Drop it anywhere a CircularProgressIndicator would go.
class StitchLoader extends StatefulWidget {
  const StitchLoader({super.key, this.size = 72, this.showMonogram = true});
  final double size;
  final bool showMonogram;

  @override
  State<StitchLoader> createState() => _StitchLoaderState();
}

class _StitchLoaderState extends State<StitchLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(widget.size),
              painter: StitchRingPainter(highlight: _c.value),
            ),
            if (widget.showMonogram)
              Text(
                'CE',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: widget.size * 0.29,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                  color: kIvory,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen loading page.
class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key, this.message = 'Loading'});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSplashBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const StitchLoader(size: 150),
            const SizedBox(height: 28),
            Text(
              message.toUpperCase().split('').join(' '),
              style: const TextStyle(
                fontFamily: 'serif',
                fontSize: 13,
                letterSpacing: 2,
                color: Color(0xFFBEAFE6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

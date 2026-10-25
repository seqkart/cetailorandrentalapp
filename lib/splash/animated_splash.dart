import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme_colors.dart';
import '../l10n/app_strings.dart';
import '../widgets/stitch_ring_painter.dart';

/// Animated splash: a needle sews the ring, then CE, the name and
/// "TAILORING & RENTALS" fade in. Calls [onFinished] when done.
///
/// Frame 0 is a plain [kSplashBg] screen, so it hands over seamlessly from
/// the native splash created by flutter_native_splash.
class AnimatedSplash extends StatefulWidget {
  const AnimatedSplash({super.key, required this.onFinished});
  final VoidCallback onFinished;

  @override
  State<AnimatedSplash> createState() => _AnimatedSplashState();
}

class _AnimatedSplashState extends State<AnimatedSplash>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 3200);
  static const _fallbackDuration = Duration(seconds: 5);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _duration,
  );
  Timer? _fallbackTimer;
  bool _finished = false;

  Animation<double> _seg(double a, double b, Curve curve) => CurvedAnimation(
    parent: _c,
    curve: Interval(a, b, curve: curve),
  );

  late final Animation<double> _glow = _seg(0.0, 0.5, Curves.easeOut);
  late final Animation<double> _ring = _seg(0.0, 0.55, Curves.easeInOutCubic);
  late final Animation<double> _mono = _seg(0.42, 0.65, Curves.easeOut);
  late final Animation<double> _name = _seg(0.60, 0.82, Curves.easeOutCubic);
  late final Animation<double> _tag = _seg(0.76, 1.0, Curves.easeOut);

  @override
  void initState() {
    super.initState();
    _fallbackTimer = Timer(_fallbackDuration, _finish);
    _c.forward().whenComplete(_finish);
  }

  void _finish() {
    if (_finished || !mounted) return;
    _finished = true;
    _fallbackTimer?.cancel();
    widget.onFinished();
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final ringSize = math.min(width * 0.62, 300.0);

    return Scaffold(
      backgroundColor: kSplashBg,
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final needle = (1 - ((_ring.value - 0.92) / 0.08))
              .clamp(0.0, 1.0)
              .toDouble();
          return Stack(
            fit: StackFit.expand,
            children: [
              Opacity(
                opacity: _glow.value,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0, -0.2),
                      radius: 0.95,
                      colors: [Color(0xFF5A2FA8), Color(0x002A1A5E)],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size.square(ringSize),
                            painter: StitchRingPainter(
                              progress: _ring.value,
                              needleOpacity: needle,
                            ),
                          ),
                          Opacity(
                            opacity: _mono.value,
                            child: Text(
                              'CE',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: ringSize * 0.29,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 2,
                                color: kIvory,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: ringSize * 0.08),
                    Opacity(
                      opacity: _name.value,
                      child: Transform.translate(
                        offset: Offset(0, 12 * (1 - _name.value)),
                        child: Text(
                          'Creative Ease',
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 34,
                            fontWeight: FontWeight.w500,
                            color: kIvory,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: _tag.value,
                      child: Text(
                        localizedUiText(context, 'TAILORING & RENTALS'),
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 4,
                          color: kGold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

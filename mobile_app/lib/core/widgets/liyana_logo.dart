import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LiyanaLogo extends StatelessWidget {
  const LiyanaLogo({
    super.key,
    this.size = 140,
    this.showWordmark = false,
  });

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    if (showWordmark) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: SvgPicture.asset(
              'assets/images/liyana_logoo.svg',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'LIYANA',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w300,
              letterSpacing: 7,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'YOUR INTELLIGENT COMPANION',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              letterSpacing: 3.5,
            ),
          ),
        ],
      );
    }

    return SvgPicture.asset(
      'assets/images/liyana_logoo.svg',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

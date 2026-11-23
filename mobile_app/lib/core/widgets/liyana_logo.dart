import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// The compact Liyana mark: a violet gradient tile with a sparkle. Used for
/// small spots like the chat avatar and the app bar.
class LiyanaMark extends StatelessWidget {
  const LiyanaMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: size * 0.3,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size * 0.52),
    );
  }
}

/// The full Liyana logo artwork (it has its own dark background), shown as
/// a rounded brand card. Used on the splash and sign-in screens.
class LiyanaLogo extends StatelessWidget {
  const LiyanaLogo({super.key, this.width = 180});

  final double width;

  @override
  Widget build(BuildContext context) {
    // The artwork is 3:2 and includes the "LIYANA" wordmark.
    return Container(
      width: width,
      height: width * 2 / 3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: SvgPicture.asset(
        'assets/images/liyana_logoo.svg',
        fit: BoxFit.cover,
      ),
    );
  }
}

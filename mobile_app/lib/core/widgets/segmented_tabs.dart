import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A pill-shaped two-way switch for screens with tabs (e.g. To do / Done),
/// used as an AppBar `bottom`.
class SegmentedTabs extends StatelessWidget implements PreferredSizeWidget {
  const SegmentedTabs({
    super.key,
    required this.controller,
    required this.labels,
  });

  final TabController controller;
  final List<String> labels;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(14),
        ),
        child: TabBar(
          controller: controller,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          splashBorderRadius: BorderRadius.circular(10),
          indicator: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x141B1D29),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [for (final label in labels) Tab(text: label, height: 36)],
        ),
      ),
    );
  }
}

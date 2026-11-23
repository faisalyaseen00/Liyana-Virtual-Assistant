import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/liyana_logo.dart';

/// One chat message. The user's messages sit on the right in the brand
/// colour; Liyana's sit on the left in white, next to her avatar.
class ChatBubble extends StatelessWidget {
  final String message;
  final bool isUser;

  /// A local error reply (not saved on the server).
  final bool isError;

  /// Show Liyana's avatar (only on the first of several replies in a row).
  final bool showAvatar;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.isError = false,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.76;

    final Color background;
    final Color foreground;
    final Border? border;
    if (isUser) {
      background = AppColors.primary;
      foreground = Colors.white;
      border = null;
    } else if (isError) {
      background = AppColors.dangerSoft;
      foreground = AppColors.danger;
      border = null;
    } else {
      background = AppColors.surface;
      foreground = AppColors.textPrimary;
      border = Border.all(color: AppColors.outline);
    }

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 15),
      decoration: BoxDecoration(
        color: background,
        border: border,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isUser ? 20 : 6),
          bottomRight: Radius.circular(isUser ? 6 : 20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isError) ...[
            Icon(Icons.error_outline_rounded, size: 18, color: foreground),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: SelectableText(
              message,
              style: TextStyle(color: foreground, fontSize: 15, height: 1.45),
            ),
          ),
        ],
      ),
    );

    if (isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 48),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 10, top: showAvatar ? 4 : 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 30,
            child: showAvatar ? const LiyanaMark(size: 28) : null,
          ),
          const SizedBox(width: 8),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

/// Liyana's "typing" bubble with three pulsing dots.
class TypingBubble extends StatelessWidget {
  const TypingBubble({super.key, required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Row(
        children: [
          const LiyanaMark(size: 28),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.outline),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
            ),
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 7,
                      height: 7,
                      margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(
                          // Each dot is a little out of step with the last.
                          alpha: 0.25 + 0.6 * ((animation.value + i / 3) % 1.0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

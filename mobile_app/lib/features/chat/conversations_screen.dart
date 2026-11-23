import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/ui_kit.dart';
import 'chat_provider.dart';
import 'conversation_model.dart';

/// The list of past chats: tap to open, long-press to rename, swipe to delete.
class ConversationsScreen extends StatelessWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final conversations = chat.conversations;

    return Scaffold(
      appBar: AppBar(title: const Text('Chats')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          chat.startNewConversation();
          Navigator.pop(context);
        },
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('New chat'),
      ),
      body: RefreshIndicator(
        onRefresh: chat.loadConversations,
        child: conversations.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 480,
                    child: chat.isLoadingConversations
                        ? const Center(child: CircularProgressIndicator())
                        : EmptyState(
                            icon: Icons.forum_outlined,
                            title: chat.errorMessage == null
                                ? 'No chats yet'
                                : 'Could not load your chats',
                            message:
                                chat.errorMessage ??
                                'Your conversations with Liyana will appear here.',
                          ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                itemCount: conversations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) => _ConversationTile(
                  conversation: conversations[index],
                  isOpen: conversations[index].id == chat.conversationId,
                ),
              ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.isOpen});

  final Conversation conversation;
  final bool isOpen;

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this chat?'),
        content: Text(
          '"${conversation.title}" and all its messages will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    final chat = context.read<ChatProvider>();
    final deleted = await chat.deleteConversation(conversation.id);
    if (!deleted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.errorMessage ?? 'Could not delete.')),
      );
    }
    return deleted;
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: conversation.title);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 255,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.trim().isEmpty || !context.mounted) return;

    final chat = context.read<ChatProvider>();
    final renamed = await chat.renameConversation(conversation.id, title);
    if (!renamed && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chat.errorMessage ?? 'Could not rename.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.danger,
        ),
      ),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        color: isOpen ? AppColors.primarySoft : AppColors.surface,
        borderColor: isOpen
            ? AppColors.primary.withValues(alpha: 0.35)
            : AppColors.outline,
        onTap: () {
          context.read<ChatProvider>().openConversation(conversation.id);
          Navigator.pop(context);
        },
        child: Row(
          children: [
            SoftIcon(
              icon: Icons.chat_bubble_outline_rounded,
              color: isOpen ? AppColors.primaryDark : AppColors.primary,
              background: isOpen ? AppColors.surface : AppColors.primarySoft,
              size: 40,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isOpen
                        ? 'Open now · ${formatChatTime(conversation.lastMessageAt)}'
                        : formatChatTime(conversation.lastMessageAt),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Rename',
              icon: const Icon(Icons.edit_outlined, size: 20),
              color: AppColors.textMuted,
              onPressed: () => _rename(context),
            ),
          ],
        ),
      ),
    );
  }
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "14:05" today, "Yesterday", or "23 Nov" / "23 Nov 2025".
String formatChatTime(DateTime time, {DateTime? now}) {
  final today = DateUtils.dateOnly(now ?? DateTime.now());
  final day = DateUtils.dateOnly(time);
  final diff = today.difference(day).inDays;

  if (diff == 0) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
  if (diff == 1) return 'Yesterday';

  final text = '${day.day} ${_months[day.month - 1]}';
  return day.year == today.year ? text : '$text ${day.year}';
}

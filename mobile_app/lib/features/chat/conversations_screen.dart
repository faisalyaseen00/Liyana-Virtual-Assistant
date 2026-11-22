import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
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
      appBar: AppBar(
        title: const Text('CHATS'),
        actions: [
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              chat.startNewConversation();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: chat.loadConversations,
        child: conversations.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: 400,
                    child: Center(
                      child: chat.isLoadingConversations
                          ? const CircularProgressIndicator(
                              color: AppColors.primary,
                            )
                          : Text(
                              chat.errorMessage ?? 'No chats yet',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: conversations.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.outline),
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
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
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
        color: AppColors.danger.withValues(alpha: 0.25),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      child: ListTile(
        selected: isOpen,
        selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
        leading: Icon(
          Icons.chat_bubble_outline,
          color: isOpen ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(
          conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white),
        ),
        subtitle: Text(
          formatChatTime(conversation.lastMessageAt),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        onTap: () {
          context.read<ChatProvider>().openConversation(conversation.id);
          Navigator.pop(context);
        },
        onLongPress: () => _rename(context),
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

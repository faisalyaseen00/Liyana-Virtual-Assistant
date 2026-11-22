import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import 'reminder_format.dart';
import 'reminder_provider.dart';

class AddReminderSheet extends StatefulWidget {
  const AddReminderSheet({super.key});

  @override
  State<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<AddReminderSheet> {
  final TextEditingController _titleController = TextEditingController();
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  TimeOfDay? _time;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Theme _pickerTheme(BuildContext context, Widget? child) => Theme(
    data: ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        surface: AppColors.surface,
      ),
    ),
    child: child!,
  );

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: _pickerTheme,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty || _saving) return;

    setState(() => _saving = true);
    final provider = context.read<ReminderProvider>();
    final saved = await provider.addReminder(
      title: title,
      date: _date,
      time: _time,
    );
    if (!mounted) return;

    if (saved) {
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Could not add the reminder.'),
        ),
      );
    }
  }

  Widget _pickerButton({
    required IconData icon,
    required String label,
    required bool isSet,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSet
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.outline, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'NEW REMINDER',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Remind me to… *'),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _pickerButton(
                icon: Icons.calendar_today,
                label: formatReminderDate(_date),
                isSet: true,
                onTap: _pickDate,
              ),
              const SizedBox(width: 12),
              _pickerButton(
                icon: Icons.access_time,
                label: _time == null
                    ? 'Time (optional)'
                    : _time!.format(context),
                isSet: _time != null,
                onTap: _pickTime,
                onClear: _time == null
                    ? null
                    : () => setState(() => _time = null),
              ),
            ],
          ),
          if (_time == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Without a time, you will be notified at 9:00.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'ADD REMINDER',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

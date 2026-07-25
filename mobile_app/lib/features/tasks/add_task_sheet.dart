import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import 'task_provider.dart';

class AddTaskSheet extends StatefulWidget {
  const AddTaskSheet({super.key});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String _priority = 'Medium';
  DateTime? _deadline;

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF00F5FF),
              surface: Color(0xFF12121A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _submit() {
    if (_titleController.text.trim().isEmpty) return;
    Provider.of<TaskProvider>(context, listen: false).addTask(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      priority: _priority,
      deadline: _deadline,
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
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
        color: Color(0xFF12121A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF00F5FF), width: 0.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'NEW TASK',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF00F5FF),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Task title *',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                borderSide: const BorderSide(color: Color(0xFF00F5FF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                borderSide: const BorderSide(color: Color(0xFF7B2FFF), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            style: const TextStyle(color: Colors.white),
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Description (optional)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                borderSide: const BorderSide(color: Color(0xFF00F5FF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                borderSide: const BorderSide(color: Color(0xFF7B2FFF), width: 2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Priority:',
                  style: TextStyle(color: Colors.white70)),
              const SizedBox(width: 12),
              ..._priorities.map((p) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _priority == p
                              ? _priorityColor(p)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _priorityColor(p)),
                        ),
                        child: Text(p,
                            style: TextStyle(
                              color: _priority == p
                                  ? Colors.black
                                  : _priorityColor(p),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            )),
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickDeadline,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
                border: const BorderSide(color: Color(0xFF00F5FF)) as Border?,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      color: Color(0xFF00F5FF), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _deadline == null
                        ? 'Set deadline (optional)'
                        : '${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                    style: TextStyle(
                      color: _deadline == null
                          ? Colors.white.withOpacity(0.4)
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00F5FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.borderRadius),
              ),
            ),
            child: const Text(
              'ADD TASK',
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

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return const Color(0xFFFF4444);
      case 'Low':
        return const Color(0xFF44FF88);
      default:
        return const Color(0xFFFFAA00);
    }
  }
}
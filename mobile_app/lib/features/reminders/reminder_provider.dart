import 'package:flutter/material.dart';

import '../../services/reminder_notifier.dart';
import 'reminder_model.dart';
import 'reminder_service.dart';

/// The signed-in user's reminders, stored on the backend, with phone
/// notifications kept in step after every change.
class ReminderProvider extends ChangeNotifier {
  ReminderProvider({ReminderService? service, ReminderNotifier? notifier})
    : _service = service ?? ReminderService(),
      _notifier = notifier ?? NoopReminderNotifier();

  final ReminderService _service;
  final ReminderNotifier _notifier;

  List<Reminder> _reminders = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Reminder> get allReminders => List.unmodifiable(_reminders);

  /// Not done yet, soonest first.
  List<Reminder> get upcomingReminders =>
      _reminders.where((r) => !r.isDone).toList()
        ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

  /// Done, most recent first.
  List<Reminder> get doneReminders =>
      _reminders.where((r) => r.isDone).toList()
        ..sort((a, b) => b.dueAt.compareTo(a.dueAt));

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadReminders() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _reminders = await _service.fetchReminders();
      await _notifier.sync(_reminders);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns true when the reminder was saved.
  Future<bool> addReminder({
    required String title,
    required DateTime date,
    TimeOfDay? time,
  }) async {
    try {
      final reminder = await _service.createReminder(
        title: title,
        date: date,
        time: time,
      );
      _reminders = [..._reminders, reminder];
      _errorMessage = null;
      notifyListeners();
      await _notifier.sync(_reminders);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> toggleDone(String id) async {
    final reminder = _find(id);
    if (reminder == null) return;

    final newValue = !reminder.isDone;
    reminder.isDone = newValue;
    notifyListeners();

    try {
      final saved = await _service.setDone(id, newValue);
      final index = _reminders.indexWhere((r) => r.id == id);
      if (index != -1) _reminders[index] = saved;
      _errorMessage = null;
    } catch (e) {
      reminder.isDone = !newValue;
      _errorMessage = e.toString();
    }
    notifyListeners();
    await _notifier.sync(_reminders);
  }

  Future<void> deleteReminder(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;

    final removed = _reminders.removeAt(index);
    notifyListeners();

    try {
      await _service.deleteReminder(id);
      _errorMessage = null;
    } catch (e) {
      _reminders.insert(index.clamp(0, _reminders.length), removed);
      _errorMessage = e.toString();
    }
    notifyListeners();
    await _notifier.sync(_reminders);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Forget everything and cancel notifications, e.g. on logout.
  Future<void> clear() async {
    _reminders = [];
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
    await _notifier.cancelAll();
  }

  Reminder? _find(String id) {
    for (final reminder in _reminders) {
      if (reminder.id == id) return reminder;
    }
    return null;
  }
}

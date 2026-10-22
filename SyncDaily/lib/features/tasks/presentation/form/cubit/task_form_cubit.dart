import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/projects/domain/entities/project.dart';
import 'package:sync_daily/features/projects/domain/repositories/project_repository.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';
import 'package:sync_daily/features/tasks/presentation/form/cubit/task_form_state.dart';
import 'package:uuid/uuid.dart';

/// Jam bawaan item berjam yang dibuka dari tanggal Kalender: Acara dan
/// Pengingat mulai 09.00 (acara selesai satu jam setelahnya).
const int _initialStartHour = 9;

/// Menyimpan sub-task yang sedang disusun di form. [id] null berarti sub-task
/// baru; id terisi berarti sub-task yang sudah ada (mode ubah).
class SubtaskDraft {
  final String? id;
  final String title;

  const SubtaskDraft({this.id, required this.title});
}

/// Cubit form tugas/acara/pengingat/milestone. SEMUA input dan validasi ada di
/// sini; widget hanya menampilkan state dan mengirim event.
class TaskFormCubit extends Cubit<TaskFormState> {
  final TaskRepository _taskRepository;
  final ProjectRepository _projectRepository;
  final DateTime Function() _now;
  final String Function() _newId;

  TaskFormCubit({
    required TaskRepository taskRepository,
    required ProjectRepository projectRepository,
    DateTime Function()? now,
    String Function()? newId,
  })  : _taskRepository = taskRepository,
        _projectRepository = projectRepository,
        _now = now ?? DateTime.now,
        _newId = newId ?? const Uuid().v4,
        super(const TaskFormState());

  StreamSubscription<List<Project>>? _projectsSub;
  bool _userTouchedReminders = false;

  /// Daftar sub-task yang dimuat dari repository (mode ubah), dipakai untuk
  /// merekonsiliasi saat menyimpan.
  List<SubtaskDraft> _subtasks = const [];

  /// Tanggal awal dari Kalender (`?date=`), tanpa jam. Dipakai lagi saat
  /// pengguna mengganti tipe supaya bawaan mengikuti aturan tipe baru. Null
  /// pada form tanpa tanggal awal dan pada mode ubah.
  DateTime? _initialDate;

  /// Dipakai [TaskFormPage] untuk memuat sub-task yang sudah ada.
  List<SubtaskDraft> get subtasks => List.unmodifiable(_subtasks);

  Future<void> init({
    TaskType initialType = TaskType.task,
    String? taskId,
    DateTime? initialDate,
  }) async {
    await _projectsSub?.cancel();
    _projectsSub = _projectRepository.watchProjects().listen(
      (projects) => emit(state.copyWith(projects: projects)),
      onError: (Object error) =>
          emit(state.copyWith(status: TaskFormStatus.error, errorMessage: '$error')),
    );

    if (taskId != null) {
      _userTouchedReminders = true; // editing existing item; don't seed defaults
      await _loadTask(taskId);
    } else {
      _userTouchedReminders = false;
      _applyTypeDefaults(initialType, isEditing: false);
      if (initialDate != null) {
        _applyInitialDate(initialDate);
      }
    }
  }

  /// Mengisi kolom tanggal sesuai tipe (Acara/Pengingat -> Mulai, Tugas/
  /// Milestone -> Tenggat) dengan tanggal awal dari Kalender, memakai aturan
  /// bawaan [TaskType] (lihat [_applyDateDefaults]). Aturan validasi dan simpan
  /// tidak berubah.
  void _applyInitialDate(DateTime initialDate) {
    final date = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    _initialDate = date;
    _applyDateDefaults(state.type, date);
  }

  /// Bawaan tanggal untuk [type] pada [date]:
  /// - Tugas dan Milestone: seharian (tersimpan sebagai tanggal kalender UTC
  ///   lewat `TaskDateUtils`);
  /// - Acara: berjam, 09.00 sampai 10.00;
  /// - Pengingat: berjam, 09.00.
  void _applyDateDefaults(TaskType type, DateTime date) {
    switch (type) {
      case TaskType.task:
      case TaskType.milestone:
        emit(state.copyWith(
          isAllDay: true,
          dueAt: date,
          clearStartAt: true,
          clearEndAt: true,
        ));
      case TaskType.event:
        emit(state.copyWith(
          isAllDay: false,
          startAt: _timeOn(date, _initialStartHour),
          endAt: _timeOn(date, _initialStartHour + 1),
          clearDueAt: true,
        ));
      case TaskType.reminder:
        emit(state.copyWith(
          isAllDay: false,
          startAt: _timeOn(date, _initialStartHour),
          clearEndAt: true,
          clearDueAt: true,
        ));
    }
  }

  static DateTime _timeOn(DateTime date, int hour) =>
      DateTime(date.year, date.month, date.day, hour);

  /// Tanggal acuan yang sedang terisi (tanpa jam), atau null bila belum ada.
  DateTime? _anchorDay() {
    final anchor = state.anchorDate;
    if (anchor == null) {
      return null;
    }
    return DateTime(anchor.year, anchor.month, anchor.day);
  }

  Future<void> _loadTask(String taskId) async {
    final task = await _taskRepository.getTask(taskId);
    if (task == null) {
      emit(state.copyWith(
        status: TaskFormStatus.error,
        errorMessage: AppStrings.loadFailedTitle,
      ));
      return;
    }

    final reminderRows = await _taskRepository.getReminders(taskId);
    final recurrence = await _taskRepository.getRecurrence(taskId);
    final all = await _taskRepository.watchAllTasks().first;

    _subtasks = all
        .where((t) => t.parentTaskId == taskId && t.type == TaskType.task)
        .map((t) => SubtaskDraft(id: t.id, title: t.title))
        .toList();

    final reminderSet = <ReminderOption>{};
    for (final r in reminderRows) {
      for (final option in ReminderOption.values) {
        if (option.toOffsetMinutes() == r.offsetMinutes) {
          reminderSet.add(option);
        }
      }
    }

    var recurrenceOption = RecurrenceOption.none;
    if (recurrence != null) {
      switch (recurrence.frequency) {
        case RecurrenceFrequency.daily:
          recurrenceOption = RecurrenceOption.daily;
        case RecurrenceFrequency.weekly:
          recurrenceOption = RecurrenceOption.weekly;
        case RecurrenceFrequency.monthly:
        case RecurrenceFrequency.yearly:
          recurrenceOption = RecurrenceOption.monthly;
      }
    }

    _userTouchedReminders = true;
    emit(state.copyWith(
      status: TaskFormStatus.idle,
      isEditing: true,
      type: task.type,
      title: task.title,
      description: task.description ?? '',
      priority: task.priority,
      projectId: task.projectId,
      subtaskTitles: _subtasks.map((s) => s.title).toList(),
      recurrence: recurrenceOption,
      reminders: reminderSet,
      isAllDay: task.isAllDay,
      startAt: task.startAt,
      endAt: task.endAt,
      dueAt: task.dueAt,
      clearProject: task.projectId == null,
      clearError: true,
    ));
  }

  /// Menyusun ulang kolom yang dipakai sesuai tipe (lihat pemetaan F4a).
  void _applyTypeDefaults(TaskType type, {required bool isEditing}) {
    switch (type) {
      case TaskType.task:
        emit(state.copyWith(
          type: type,
          isEditing: isEditing,
          isAllDay: false,
          clearStartAt: true,
          clearEndAt: true,
          clearError: true,
        ));
      case TaskType.event:
        emit(state.copyWith(
          type: type,
          isEditing: isEditing,
          isAllDay: false,
          clearDueAt: true,
          clearError: true,
        ));
      case TaskType.reminder:
        emit(state.copyWith(
          type: type,
          isEditing: isEditing,
          isAllDay: false,
          clearEndAt: true,
          clearDueAt: true,
          reminders: {ReminderOption.onTime, ...state.reminders},
          clearError: true,
        ));
      case TaskType.milestone:
        emit(state.copyWith(
          type: type,
          isEditing: isEditing,
          isAllDay: true,
          clearStartAt: true,
          clearEndAt: true,
          clearError: true,
        ));
    }
  }

  void setType(TaskType type) {
    // Pada form yang dibuka dari tanggal Kalender, bawaan tanggal mengikuti
    // aturan tipe baru (mis. Acara 09.00-10.00, bukan sisa 00.00).
    final base = _initialDate == null ? null : (_anchorDay() ?? _initialDate!);
    _applyTypeDefaults(type, isEditing: state.isEditing);
    if (base != null) {
      _applyDateDefaults(type, base);
    }
  }

  void setTitle(String value) => emit(state.copyWith(title: value));

  void setDescription(String value) => emit(state.copyWith(description: value));

  void setPriority(TaskPriority value) => emit(state.copyWith(priority: value));

  void setProjectId(String? value) => emit(value == null
      ? state.copyWith(clearProject: true)
      : state.copyWith(projectId: value));

  void addSubtask(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _subtasks = [..._subtasks, SubtaskDraft(title: trimmed)];
    emit(state.copyWith(subtaskTitles: _subtasks.map((s) => s.title).toList()));
  }

  void updateSubtask(int index, String title) {
    final trimmed = title.trim();
    if (index < 0 || index >= _subtasks.length || trimmed.isEmpty) {
      return;
    }
    final list = [..._subtasks];
    list[index] = SubtaskDraft(id: list[index].id, title: trimmed);
    _subtasks = list;
    emit(state.copyWith(subtaskTitles: _subtasks.map((s) => s.title).toList()));
  }

  void removeSubtask(int index) {
    if (index < 0 || index >= _subtasks.length) {
      return;
    }
    final list = [..._subtasks]..removeAt(index);
    _subtasks = list;
    emit(state.copyWith(subtaskTitles: _subtasks.map((s) => s.title).toList()));
  }

  void setRecurrence(RecurrenceOption value) =>
      emit(state.copyWith(recurrence: value));

  void toggleReminder(ReminderOption value) {
    _userTouchedReminders = true;
    if (_userTouchedReminders) {}
    final set = {...state.reminders};
    if (!set.remove(value)) {
      set.add(value);
    }
    emit(state.copyWith(reminders: set));
  }

  void setIsAllDay(bool value) => emit(state.copyWith(isAllDay: value));

  /// Mengubah waktu Mulai.
  ///
  /// Khusus tipe Acara: bila Selesai sudah terisi, Selesai ikut bergeser dengan
  /// selisih yang sama seperti sebelum Mulai diubah (durasi untuk acara berjam,
  /// selisih hari kalender untuk acara seharian). Penggeseran hanya terjadi
  /// karena perubahan dari pengguna; memuat form dan mengganti tipe tidak
  /// menggeser apa pun.
  void setStartAt(DateTime? value) {
    final previous = state.startAt;
    if (value == null) {
      emit(state.copyWith(clearStartAt: true));
      return;
    }
    emit(state.copyWith(startAt: value));
    if (previous != null) {
      _shiftEndWithStart(previous, value);
    }
  }

  /// Menggeser Selesai mengikuti perubahan Mulai pada Acara.
  void _shiftEndWithStart(DateTime previous, DateTime value) {
    if (state.type != TaskType.event) {
      return;
    }
    final end = state.endAt;
    if (end == null) {
      return;
    }
    if (state.isAllDay) {
      final days = _calendarDay(value) - _calendarDay(previous);
      if (days == 0) {
        return;
      }
      emit(state.copyWith(
        endAt: _dateOnly(end).add(Duration(days: days)),
      ));
      return;
    }
    // Acara berjam: durasi (selisih waktu) tetap.
    emit(state.copyWith(endAt: value.add(end.difference(previous))));
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Hitungan hari kalender dari komponen tanggal, bebas zona waktu.
  static int _calendarDay(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day)
          .millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  void setEndAt(DateTime? value) => emit(value == null
      ? state.copyWith(clearEndAt: true)
      : state.copyWith(endAt: value));

  void setDueAt(DateTime? value) => emit(value == null
      ? state.copyWith(clearDueAt: true)
      : state.copyWith(dueAt: value));

  /// True bila waktu selesai tidak valid (sebelum mulai).
  bool _isEndBeforeStart() {
    final start = state.startAt;
    final end = state.endAt;
    if (start == null || end == null) {
      return false;
    }
    if (state.isAllDay) {
      final s = DateTime(start.year, start.month, start.day);
      final e = DateTime(end.year, end.month, end.day);
      return e.isBefore(s);
    }
    return end.isBefore(start);
  }

  /// Menyimpan. [editingTaskId] null berarti membuat item baru.
  Future<void> save({String? editingTaskId}) async {
    if (state.title.trim().isEmpty) {
      emit(state.copyWith(errorMessage: AppStrings.titleRequired));
      return;
    }

    // Tanggal wajib per tipe (lihat pemetaan F4a): Acara butuh Mulai (dan
    // Selesai untuk acara berjam); Pengingat butuh Mulai; Milestone butuh
    // Tenggat. Tugas boleh tanpa tanggal.
    switch (state.type) {
      case TaskType.event:
        if (state.startAt == null) {
          emit(state.copyWith(errorMessage: AppStrings.startRequired));
          return;
        }
        if (!state.isAllDay && state.endAt == null) {
          emit(state.copyWith(errorMessage: AppStrings.endRequired));
          return;
        }
        if (_isEndBeforeStart()) {
          emit(state.copyWith(errorMessage: AppStrings.endBeforeStart));
          return;
        }
      case TaskType.reminder:
        if (state.startAt == null) {
          emit(state.copyWith(errorMessage: AppStrings.startRequired));
          return;
        }
      case TaskType.milestone:
        if (state.dueAt == null) {
          emit(state.copyWith(errorMessage: AppStrings.dueRequired));
          return;
        }
      case TaskType.task:
        break;
    }

    emit(state.copyWith(status: TaskFormStatus.saving, clearError: true));

    final now = _now().toUtc();
    final id = editingTaskId ?? _newId();

    final start = _storageDate(state.startAt);
    final end = _storageDate(state.endAt);
    final due = _storageDate(state.dueAt);

    final task = Task(
      id: id,
      projectId: state.projectId,
      parentTaskId: null,
      title: state.title.trim(),
      description:
          state.description.trim().isEmpty ? null : state.description.trim(),
      type: state.type,
      status: TaskStatus.todo,
      priority: state.priority,
      startAt: start,
      endAt: end,
      dueAt: due,
      isAllDay: state.isAllDay,
      createdAt: now,
      updatedAt: now,
    );

    try {
      if (editingTaskId != null) {
        final existing = await _taskRepository.getTask(editingTaskId);
        await _taskRepository.upsertTask(Task(
          id: task.id,
          projectId: task.projectId,
          parentTaskId: task.parentTaskId,
          title: task.title,
          description: task.description,
          type: task.type,
          status: existing?.status ?? task.status,
          priority: task.priority,
          startAt: task.startAt,
          endAt: task.endAt,
          dueAt: task.dueAt,
          isAllDay: task.isAllDay,
          completedAt: existing?.completedAt,
          remoteId: existing?.remoteId,
          version: existing?.version ?? task.version,
          createdAt: existing?.createdAt ?? task.createdAt,
          updatedAt: now,
          deletedAt: existing?.deletedAt,
        ));
      } else {
        await _taskRepository.upsertTask(task);
      }

      await _saveReminders(id, now);
      await _saveRecurrence(id, now);
      await _saveSubtasks(id, now, task);

      emit(state.copyWith(status: TaskFormStatus.saved, clearError: true));
    } catch (error) {
      emit(state.copyWith(
        status: TaskFormStatus.error,
        errorMessage: '$error',
      ));
    }
  }

  /// Aturan F3 (`TaskDateUtils`): all-day = tanggal kalender UTC tengah malam;
  /// item berjam = instan apa adanya (dibaca kembali lewat waktu lokal).
  DateTime? _storageDate(DateTime? value) {
    if (value == null) {
      return null;
    }
    if (state.isAllDay) {
      return DateTime.utc(value.year, value.month, value.day);
    }
    return value;
  }

  Future<void> _saveReminders(String taskId, DateTime now) async {
    final offsets = state.savedReminderOffsets;
    final reminders = [
      for (final offset in offsets)
        TaskReminder(
          id: _newId(),
          taskId: taskId,
          offsetMinutes: offset,
          createdAt: now,
          updatedAt: now,
        ),
    ];
    await _taskRepository.replaceReminders(taskId, reminders);
  }

  Future<void> _saveRecurrence(String taskId, DateTime now) async {
    final frequency =
        state.hasAnchorDate ? state.recurrence.toFrequency() : null;
    if (frequency == null) {
      await _taskRepository.setRecurrence(taskId, null);
      return;
    }
    await _taskRepository.setRecurrence(
      taskId,
      TaskRecurrence(
        taskId: taskId,
        frequency: frequency,
        intervalValue: 1,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<void> _saveSubtasks(String taskId, DateTime now, Task parent) async {
    if (state.type != TaskType.task) {
      return;
    }

    // Ambil sub-task yang sudah ada SEBELUM menyimpan, agar sub-task baru
    // (id null) tidak ikut terhapus di langkah pembersihan.
    final existingChildren = (await _taskRepository.watchAllTasks().first)
        .where((t) => t.parentTaskId == taskId)
        .toList();
    final byId = {for (final child in existingChildren) child.id: child};

    final keptIds = <String>{};
    for (final draft in _subtasks) {
      final childId = draft.id ?? _newId();
      keptIds.add(childId);
      final previous = byId[childId];
      await _taskRepository.upsertTask(Task(
        id: childId,
        projectId: parent.projectId,
        parentTaskId: taskId,
        title: draft.title,
        type: TaskType.task,
        status: previous?.status ?? TaskStatus.todo,
        priority: previous?.priority ?? TaskPriority.medium,
        dueAt: parent.dueAt,
        isAllDay: parent.isAllDay,
        completedAt: previous?.completedAt,
        createdAt: previous?.createdAt ?? now,
        updatedAt: now,
      ));
    }

    for (final child in existingChildren) {
      if (!keptIds.contains(child.id)) {
        await _taskRepository.softDeleteTask(child.id);
      }
    }
  }

  @override
  Future<void> close() async {
    await _projectsSub?.cancel();
    return super.close();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_colors.dart';
import 'package:sync_daily/core/theme/app_icons.dart';
import 'package:sync_daily/core/theme/app_radius.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/theme/app_typography.dart';
import 'package:sync_daily/core/widgets/app_chip.dart';
import 'package:sync_daily/core/widgets/latar_layar.dart';
import 'package:sync_daily/core/widgets/section_header.dart';
import 'package:sync_daily/core/utils/id_date.dart';
import 'package:sync_daily/features/notifications/domain/reminder_permissions.dart';
import 'package:sync_daily/features/notifications/presentation/reminder_permission_dialog.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/presentation/form/cubit/task_form_cubit.dart';
import 'package:sync_daily/features/tasks/presentation/form/cubit/task_form_state.dart';

/// Form buat/ubah tugas, acara, pengingat, dan milestone.
///
/// TODO(design): layar ini belum didesain (lihat docs/DESIGN.md bagian "Layar
/// yang BELUM didesain"). Untuk sementara memakai komponen yang ada
/// (AppChip, TextField, LayarLatar) dan token theme. Ganti setelah desain ada.
class TaskFormPage extends StatelessWidget {
  final TaskType initialType;
  final String? taskId;

  /// Tanggal awal (tanpa jam) yang diisikan ke kolom tanggal tipe yang dipilih.
  /// Dipakai Kalender lewat `?date=`; `null` berarti perilaku lama.
  final DateTime? initialDate;

  const TaskFormPage({
    super.key,
    this.initialType = TaskType.task,
    this.taskId,
    this.initialDate,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TaskFormCubit(
        taskRepository: getIt(),
        projectRepository: getIt(),
      )..init(
          initialType: initialType,
          taskId: taskId,
          initialDate: initialDate,
        ),
      child: _TaskFormView(taskId: taskId),
    );
  }
}

class _TaskFormView extends StatelessWidget {
  final String? taskId;

  const _TaskFormView({this.taskId});

  @override
  Widget build(BuildContext context) {
    return BlocListener<TaskFormCubit, TaskFormState>(
      listenWhen: (previous, current) => previous.status != current.status,
      listener: (context, state) async {
        if (state.status != TaskFormStatus.saved) {
          return;
        }
        // Item berpengingat: minta izin notifikasi/alarm tepat waktu dulu.
        if (state.savedReminderOffsets.isNotEmpty) {
          await _requestReminderPermissions(context);
        }
        if (context.mounted) {
          context.pop(true);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: LayarLatar(
          child: SafeArea(
            child: Column(
              children: [
                _FormHeader(taskId: taskId),
                Expanded(
                  child: BlocBuilder<TaskFormCubit, TaskFormState>(
                    builder: (context, state) => _FormBody(state: state),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Meminta izin notifikasi/alarm tepat waktu saat item berpengingat
  /// disimpan, lalu menampilkan penjelasan (termasuk panduan OEM) bila izin
  /// belum diberikan. Izin bersifat pilihan: kegagalan di sini tidak
  /// menghalangi penyimpanan.
  Future<void> _requestReminderPermissions(BuildContext context) async {
    try {
      final permissions = getIt<ReminderPermissions>();
      final notificationsEnabled =
          await permissions.ensureNotificationPermission();
      final exactAlarmsEnabled =
          notificationsEnabled ? await permissions.canScheduleExactAlarms() : false;
      if (notificationsEnabled && exactAlarmsEnabled) {
        return;
      }
      if (!context.mounted) {
        return;
      }
      await showReminderPermissionDialog(
        context,
        permissions: permissions,
        notificationsEnabled: notificationsEnabled,
        exactAlarmsEnabled: exactAlarmsEnabled,
      );
    } catch (_) {
      // Abaikan; penyimpanan tetap dilanjutkan.
    }
  }
}

class _FormHeader extends StatelessWidget {
  final String? taskId;

  const _FormHeader({this.taskId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskFormCubit, TaskFormState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.cardGap,
            AppSizes.pagePadding,
            AppSizes.cardGap,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  state.isEditing ? AppStrings.editItem : AppStrings.newItem,
                  style: AppTypography.textTheme.headlineMedium,
                ),
              ),
              TextButton(
                onPressed: () =>
                    context.read<TaskFormCubit>().save(editingTaskId: taskId),
                child: Text(
                  AppStrings.save,
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FormBody extends StatefulWidget {
  final TaskFormState state;

  const _FormBody({required this.state});

  @override
  State<_FormBody> createState() => _FormBodyState();
}

class _FormBodyState extends State<_FormBody> {
  late final TextEditingController _title;
  late final TextEditingController _description;
  final TextEditingController _subtaskInput = TextEditingController();

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.state.title);
    _description = TextEditingController(text: widget.state.description);
  }

  @override
  void didUpdateWidget(covariant _FormBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sinkronkan saat data dimuat dari repository (mode ubah).
    if (widget.state.title != _title.text &&
        oldWidget.state.title != widget.state.title) {
      _title.text = widget.state.title;
    }
    if (widget.state.description != _description.text &&
        oldWidget.state.description != widget.state.description) {
      _description.text = widget.state.description;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _subtaskInput.dispose();
    super.dispose();
  }

  TaskFormCubit get _cubit => context.read<TaskFormCubit>();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        0,
        AppSizes.pagePadding,
        AppSizes.sectionGap * 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(AppStrings.type),
          const SizedBox(height: AppSizes.itemSpacing),
          _TypeChips(
            value: state.type,
            onChanged: _cubit.setType,
          ),
          const SizedBox(height: AppSizes.sectionGap),
          _TextField(
            controller: _title,
            label: AppStrings.title,
            onChanged: _cubit.setTitle,
          ),
          const SizedBox(height: AppSizes.cardGap),
          _TextField(
            controller: _description,
            label: AppStrings.description,
            onChanged: _cubit.setDescription,
            maxLines: 3,
          ),
          const SizedBox(height: AppSizes.sectionGap),
          const _FieldLabel(AppStrings.priority),
          const SizedBox(height: AppSizes.itemSpacing),
          _PriorityChips(
            value: state.priority,
            onChanged: _cubit.setPriority,
          ),
          const SizedBox(height: AppSizes.sectionGap),
          const _FieldLabel(AppStrings.project),
          const SizedBox(height: AppSizes.itemSpacing),
          _ProjectDropdown(state: state, onChanged: _cubit.setProjectId),
          const SizedBox(height: AppSizes.sectionGap),
          ..._dateFields(state),
          if (state.type == TaskType.task) ...[
            const SizedBox(height: AppSizes.sectionGap),
            _SubtaskField(
              state: state,
              controller: _subtaskInput,
              onAdd: (value) {
                _cubit.addSubtask(value);
                _subtaskInput.clear();
              },
              onRename: _cubit.updateSubtask,
              onRemove: _cubit.removeSubtask,
            ),
          ],
          const SizedBox(height: AppSizes.sectionGap),
          _RecurrenceField(state: state, onChanged: _cubit.setRecurrence),
          const SizedBox(height: AppSizes.sectionGap),
          _ReminderField(
            state: state,
            onToggle: _cubit.toggleReminder,
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSizes.cardGap),
            Text(
              state.errorMessage!,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.deadlineIcon,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Kolom tanggal/waktu sesuai tipe (lihat pemetaan F4a).
  List<Widget> _dateFields(TaskFormState state) {
    switch (state.type) {
      case TaskType.event:
        return [
          const _FieldLabel(AppStrings.startAt),
          const SizedBox(height: AppSizes.itemSpacing),
          _DateTimeButton(
            value: state.startAt,
            isAllDay: state.isAllDay,
            onPick: _cubit.setStartAt,
          ),
          const SizedBox(height: AppSizes.cardGap),
          const _FieldLabel(AppStrings.endAt),
          const SizedBox(height: AppSizes.itemSpacing),
          _DateTimeButton(
            value: state.endAt,
            isAllDay: state.isAllDay,
            onPick: _cubit.setEndAt,
          ),
          const SizedBox(height: AppSizes.cardGap),
          _AllDayToggle(
            value: state.isAllDay,
            onChanged: _cubit.setIsAllDay,
          ),
        ];
      case TaskType.reminder:
        return [
          const _FieldLabel(AppStrings.startAt),
          const SizedBox(height: AppSizes.itemSpacing),
          _DateTimeButton(
            value: state.startAt,
            isAllDay: false,
            onPick: _cubit.setStartAt,
          ),
        ];
      case TaskType.milestone:
        return [
          const _FieldLabel(AppStrings.dueTarget),
          const SizedBox(height: AppSizes.itemSpacing),
          _DateTimeButton(
            value: state.dueAt,
            isAllDay: state.isAllDay,
            onPick: _cubit.setDueAt,
          ),
          const SizedBox(height: AppSizes.cardGap),
          _AllDayToggle(
            value: state.isAllDay,
            onChanged: _cubit.setIsAllDay,
          ),
        ];
      case TaskType.task:
        return [
          const _FieldLabel(AppStrings.dueDate),
          const SizedBox(height: AppSizes.itemSpacing),
          _DateTimeButton(
            value: state.dueAt,
            isAllDay: state.isAllDay,
            onPick: _cubit.setDueAt,
          ),
          const SizedBox(height: AppSizes.cardGap),
          _AllDayToggle(
            value: state.isAllDay,
            onChanged: _cubit.setIsAllDay,
          ),
        ];
    }
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTypography.textTheme.labelSmall,
      );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final int maxLines;

  const _TextField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.searchField),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        maxLines: maxLines,
        style: AppTypography.textTheme.bodyLarge,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTypography.textTheme.bodyMedium,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  final TaskType value;
  final ValueChanged<TaskType> onChanged;

  const _TypeChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.itemSpacing,
      runSpacing: AppSizes.itemSpacing,
      children: [
        for (final type in TaskType.values)
          AppChip(
            label: typeLabel(type),
            isActive: value == type,
            onTap: () => onChanged(type),
          ),
      ],
    );
  }
}

class _PriorityChips extends StatelessWidget {
  final TaskPriority value;
  final ValueChanged<TaskPriority> onChanged;

  const _PriorityChips({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.itemSpacing,
      runSpacing: AppSizes.itemSpacing,
      children: [
        for (final priority in TaskPriority.values)
          AppChip(
            label: priorityLabel(priority),
            isActive: value == priority,
            onTap: () => onChanged(priority),
          ),
      ],
    );
  }
}

class _ProjectDropdown extends StatelessWidget {
  final TaskFormState state;
  final ValueChanged<String?> onChanged;

  const _ProjectDropdown({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.searchField),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          value: state.projectId,
          isExpanded: true,
          hint: Text(
            AppStrings.noProject,
            style: AppTypography.textTheme.bodyMedium,
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(
                AppStrings.noProject,
                style: AppTypography.textTheme.bodyMedium,
              ),
            ),
            for (final project in state.projects)
              DropdownMenuItem<String?>(
                value: project.id,
                child: Text(
                  project.title,
                  style: AppTypography.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  final DateTime? value;
  final bool isAllDay;
  final ValueChanged<DateTime?> onPick;

  const _DateTimeButton({
    required this.value,
    required this.isAllDay,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? AppStrings.pickDate
        : isAllDay
            ? IdDate.full(value!)
            : '${IdDate.full(value!)} · ${_time(value!)}';

    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton.icon(
        onPressed: () => _pick(context),
        icon: const Icon(AppIcons.calendar, size: 20),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, style: AppTypography.textTheme.bodyMedium),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.minTouchTarget),
          alignment: Alignment.centerLeft,
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surface,
        ),
      ),
    );
  }

  static String _time(DateTime value) {
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour.$minute';
  }

  Future<void> _pick(BuildContext context) async {
    final initial = value ?? DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !context.mounted) {
      return;
    }
    if (isAllDay) {
      onPick(date);
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) {
      return;
    }
    onPick(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }
}

class _AllDayToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AllDayToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: Row(
        children: [
          Switch(
            value: value,
            onChanged: onChanged,
          ),
          const SizedBox(width: AppSizes.itemSpacing),
          Text(AppStrings.allDay, style: AppTypography.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SubtaskField extends StatelessWidget {
  final TaskFormState state;
  final TextEditingController controller;
  final ValueChanged<String> onAdd;
  final void Function(int index, String title) onRename;
  final ValueChanged<int> onRemove;

  const _SubtaskField({
    required this.state,
    required this.controller,
    required this.onAdd,
    required this.onRename,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: AppStrings.subtask),
        const SizedBox(height: AppSizes.cardGap),
        Row(
          children: [
            Expanded(
              child: _TextField(
                controller: controller,
                label: AppStrings.addSubtask,
                onChanged: (_) {},
              ),
            ),
            const SizedBox(width: AppSizes.itemSpacing),
            IconButton(
              onPressed: () => onAdd(controller.text),
              icon: const Icon(AppIcons.add),
              tooltip: AppStrings.addSubtask,
            ),
          ],
        ),
        const SizedBox(height: AppSizes.itemSpacing),
        for (var i = 0; i < state.subtaskTitles.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              state.subtaskTitles[i],
              style: AppTypography.textTheme.bodyLarge,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => _rename(context, i, state.subtaskTitles[i]),
                  icon: const Icon(AppIcons.edit),
                  tooltip: AppStrings.editSubtask,
                ),
                IconButton(
                  onPressed: () => onRemove(i),
                  icon: const Icon(AppIcons.close),
                  tooltip: AppStrings.removeSubtask,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _rename(BuildContext context, int index, String current) async {
    final controller = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.editSubtask),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: AppStrings.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      onRename(index, result);
    }
  }
}

class _RecurrenceField extends StatelessWidget {
  final TaskFormState state;
  final ValueChanged<RecurrenceOption> onChanged;

  const _RecurrenceField({required this.state, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enabled = state.hasAnchorDate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: AppStrings.recurrence),
        const SizedBox(height: AppSizes.cardGap),
        Wrap(
          spacing: AppSizes.itemSpacing,
          runSpacing: AppSizes.itemSpacing,
          children: [
            for (final option in RecurrenceOption.values)
              AppChip(
                label: recurrenceLabel(option),
                isActive: state.recurrence == option,
                onTap: enabled ? () => onChanged(option) : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _ReminderField extends StatelessWidget {
  final TaskFormState state;
  final ValueChanged<ReminderOption> onToggle;

  const _ReminderField({required this.state, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final enabled = state.hasAnchorDate;
    final options = state.type == TaskType.reminder
        ? ReminderOption.values
        : ReminderOption.values
            .where((option) => option != ReminderOption.onTime)
            .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: AppStrings.reminderLabel),
        const SizedBox(height: AppSizes.cardGap),
        Wrap(
          spacing: AppSizes.itemSpacing,
          runSpacing: AppSizes.itemSpacing,
          children: [
            for (final option in options)
              AppChip(
                label: reminderLabel(option),
                isActive: state.reminders.contains(option),
                onTap: enabled ? () => onToggle(option) : null,
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => showReminderOemGuideDialog(context),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, AppSizes.minTouchTarget),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
            child: const Text(AppStrings.oemGuideLink),
          ),
        ),
      ],
    );
  }
}

// --- Label helpers (dipakai widget dan tes) ---

String typeLabel(TaskType type) {
  switch (type) {
    case TaskType.task:
      return AppStrings.formTitleTask;
    case TaskType.event:
      return AppStrings.formTitleEvent;
    case TaskType.reminder:
      return AppStrings.formTitleReminder;
    case TaskType.milestone:
      return AppStrings.formTitleMilestone;
  }
}

String priorityLabel(TaskPriority priority) {
  switch (priority) {
    case TaskPriority.low:
      return AppStrings.priorityLow;
    case TaskPriority.medium:
      return AppStrings.priorityMedium;
    case TaskPriority.high:
      return AppStrings.priorityHigh;
  }
}

String recurrenceLabel(RecurrenceOption option) {
  switch (option) {
    case RecurrenceOption.none:
      return AppStrings.none;
    case RecurrenceOption.daily:
      return AppStrings.daily;
    case RecurrenceOption.weekly:
      return AppStrings.weekly;
    case RecurrenceOption.monthly:
      return AppStrings.monthly;
  }
}

String reminderLabel(ReminderOption option) {
  switch (option) {
    case ReminderOption.onTime:
      return AppStrings.remindOnTime;
    case ReminderOption.tenMinutes:
      return AppStrings.remind10Min;
    case ReminderOption.oneHour:
      return AppStrings.remind1Hour;
    case ReminderOption.oneDay:
      return AppStrings.remind1Day;
  }
}

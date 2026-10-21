import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_icons.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/theme/app_typography.dart';
import 'package:sync_daily/core/widgets/app_icon_button.dart';
import 'package:sync_daily/core/widgets/empty_state.dart';
import 'package:sync_daily/core/widgets/latar_layar.dart';
import 'package:sync_daily/core/widgets/section_header.dart';
import 'package:sync_daily/features/notifications/domain/app_messenger.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/notification_kind.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/notifications/domain/repositories/notification_repository.dart';
import 'package:sync_daily/features/notifications/domain/task_detail_opener.dart';
import 'package:sync_daily/features/notifications/domain/notification_day_group.dart';
import 'package:sync_daily/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:sync_daily/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:sync_daily/features/notifications/presentation/widgets/notification_filter_chips.dart';
import 'package:sync_daily/features/notifications/presentation/widgets/notification_item_tile.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';

/// Layar Notifikasi: tombol kembali, "Tandai dibaca", chip jenis, lalu daftar
/// entri riwayat yang dikelompokkan per hari.
///
/// Halaman dibuka dari lonceng Beranda lewat rute `/notifications` (di luar
/// shell, tampil penuh tanpa navigasi bawah).
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationsCubit(
        notificationRepository: getIt<NotificationRepository>(),
        taskRepository: getIt<TaskRepository>(),
        opener: getIt<TaskDetailOpener>(),
        messenger: getIt<AppMessenger>(),
        synchronizer: getIt<ReminderSynchronizer>(),
        reconciler: getIt<NotificationHistoryReconciler>(),
      )..start(),
      child: const _NotificationsView(),
    );
  }
}

/// Jarak bawah daftar. Halaman ini tampil penuh (tanpa navigasi bawah), jadi
/// cukup satu jarak bagian.
const double _bottomInset = AppSizes.sectionGap * 2;

/// Sisa ruang minimal untuk daftar yang bergulir sendiri. Bila ruang di layar
/// lebih kecil dari ini (layar pendek), seluruh halaman bergulir seperti pola
/// Catatan/Kalender supaya tidak ada isi yang terpotong.
const double _minListHeight = 160;

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LayarLatar(
        child: SafeArea(
          child: BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              switch (state.status) {
                case NotificationsStatus.loading:
                  return const Center(child: CircularProgressIndicator());
                case NotificationsStatus.error:
                  return _ErrorState(
                    onRetry: () => context.read<NotificationsCubit>().retry(),
                  );
                case NotificationsStatus.loaded:
                  final cubit = context.read<NotificationsCubit>();
                  return _LoadedView(
                    state: state,
                    onBack: () => _close(context),
                    onKindChanged: cubit.setKind,
                    onMarkAllRead: cubit.markAllRead,
                    onOpenEntry: cubit.openEntry,
                    onDone: cubit.markDone,
                    onSnooze: cubit.snooze,
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Isi Notifikasi yang sudah termuat.
///
/// Tombol kembali, judul, "Tandai dibaca", dan chip jenis tetap di atas; hanya
/// daftar entri yang bergulir. Bila sisa ruang untuk daftar terlalu kecil
/// (< [_minListHeight]), seluruh halaman bergulir; peralihan itu hanya
/// dilakukan setelah bagian tetap terukur, jadi frame pertama sudah memakai
/// tata letak yang mengisi penuh (tidak ada kilatan/lompatan).
class _LoadedView extends StatefulWidget {
  final NotificationsState state;
  final VoidCallback onBack;
  final ValueChanged<NotificationKind?> onKindChanged;
  final VoidCallback onMarkAllRead;
  final ValueChanged<AppNotification> onOpenEntry;
  final ValueChanged<AppNotification> onDone;
  final ValueChanged<AppNotification> onSnooze;

  const _LoadedView({
    required this.state,
    required this.onBack,
    required this.onKindChanged,
    required this.onMarkAllRead,
    required this.onOpenEntry,
    required this.onDone,
    required this.onSnooze,
  });

  @override
  State<_LoadedView> createState() => _LoadedViewState();
}

class _LoadedViewState extends State<_LoadedView> {
  final GlobalKey _fixedKey = GlobalKey();

  double? _fixedHeight;

  @override
  Widget build(BuildContext context) {
    _measureFixed();

    return LayoutBuilder(
      builder: (context, constraints) {
        final height = _fixedHeight;
        if (height != null &&
            constraints.maxHeight - height - AppSizes.cardGap <
                _minListHeight) {
          return _scrollingLayout();
        }
        return _fixedLayout();
      },
    );
  }

  void _measureFixed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final size = _fixedKey.currentContext?.size;
      if (size == null) {
        return;
      }
      final measured = size.height;
      final previous = _fixedHeight;
      if (previous != null && (previous - measured).abs() < 0.5) {
        return;
      }
      setState(() => _fixedHeight = measured);
    });
  }

  /// Bagian tetap: tombol kembali, judul, "Tandai dibaca", dan chip jenis.
  Widget _fixedPart() {
    return KeyedSubtree(
      key: _fixedKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconButton(
                icon: AppIcons.back,
                semanticLabel: AppStrings.back,
                onTap: widget.onBack,
              ),
              const SizedBox(width: AppSizes.cardGap),
              Expanded(
                child: Text(
                  AppStrings.notifications,
                  style: AppTypography.textTheme.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSizes.itemSpacing),
              TextButton(
                onPressed:
                    widget.state.hasUnread ? widget.onMarkAllRead : null,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, AppSizes.minTouchTarget),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  AppStrings.notificationMarkAllRead,
                  style: AppTypography.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sectionGap),
          NotificationFilterChips(
            value: widget.state.kind,
            onChanged: widget.onKindChanged,
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    final filtered = widget.state.hasFilter;
    return EmptyState(
      title: filtered
          ? AppStrings.notificationNoMatch
          : AppStrings.notificationEmpty,
      description: filtered
          ? AppStrings.notificationNoMatchDescription
          : AppStrings.notificationEmptyDescription,
    );
  }

  Widget _list() {
    final children = <Widget>[];
    for (final group in widget.state.groups) {
      children.add(
        SectionHeader(
          title: notificationDayLabel(group.day, widget.state.today),
        ),
      );
      children.add(const SizedBox(height: AppSizes.cardGap));
      for (var i = 0; i < group.entries.length; i++) {
        final entry = group.entries[i];
        children.add(
          NotificationItemTile(
            entry: entry,
            onTap: () => widget.onOpenEntry(entry),
            onDone: () => widget.onDone(entry),
            onSnooze: () => widget.onSnooze(entry),
          ),
        );
        if (i != group.entries.length - 1) {
          children.add(const SizedBox(height: AppSizes.itemSpacing));
        }
      }
      children.add(const SizedBox(height: AppSizes.sectionGap));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _fixedLayout() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.cardGap,
            AppSizes.pagePadding,
            0,
          ),
          child: _fixedPart(),
        ),
        Expanded(
          child: widget.state.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(AppSizes.pagePadding),
                  child: Center(child: _emptyState()),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.pagePadding,
                    AppSizes.cardGap,
                    AppSizes.pagePadding,
                    _bottomInset,
                  ),
                  child: _list(),
                ),
        ),
      ],
    );
  }

  Widget _scrollingLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.cardGap,
        AppSizes.pagePadding,
        _bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fixedPart(),
          const SizedBox(height: AppSizes.cardGap),
          if (widget.state.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.sectionGap),
              child: _emptyState(),
            )
          else
            _list(),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        child: EmptyState(
          title: AppStrings.loadFailedTitle,
          description: AppStrings.loadFailedDescription,
          action: FilledButton(
            onPressed: onRetry,
            child: Text(
              AppStrings.retry,
              style: AppTypography.textTheme.labelLarge,
            ),
          ),
        ),
      ),
    );
  }
}

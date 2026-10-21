import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/theme/app_typography.dart';
import 'package:sync_daily/core/theme/category_theme.dart';
import 'package:sync_daily/core/widgets/empty_state.dart';
import 'package:sync_daily/core/widgets/latar_layar.dart';
import 'package:sync_daily/core/widgets/section_header.dart';
import 'package:sync_daily/features/home/presentation/cubit/home_cubit.dart';
import 'package:sync_daily/features/home/presentation/cubit/home_state.dart';
import 'package:sync_daily/features/home/presentation/widgets/home_filter_dropdown.dart';
import 'package:sync_daily/features/home/presentation/widgets/home_header.dart';
import 'package:sync_daily/features/home/presentation/widgets/projects_section.dart';
import 'package:sync_daily/features/home/presentation/widgets/stat_card.dart';
import 'package:sync_daily/features/notifications/presentation/notifications_route.dart';
import 'package:sync_daily/features/projects/domain/entities/project_with_counts.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeCubit(
        taskRepository: getIt(),
        projectRepository: getIt(),
        notificationRepository: getIt(),
        userProfileRepository: getIt(),
      )..start(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  void _showSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.comingSoon)),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    HomeCubit cubit,
    ProjectWithCounts item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.deleteProjectTitle),
        content: Text(
          AppStrings.deleteProjectBody(item.project.title),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );

    if (confirmed ?? false) {
      await cubit.deleteProject(item.project.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.projectDeleted)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayarLatar(
        child: SafeArea(
          child: BlocBuilder<HomeCubit, HomeState>(
            builder: (context, state) {
              switch (state.status) {
                case HomeStatus.loading:
                  return const Center(child: CircularProgressIndicator());
                case HomeStatus.error:
                  return _ErrorState(
                    onRetry: () => context.read<HomeCubit>().retry(),
                  );
                case HomeStatus.loaded:
                  return _LoadedView(
                    state: state,
                    onShowSoon: () => _showSoon(context),
                    onOpenNotifications: () => openNotificationsPage(context),
                    onOpenToday: () => context.push('/tasks?filter=today'),
                    onOpenAllTasks: () => context.push('/tasks?filter=all'),
                    onDelete: (item) => _confirmDelete(
                      context,
                      context.read<HomeCubit>(),
                      item,
                    ),
                  );
              }
            },
          ),
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  final HomeState state;
  final VoidCallback onShowSoon;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenToday;
  final VoidCallback onOpenAllTasks;
  final ValueChanged<ProjectWithCounts> onDelete;

  const _LoadedView({
    required this.state,
    required this.onShowSoon,
    required this.onOpenNotifications,
    required this.onOpenToday,
    required this.onOpenAllTasks,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<HomeCubit>();
    final summary = state.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.pagePadding,
        AppSizes.pagePadding,
        AppSizes.pagePadding,
        120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeHeader(
            userName: state.userName,
            greeting: state.greeting,
            unreadCount: state.unreadCount,
            onBellTap: onOpenNotifications,
          ),
          const SizedBox(height: AppSizes.sectionGap),
          SectionHeader(
            title: AppStrings.overview,
            trailing: HomeFilterDropdown<PeriodFilter>(
              semanticLabel: AppStrings.filterPeriod,
              options: PeriodFilter.values,
              value: state.period,
              labelOf: (value) => value.label,
              onChanged: cubit.setPeriod,
            ),
          ),
          const SizedBox(height: AppSizes.cardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatCard(
                    label: AppStrings.statToday,
                    value: summary?.today ?? 0,
                    category: TaskCategory.task,
                    onTap: onOpenToday,
                  ),
                ),
                const SizedBox(width: AppSizes.cardGap),
                Expanded(
                  child: StatCard(
                    label: AppStrings.statSchedule,
                    value: summary?.schedule ?? 0,
                    category: TaskCategory.event,
                    onTap: onShowSoon,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.cardGap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StatCard(
                    label: AppStrings.statProjects,
                    value: summary?.projectsTotal ?? 0,
                    category: TaskCategory.project,
                    onTap: onShowSoon,
                  ),
                ),
                const SizedBox(width: AppSizes.cardGap),
                Expanded(
                  child: StatCard(
                    label: AppStrings.statAllTasks,
                    value: summary?.allTasks ?? 0,
                    category: TaskCategory.milestone,
                    onTap: onOpenAllTasks,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          ProjectsSection(
            owned: state.ownedProjects,
            received: state.receivedProjects,
            projectTab: state.projectTab,
            onTabChanged: cubit.setProjectTab,
            onEdit: (_) => onShowSoon(),
            onDelete: onDelete,
          ),
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

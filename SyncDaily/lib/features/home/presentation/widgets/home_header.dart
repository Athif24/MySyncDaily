import 'package:sync_daily/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_icons.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/theme/app_typography.dart';
import 'package:sync_daily/core/widgets/app_avatar.dart';
import 'package:sync_daily/core/widgets/app_icon_button.dart';
import 'package:sync_daily/core/widgets/unread_badge.dart';

/// Header Beranda: avatar, sapaan + nama, dan tombol lonceng dengan badge.
class HomeHeader extends StatelessWidget {
  final String userName;
  final String greeting;
  final int unreadCount;
  final VoidCallback? onBellTap;

  const HomeHeader({
    super.key,
    required this.userName,
    required this.greeting,
    required this.unreadCount,
    this.onBellTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Semantics(
          container: true,
          button: true,
          label: AppStrings.settingsTitle,
          onTap: () => openSettingsPage(context),
          // Avatar punya label sendiri (nama pengguna). Kalau tidak dikecualikan,
          // label itu menyatu dengan label tombol dan pembaca layar membaca
          // dua label sekaligus.
          child: ExcludeSemantics(
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => openSettingsPage(context),
                child: SizedBox(
                  height: AppSizes.avatar,
                  width: AppSizes.avatar,
                  child: AppAvatar(name: userName, size: AppSizes.avatar),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSizes.cardGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                greeting,
                style: AppTypography.textTheme.bodySmall,
              ),
              Text(
                userName,
                style: AppTypography.textTheme.titleLarge,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSizes.itemSpacing),
        _BellButton(unreadCount: unreadCount, onTap: onBellTap),
      ],
    );
  }
}

class _BellButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback? onTap;

  const _BellButton({required this.unreadCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AppIconButton(
          icon: AppIcons.bell,
          semanticLabel: AppStrings.notifications,
          onTap: onTap,
        ),
        if (unreadCount > 0)
          Positioned(
            top: -AppSizes.badgeOverlap,
            right: -AppSizes.badgeOverlap,
            child: UnreadBadge(count: unreadCount),
          ),
      ],
    );
  }
}

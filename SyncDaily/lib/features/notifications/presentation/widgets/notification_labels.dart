import 'package:flutter/material.dart';
import 'package:sync_daily/core/theme/app_icons.dart';
import 'package:sync_daily/core/theme/category_theme.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';

/// Kategori warna kartu untuk sebuah tipe notifikasi tersimpan.
TaskCategory notificationCategoryFor(NotificationType type) {
  switch (type) {
    case NotificationType.reminder:
      return TaskCategory.reminder;
    case NotificationType.event:
      return TaskCategory.event;
    case NotificationType.deadline:
      return TaskCategory.deadline;
    default:
      return TaskCategory.task;
  }
}

/// Ikon kotak depan untuk sebuah tipe notifikasi tersimpan.
IconData notificationIconFor(NotificationType type) {
  switch (type) {
    case NotificationType.reminder:
      return AppIcons.clock;
    case NotificationType.event:
      return AppIcons.calendar;
    case NotificationType.deadline:
      return AppIcons.flag;
    default:
      return AppIcons.bell;
  }
}

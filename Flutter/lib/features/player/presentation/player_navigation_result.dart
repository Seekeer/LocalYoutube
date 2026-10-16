import 'package:flutter/material.dart';

enum PlayerNavigationResult {
  deletedLocal,
  deletedServer,
  deletedEverywhere,
}

extension PlayerNavigationResultX on PlayerNavigationResult {
  String get successMessage {
    switch (this) {
      case PlayerNavigationResult.deletedLocal:
        return 'Файл удалён локально';
      case PlayerNavigationResult.deletedServer:
        return 'Файл удалён с сервера';
      case PlayerNavigationResult.deletedEverywhere:
        return 'Файл удалён отовсюду';
    }
  }
}

void showPlayerNavigationResultSnackBar(
  BuildContext context,
  PlayerNavigationResult? result,
) {
  if (result == null || !context.mounted) {
    return;
  }
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(result.successMessage)));
}

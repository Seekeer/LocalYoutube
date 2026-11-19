import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/bootstrap/bootstrap_providers.dart';
import '../../../app/router/app_routes.dart';
import '../../../core/errors/failure.dart';
import '../../../shared/widgets/lt_widgets.dart';
import '../../downloads/domain/download_models.dart';
import '../../downloads/domain/download_service.dart';
import '../../notes/data/notes_repository.dart';

/// Signs the person out after asking: online it removes every downloaded video
/// from the phone and ends the session on the server; in the offline fallback
/// it only forgets the saved session. Notes drafts of the account are cleared
/// either way, and the app goes to the login screen.
///
/// Returns false when the person changed their mind or the server refused.
Future<bool> confirmAndSignOut(BuildContext context, WidgetRef ref) async {
  final bool isOfflineFallback =
      ref.read(authNotifierProvider).isOfflineFallback;
  final bool confirmed = await ltConfirm(
    context,
    title: 'Выйти из аккаунта?',
    message: isOfflineFallback
        ? 'Понадобится снова войти, когда появится сеть.'
        : 'Скачанные видео будут удалены с телефона.',
    confirmLabel: 'Выйти',
    confirmKey: const Key('sign-out-confirm'),
  );
  if (!confirmed || !context.mounted) {
    return false;
  }

  // Once confirmed, sign-out finishes even if the person leaves Settings
  // while the downloads are being removed: it works through the app's
  // provider container and router, not through this page.
  final ProviderContainer container =
      ProviderScope.containerOf(context, listen: false);
  final GoRouter router = GoRouter.of(context);
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);

  NotesRepository? notes;
  try {
    notes = container.read(notesRepositoryProvider);
  } catch (_) {
    notes = null;
  }
  if (isOfflineFallback) {
    await container.read(authRepositoryProvider).logoutOfflineFallback();
  } else {
    final DownloadService downloadService =
        container.read(downloadServiceProvider);
    final List<DownloadItem> downloads =
        await container.read(localDownloadsRepositoryProvider).listAll();
    for (final DownloadItem item in downloads) {
      await downloadService.deleteLocal(item.videoId);
    }

    final Failure? logoutFailure =
        await container.read(logoutUseCaseProvider).call();
    if (logoutFailure != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text(logoutFailure.message)),
      );
      return false;
    }
  }
  // Drafts, clips and cached notes are private to the account that
  // signed out; the next account must not see or sync them.
  try {
    await notes?.clearLocalData();
  } catch (_) {
    // Rows stay tied to their account, so the next one still cannot see them.
  }
  container.invalidate(notesShelfProvider);
  container.read(notesRevisionProvider.notifier).state++;
  container.read(authNotifierProvider).enterSignedOut();
  router.go(AppRoutes.login);
  return true;
}

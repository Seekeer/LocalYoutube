import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cast_device_labels.dart';
import '../domain/cast_session_models.dart';
import 'cast_controller.dart';

/// Where a viewer picks the Receiver to watch on, and starts watching on it.
///
/// It stays on screen when no Receiver is online, because that is exactly the moment someone needs
/// to be told how to make one available. Picking a Receiver still records the choice and nothing
/// else: starting a cast is the separate, explicit action below the list.
///
/// The entry point is also shown where there is no video to cast - a settings screen, say. There it
/// is given no [videoId] and offers no way to start, because there would be nothing to start.
class CastEntryPoint extends ConsumerWidget {
  const CastEntryPoint({super.key, this.videoId});

  static const String title = 'Watch on another device';

  /// Shown instead of the list while the account has no online Receiver.
  static const String noReceiversMessage =
      'No Receiver is online. Open LocalTube on the device you want to watch '
      'on and turn on Receiver Mode there.';

  /// The action that starts Handoff of the current video to the picked Receiver.
  static const String castLabel = 'Cast';

  /// Shown while the Receiver is loading the video and the phone is still playing it.
  static const String preparingLabel = 'Preparing the Receiver...';

  /// The way out of a Handoff that is taking too long. The phone never stopped playing, so backing
  /// out simply leaves the viewer where they already are.
  static const String cancelLabel = 'Cancel';

  /// Shown when the API refused, so the viewer is not left wondering why nothing happened.
  static const String alreadyCastingMessage =
      'Something on this account is already casting.';
  static const String castFailedMessage = 'Could not start casting.';

  static const Key noReceiversMessageKey = Key('cast-no-receivers-message');
  static const Key selectedReceiverKey = Key('cast-selected-receiver');
  static const Key castButtonKey = Key('cast-start-button');
  static const Key preparingKey = Key('cast-preparing');
  static const Key cancelButtonKey = Key('cast-cancel-button');
  static const Key failureKey = Key('cast-failure');

  /// The video a cast started from here would hand over, or `null` where there is none.
  final int? videoId;

  /// The key of the row for [deviceId], so a test can tap one particular Receiver.
  static Key receiverKey(String deviceId) => Key('cast-receiver-$deviceId');

  /// What a refusal reads as. An unrecognised reason still says the cast did not happen.
  static String failureMessage(String reason) {
    return reason == CastErrorReason.sessionAlreadyActive
        ? alreadyCastingMessage
        : castFailedMessage;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CastUiState state = ref.watch(castControllerProvider);
    final int? castableVideoId = videoId;
    final String? failureReason = state.castFailureReason;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Icon(Icons.cast),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        if (state.receivers.isEmpty)
          Text(
            noReceiversMessage,
            key: noReceiversMessageKey,
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...state.receivers.map(
            (CastDeviceLabel receiver) => _buildReceiverTile(
              context: context,
              ref: ref,
              receiver: receiver,
              isSelected: state.selectedReceiverDeviceId == receiver.deviceId,
            ),
          ),
        if (state.isPreparingHandoff) ...<Widget>[
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  preparingLabel,
                  key: preparingKey,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              TextButton(
                key: cancelButtonKey,
                onPressed: () => unawaited(
                  ref.read(castControllerProvider.notifier).cancelCast(),
                ),
                child: const Text(cancelLabel),
              ),
            ],
          ),
        ],
        if (failureReason != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            failureMessage(failureReason),
            key: failureKey,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (castableVideoId != null) ...<Widget>[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              key: castButtonKey,
              onPressed: state.canStartCast
                  ? () => unawaited(
                        ref.read(castControllerProvider.notifier).startCast(
                              videoId: castableVideoId,
                            ),
                      )
                  : null,
              icon: const Icon(Icons.cast_connected),
              label: const Text(castLabel),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReceiverTile({
    required BuildContext context,
    required WidgetRef ref,
    required CastDeviceLabel receiver,
    required bool isSelected,
  }) {
    return ListTile(
      key: receiverKey(receiver.deviceId),
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.tv),
      title: Text(receiver.name),
      subtitle: receiver.detail == null ? null : Text(receiver.detail!),
      selected: isSelected,
      trailing: isSelected
          ? const Icon(Icons.check, key: selectedReceiverKey)
          : null,
      onTap: () => unawaited(
        ref.read(castControllerProvider.notifier).selectReceiver(
              receiver.deviceId,
            ),
      ),
    );
  }
}

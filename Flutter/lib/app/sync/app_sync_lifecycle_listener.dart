import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/bootstrap_providers.dart';
import '../../core/network/network_status.dart';

class AppSyncLifecycleListener extends ConsumerStatefulWidget {
  const AppSyncLifecycleListener({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<AppSyncLifecycleListener> createState() =>
      _AppSyncLifecycleListenerState();
}

class _AppSyncLifecycleListenerState
    extends ConsumerState<AppSyncLifecycleListener>
    with WidgetsBindingObserver {
  ProviderSubscription<AsyncValue<NetworkStatus>>? _networkStatusSubscription;
  bool? _isOnline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final appSyncCoordinator = ref.read(appSyncCoordinatorProvider);
    unawaited(appSyncCoordinator.initialize());
    _networkStatusSubscription = ref.listenManual<AsyncValue<NetworkStatus>>(
      networkStatusProvider,
      (_, AsyncValue<NetworkStatus> next) {
        next.whenData(
          (NetworkStatus status) => unawaited(_handleNetworkStatus(status)),
        );
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _networkStatusSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      return;
    }
    try {
      ref.read(apiRouteProvider).invalidate('app resumed');
    } on UnimplementedError {
      // Lightweight widget tests do not build the network composition root.
    }
    unawaited(_recoverAndSync(reason: 'app-resumed'));
  }

  Future<void> _handleNetworkStatus(NetworkStatus status) async {
    try {
      ref.read(apiRouteProvider).invalidate('connectivity=${status.name}');
    } on UnimplementedError {
      // Lightweight widget tests do not build the network composition root.
    }
    final bool online = status == NetworkStatus.online;
    final bool? wasOnline = _isOnline;
    _isOnline = online;

    if (!online) {
      if (wasOnline == true) {
        await _handleNetworkOffline();
      }
      return;
    }

    final String reason = wasOnline == true ? 'network-change' : 'network-online';
    await _recoverAndSync(reason: reason);
  }

  Future<void> _handleNetworkOffline() async {
    final authNotifier = ref.read(authNotifierProvider);
    if (!authNotifier.isOnlineAuthenticated) {
      return;
    }

    final bool enteredOfflineFallback =
        await ref.read(authRepositoryProvider).enterOfflineFallbackIfAvailable(
              notice: 'Internet unavailable. Switched to offline mode using local data.',
            );
    if (enteredOfflineFallback) {
      return;
    }

    authNotifier.setAccessMode(
      authNotifier.accessMode,
      notice: 'Internet unavailable. Offline mode requires local data.',
    );
  }

  Future<void> _recoverAndSync({required String reason}) async {
    final authNotifier = ref.read(authNotifierProvider);
    if (authNotifier.isOfflineFallback) {
      authNotifier.enterOnlineAuthenticated();
      final bool recovered =
          await ref.read(authRepositoryProvider).recoverOnlineSession();
      if (!recovered) {
        authNotifier.enterOfflineFallback();
      }
    }
    await ref.read(appSyncCoordinatorProvider).triggerSync(reason: reason);
  }
}

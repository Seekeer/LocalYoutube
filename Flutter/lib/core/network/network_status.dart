import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NetworkStatus { online, offline }

final Provider<Connectivity> connectivityProvider = Provider<Connectivity>(
  (Ref ref) => Connectivity(),
);

final StreamProvider<NetworkStatus> networkStatusProvider =
    StreamProvider<NetworkStatus>(
  (Ref ref) async* {
    final Connectivity connectivity = ref.watch(connectivityProvider);

    NetworkStatus mapResults(List<ConnectivityResult> results) {
      for (final ConnectivityResult result in results) {
        if (result != ConnectivityResult.none) {
          return NetworkStatus.online;
        }
      }
      return NetworkStatus.offline;
    }

    try {
      final List<ConnectivityResult> initial =
          await connectivity.checkConnectivity();
      yield mapResults(initial);
      yield* connectivity.onConnectivityChanged.map(mapResults).distinct();
    } on MissingPluginException {
      yield NetworkStatus.online;
    } catch (_) {
      yield NetworkStatus.online;
    }
  },
);

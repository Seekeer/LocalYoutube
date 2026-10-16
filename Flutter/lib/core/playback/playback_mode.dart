import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/network_status.dart';

final StateProvider<bool> manualAutonomousModeProvider =
    StateProvider<bool>((Ref ref) => false);

final Provider<bool> effectiveAutonomousModeProvider =
    Provider<bool>((Ref ref) {
  final bool manualMode = ref.watch(manualAutonomousModeProvider);
  final NetworkStatus? networkStatus = ref.watch(networkStatusProvider).value;
  return manualMode || networkStatus == NetworkStatus.offline;
});
